#!/usr/bin/env python3
"""
STEP 4: Import Oracle Data Pump exports into PostgreSQL.

Oracle Data Pump (.dmp) files can't be directly loaded into PostgreSQL.
This script handles multiple approaches depending on what's in the dump:

  Approach A: If ora2pg is available, use it to convert Oracle -> PostgreSQL
  Approach B: If the dumps contain SQL/CSV-exportable data, extract and load
  Approach C: Analyze the dump files and create a loading plan

Since JEDMICS Data Pump exports are Oracle-specific binary format, the
recommended path is ora2pg or setting up a temporary Oracle XE instance
to export to CSV, then load into PostgreSQL.

This script provides Approach C (analysis + CSV loading) as the most
practical path for a GFE without Oracle installed.

Usage:
    python 04_import_to_postgres.py --data-dir %USERPROFILE%\\UNNPI_Data --db unnpi_jedmics
"""

import argparse
import os
import re
import sys
import struct
import json
from pathlib import Path
from datetime import datetime

try:
    import psycopg2
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False

# ============================================================
# ORACLE DATA PUMP ANALYSIS
# ============================================================

def analyze_dmp_file(filepath):
    """
    Analyze an Oracle Data Pump file to extract metadata.
    DMP files are binary but contain readable table/schema names.
    """
    info = {
        "filename": os.path.basename(filepath),
        "size_mb": round(os.path.getsize(filepath) / (1024 * 1024), 2),
        "tables_found": [],
        "schemas_found": [],
        "is_datapump": False,
    }

    try:
        with open(filepath, "rb") as f:
            header = f.read(4096)

            # Check for Data Pump magic bytes
            # Oracle Data Pump files typically start with specific headers
            if b"MASTER" in header or b"TABLE_DATA" in header or b"SYS_EXPORT" in header:
                info["is_datapump"] = True

            # Scan for table names and schema names in the binary
            # Read more of the file for metadata extraction
            f.seek(0)
            chunk_size = 1024 * 1024  # 1MB chunks
            text_fragments = []

            # Read first 10MB for metadata
            for _ in range(10):
                chunk = f.read(chunk_size)
                if not chunk:
                    break
                # Extract ASCII strings from binary
                current = []
                for byte in chunk:
                    if 32 <= byte < 127:
                        current.append(chr(byte))
                    else:
                        if len(current) >= 4:
                            text_fragments.append("".join(current))
                        current = []

            # Look for table-like names (uppercase, underscores)
            seen_tables = set()
            seen_schemas = set()
            for frag in text_fragments:
                frag = frag.strip()
                # Common JEDMICS table patterns
                jedmics_patterns = [
                    "DRAWING", "DOCUMENT", "REVISION", "PART",
                    "SDI", "SHIP", "INDEX", "CONFIG", "METADATA",
                    "BLOB", "CONTENT", "HEADER", "DETAIL",
                ]
                for pattern in jedmics_patterns:
                    if pattern in frag.upper() and len(frag) < 60 and "_" in frag:
                        seen_tables.add(frag)

                # Schema patterns
                if frag.upper() in ["JEDMICS", "JDMS", "SDI", "EDMS"]:
                    seen_schemas.add(frag)

            info["tables_found"] = sorted(list(seen_tables))[:50]
            info["schemas_found"] = sorted(list(seen_schemas))

    except Exception as e:
        info["error"] = str(e)

    return info


def scan_data_directory(data_dir):
    """Scan the download directory and catalog all files."""
    catalog = {
        "scan_time": datetime.now().isoformat(),
        "data_dir": str(data_dir),
        "sources": {}
    }

    for source_dir in data_dir.iterdir():
        if not source_dir.is_dir():
            continue

        source_name = source_dir.name
        files = []

        for f in sorted(source_dir.rglob("*")):
            if f.is_file():
                file_info = {
                    "path": str(f),
                    "name": f.name,
                    "size_mb": round(f.stat().st_size / (1024 * 1024), 2),
                    "extension": f.suffix.lower(),
                }

                # Analyze .dmp files
                if f.suffix.lower() == ".dmp":
                    print(f"  Analyzing: {f.name} ({file_info['size_mb']} MB)...")
                    file_info["analysis"] = analyze_dmp_file(str(f))

                files.append(file_info)

        catalog["sources"][source_name] = {
            "file_count": len(files),
            "total_size_mb": round(sum(f["size_mb"] for f in files), 2),
            "files": files,
        }

    return catalog


# ============================================================
# CSV / SQL FILE LOADING
# ============================================================

def load_csv_to_postgres(csv_path, table_name, schema, conn, delimiter=","):
    """Load a CSV file into PostgreSQL."""
    cur = conn.cursor()

    # Read header to get column names
    with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
        header_line = f.readline().strip()
        columns = [c.strip().strip('"').lower().replace(" ", "_") for c in header_line.split(delimiter)]

    # Create table
    col_defs = ", ".join(f'"{c}" TEXT' for c in columns)
    create_sql = f'CREATE TABLE IF NOT EXISTS {schema}."{table_name}" ({col_defs})'
    cur.execute(create_sql)

    # Make the load idempotent: clear any existing rows so re-running the
    # importer replaces the data instead of appending duplicates.
    cur.execute(f'TRUNCATE TABLE {schema}."{table_name}"')

    # Copy data
    with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
        f.readline()  # skip header
        cur.copy_expert(
            f"COPY {schema}.\"{table_name}\" FROM STDIN WITH (FORMAT csv, DELIMITER '{delimiter}', NULL '')",
            f
        )

    # Get row count
    cur.execute(f'SELECT COUNT(*) FROM {schema}."{table_name}"')
    count = cur.fetchone()[0]

    conn.commit()
    cur.close()
    return count


def load_sql_to_postgres(sql_path, schema, conn):
    """Execute a SQL file against PostgreSQL (best effort)."""
    cur = conn.cursor()

    with open(sql_path, "r", encoding="utf-8", errors="replace") as f:
        sql = f.read()

    # Basic Oracle -> PostgreSQL syntax fixes.
    # Use word boundaries so we only touch standalone type keywords, not
    # identifiers that happen to contain them (e.g. a column named PART_NUMBER
    # must NOT become PART_NUMERIC). Order matters: VARCHAR2 before VARCHAR.
    type_fixes = [
        (r"\bVARCHAR2\b", "VARCHAR"),
        (r"\bNUMBER\b", "NUMERIC"),
        (r"\bCLOB\b", "TEXT"),
        (r"\bBLOB\b", "BYTEA"),
        (r"\bSYSDATE\b", "NOW()"),
        (r"\bNVL\s*\(", "COALESCE("),
    ]
    for pattern, repl in type_fixes:
        sql = re.sub(pattern, repl, sql, flags=re.IGNORECASE)

    # Set search path to target schema
    cur.execute(f"SET search_path TO {schema}, public")

    try:
        cur.execute(sql)
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"  [WARNING] SQL execution error: {e}")

    cur.close()


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="Import UNNPI data into PostgreSQL")
    parser.add_argument("--data-dir", default=os.path.join(os.path.expanduser("~"), "UNNPI_Data"),
                        help="Directory containing downloaded S3 data")
    parser.add_argument("--db", default="unnpi_jedmics",
                        help="PostgreSQL database name")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--password", default=None,
                        help="PostgreSQL password (will prompt if not provided)")
    parser.add_argument("--scan-only", action="store_true",
                        help="Only scan and analyze files, don't import")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    if not data_dir.exists():
        print(f"[ERROR] Data directory not found: {data_dir}")
        print("Run 02_download_s3_data.ps1 first to download from S3.")
        sys.exit(1)

    print("=" * 60)
    print("  UNNPI Data Import to PostgreSQL")
    print("=" * 60)
    print()

    # --- Step 1: Scan and analyze files ---
    print("[Step 1] Scanning data directory...")
    print(f"  Path: {data_dir}")
    print()

    catalog = scan_data_directory(data_dir)

    for source, info in catalog["sources"].items():
        print(f"  Source: {source}")
        print(f"    Files: {info['file_count']}")
        print(f"    Size:  {info['total_size_mb']} MB")
        for f in info["files"]:
            ext_tag = f" [{f['extension']}]" if f['extension'] else ""
            print(f"      - {f['name']} ({f['size_mb']} MB){ext_tag}")
            if "analysis" in f and f["analysis"].get("is_datapump"):
                print(f"        Oracle Data Pump detected")
                if f["analysis"]["tables_found"]:
                    print(f"        Tables found: {', '.join(f['analysis']['tables_found'][:10])}")
        print()

    # Save catalog
    catalog_path = data_dir / "file_catalog.json"
    with open(catalog_path, "w") as f:
        json.dump(catalog, f, indent=2, default=str)
    print(f"[OK] File catalog saved to: {catalog_path}")
    print()

    if args.scan_only:
        print("Scan-only mode. Exiting.")
        print()
        print_conversion_guide(catalog)
        return

    # --- Step 2: Import any CSV/SQL files found ---
    if not HAS_PSYCOPG2:
        print("[ERROR] psycopg2 not installed. Install with:")
        print("  pip install psycopg2-binary")
        print()
        print_conversion_guide(catalog)
        sys.exit(1)

    password = args.password
    if not password:
        import getpass
        password = getpass.getpass(f"PostgreSQL password for '{args.user}': ")

    try:
        conn = psycopg2.connect(
            host=args.host, port=args.port,
            dbname=args.db, user=args.user, password=password
        )
    except Exception as e:
        print(f"[ERROR] Could not connect to PostgreSQL: {e}")
        print("Make sure PostgreSQL is running and the database exists.")
        print("Run 03_setup_postgresql.ps1 first.")
        sys.exit(1)

    print("[Step 2] Importing data files...")
    print()

    imported_count = 0
    dmp_files = []

    for source, info in catalog["sources"].items():
        # Map source directories to PostgreSQL schemas
        if "NNSY" in source.upper():
            schema = "nnsy_jedmics"
        elif "PSNS" in source.upper() or source == "test":
            schema = "psns_jedmics"
        elif "CDMD" in source.upper():
            schema = "cdmdoa"
        else:
            schema = "public"

        for f_info in info["files"]:
            filepath = f_info["path"]
            ext = f_info["extension"]

            if ext == ".csv":
                print(f"  Loading CSV: {f_info['name']} -> {schema}...")
                table_name = Path(filepath).stem.lower()
                try:
                    count = load_csv_to_postgres(filepath, table_name, schema, conn)
                    print(f"    [OK] {count} rows loaded into {schema}.{table_name}")
                    imported_count += 1

                    # Log the import
                    cur = conn.cursor()
                    cur.execute("""
                        INSERT INTO public.import_log (source, filename, table_name, row_count, notes)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (source, f_info["name"], f"{schema}.{table_name}", count, "CSV import"))
                    conn.commit()
                    cur.close()
                except Exception as e:
                    print(f"    [ERROR] {e}")

            elif ext == ".sql":
                print(f"  Executing SQL: {f_info['name']} -> {schema}...")
                try:
                    load_sql_to_postgres(filepath, schema, conn)
                    print(f"    [OK] SQL executed in {schema}")
                    imported_count += 1
                except Exception as e:
                    print(f"    [ERROR] {e}")

            elif ext == ".dmp":
                dmp_files.append(f_info)

    conn.close()

    print()
    print(f"[OK] Imported {imported_count} CSV/SQL files.")
    print()

    # --- Step 3: Handle .dmp files ---
    if dmp_files:
        print("=" * 60)
        print("  Oracle Data Pump Files Detected")
        print("=" * 60)
        print()
        print(f"Found {len(dmp_files)} .dmp file(s) that need conversion:")
        for f in dmp_files:
            print(f"  - {f['name']} ({f['size_mb']} MB)")
        print()
        print_conversion_guide(catalog)


def print_conversion_guide(catalog):
    """Print instructions for converting Oracle Data Pump files."""
    print("=" * 60)
    print("  HOW TO CONVERT ORACLE DATA PUMP -> POSTGRESQL")
    print("=" * 60)
    print()
    print("Oracle .dmp files are binary and can't be loaded directly into")
    print("PostgreSQL. Here are your options, from easiest to most involved:")
    print()
    print("OPTION 1: Ask Beast Code for CSV exports (EASIEST)")
    print("-" * 50)
    print("  The Beast Code dev team can export the JEDMICS tables")
    print("  as CSV files from their Oracle instance. Then this script")
    print("  can load them directly. Ask them for:")
    print("    - CSV exports of all JEDMICS tables")
    print("    - Include headers in the CSV files")
    print("    - UTF-8 encoding")
    print()
    print("OPTION 2: Use ora2pg (conversion tool)")
    print("-" * 50)
    print("  ora2pg converts Oracle schemas/data to PostgreSQL.")
    print("  Requires a running Oracle instance to read from.")
    print("  Install: https://ora2pg.darold.net/")
    print("  Steps:")
    print("    1. Stand up Oracle XE (free) on your GFE")
    print("    2. Import the .dmp file: impdp user/pass dumpfile=file.dmp")
    print("    3. Run ora2pg to export to PostgreSQL format")
    print("    4. Load the output into your PostgreSQL database")
    print()
    print("OPTION 3: Oracle XE + manual CSV export")
    print("-" * 50)
    print("  1. Install Oracle XE (free): https://www.oracle.com/database/technologies/xe-downloads.html")
    print("  2. Import the dump:")
    print("     impdp system/password dumpfile=jedmics.dmp directory=DATA_PUMP_DIR")
    print("  3. Use SQL Developer or sqlplus to export each table as CSV")
    print("  4. Re-run this script to load the CSVs into PostgreSQL")
    print()
    print("OPTION 4: Use Python to query Oracle directly")
    print("-" * 50)
    print("  If you install Oracle XE, you can skip PostgreSQL entirely")
    print("  and use python-oracledb to query the data directly:")
    print("    pip install oracledb")
    print("  Then modify 05_query_data.py to connect to Oracle instead.")
    print()
    print("RECOMMENDED: Option 1 is fastest. Ask the Beast Code dev team for CSVs")
    print("of the key tables you need for the drawing counts.")
    print()


if __name__ == "__main__":
    main()
