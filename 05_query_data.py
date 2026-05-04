#!/usr/bin/env python3
"""
STEP 5: Query UNNPI Data in PostgreSQL.

Runs common queries against the imported JEDMICS/CDMD-OA data:
  - Drawing counts by source (NNSY, PSNS)
  - Drawing counts by type/category
  - Collision analysis (duplicate drawings across sources)
  - SDI record summaries
  - Data quality checks

These are the counts and reports Ely Banos needs for Test & Validation.

Usage:
    python 05_query_data.py --db unnpi_jedmics
    python 05_query_data.py --db unnpi_jedmics --report collision
    python 05_query_data.py --db unnpi_jedmics --export-csv
"""

import argparse
import os
import sys
import csv
from pathlib import Path
from datetime import datetime

try:
    import psycopg2
    import psycopg2.extras
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False


# ============================================================
# QUERY DEFINITIONS
# ============================================================

QUERIES = {
    "table_inventory": {
        "title": "Table Inventory (All Schemas)",
        "description": "Lists all tables loaded into the database with row counts.",
        "sql": """
            SELECT
                schemaname AS schema,
                relname AS table_name,
                n_live_tup AS approximate_row_count
            FROM pg_stat_user_tables
            WHERE schemaname IN ('nnsy_jedmics', 'psns_jedmics', 'cdmdoa', 'public')
            ORDER BY schemaname, relname;
        """,
    },

    "import_log": {
        "title": "Import History",
        "description": "Shows what files were imported and when.",
        "sql": """
            SELECT source, filename, table_name, row_count,
                   imported_at, notes
            FROM public.import_log
            ORDER BY imported_at DESC;
        """,
    },

    "drawing_counts_by_source": {
        "title": "Drawing Counts by Source",
        "description": "Total drawing/document counts per shipyard source.",
        "sql": """
            -- This query adapts based on what tables exist.
            -- JEDMICS tables often have names like DRAWING_INDEX, SDI_*, etc.
            -- We'll query each schema's tables dynamically.

            SELECT 'NNSY JEDMICS' AS source,
                   (SELECT COALESCE(SUM(n_live_tup), 0)
                    FROM pg_stat_user_tables
                    WHERE schemaname = 'nnsy_jedmics') AS total_rows
            UNION ALL
            SELECT 'PSNS JEDMICS' AS source,
                   (SELECT COALESCE(SUM(n_live_tup), 0)
                    FROM pg_stat_user_tables
                    WHERE schemaname = 'psns_jedmics') AS total_rows
            UNION ALL
            SELECT 'CDMD-OA' AS source,
                   (SELECT COALESCE(SUM(n_live_tup), 0)
                    FROM pg_stat_user_tables
                    WHERE schemaname = 'cdmdoa') AS total_rows;
        """,
    },

    "drawing_counts_by_table": {
        "title": "Drawing Counts by Table",
        "description": "Row counts per table, sorted by size (largest first).",
        "sql": """
            SELECT
                schemaname || '.' || relname AS full_table_name,
                n_live_tup AS row_count
            FROM pg_stat_user_tables
            WHERE schemaname IN ('nnsy_jedmics', 'psns_jedmics', 'cdmdoa')
              AND n_live_tup > 0
            ORDER BY n_live_tup DESC;
        """,
    },

    "schema_summary": {
        "title": "Schema Column Summary",
        "description": "Shows columns for each table to understand data structure.",
        "sql": """
            SELECT
                table_schema || '.' || table_name AS full_table,
                column_name,
                data_type,
                character_maximum_length
            FROM information_schema.columns
            WHERE table_schema IN ('nnsy_jedmics', 'psns_jedmics', 'cdmdoa')
            ORDER BY table_schema, table_name, ordinal_position;
        """,
    },
}


# Collision analysis queries — these depend on the actual table/column names
# from the JEDMICS data. We provide templates that adapt.
COLLISION_QUERIES = {
    "collision_by_drawing_number": {
        "title": "Collision Analysis: Drawings in Both NNSY and PSNS",
        "description": "Finds drawings that exist in both shipyard databases (potential conflicts for MBPS import).",
        "sql_template": """
            -- This requires knowing the drawing number column name.
            -- Common JEDMICS column names: DRAWING_NO, DWG_NUM, DOCUMENT_ID, SDI_NUMBER
            -- Will be filled in dynamically based on discovered schema.
        """,
    },
}


# ============================================================
# DYNAMIC QUERY BUILDER
# ============================================================

def discover_schema(conn):
    """Discover what tables and columns exist in the database."""
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Get all tables
    cur.execute("""
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema IN ('nnsy_jedmics', 'psns_jedmics', 'cdmdoa')
          AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name;
    """)
    tables = cur.fetchall()

    # Get columns for each table
    schema_info = {}
    for t in tables:
        key = f"{t['table_schema']}.{t['table_name']}"
        cur.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position;
        """, (t['table_schema'], t['table_name']))
        cols = cur.fetchall()
        schema_info[key] = {
            "schema": t['table_schema'],
            "table": t['table_name'],
            "columns": {c['column_name']: c['data_type'] for c in cols},
        }

    cur.close()
    return schema_info


def find_drawing_columns(schema_info):
    """Try to identify which columns contain drawing/document identifiers."""
    drawing_keywords = [
        'drawing_no', 'dwg_num', 'document_id', 'sdi_number',
        'drawing_number', 'doc_number', 'dwg_no', 'draw_no',
        'part_number', 'part_no', 'cage_code',
    ]

    results = {}
    for table_key, info in schema_info.items():
        for col_name in info['columns']:
            col_lower = col_name.lower()
            for keyword in drawing_keywords:
                if keyword in col_lower:
                    if table_key not in results:
                        results[table_key] = []
                    results[table_key].append(col_name)

    return results


def build_collision_query(schema_info, drawing_cols):
    """Build a collision query based on discovered schema."""
    nnsy_tables = {k: v for k, v in drawing_cols.items() if 'nnsy' in k}
    psns_tables = {k: v for k, v in drawing_cols.items() if 'psns' in k}

    if not nnsy_tables or not psns_tables:
        return None

    # Pick the first matching table from each
    nnsy_key = list(nnsy_tables.keys())[0]
    psns_key = list(psns_tables.keys())[0]
    nnsy_col = nnsy_tables[nnsy_key][0]
    psns_col = psns_tables[psns_key][0]

    nnsy_info = schema_info[nnsy_key]
    psns_info = schema_info[psns_key]

    return f"""
        SELECT
            n."{nnsy_col}" AS drawing_id,
            'COLLISION' AS status,
            'Exists in both NNSY and PSNS' AS notes
        FROM {nnsy_info['schema']}."{nnsy_info['table']}" n
        INNER JOIN {psns_info['schema']}."{psns_info['table']}" p
            ON n."{nnsy_col}" = p."{psns_col}"
        LIMIT 1000;
    """


# ============================================================
# REPORT RUNNER
# ============================================================

def run_query(conn, name, query_def, export_dir=None):
    """Run a named query and print/export results."""
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    print(f"\n{'=' * 60}")
    print(f"  {query_def['title']}")
    print(f"{'=' * 60}")
    print(f"  {query_def['description']}")
    print()

    try:
        cur.execute(query_def['sql'])
        rows = cur.fetchall()

        if not rows:
            print("  (no data)")
            cur.close()
            return

        # Print results as formatted table
        columns = list(rows[0].keys())
        col_widths = {}
        for col in columns:
            max_width = len(str(col))
            for row in rows[:100]:  # sample first 100 for sizing
                max_width = max(max_width, len(str(row[col] or '')))
            col_widths[col] = min(max_width, 50)  # cap at 50 chars

        # Header
        header = "  " + " | ".join(str(col).ljust(col_widths[col]) for col in columns)
        print(header)
        print("  " + "-+-".join("-" * col_widths[col] for col in columns))

        # Rows
        for row in rows:
            line = "  " + " | ".join(
                str(row[col] or '').ljust(col_widths[col])[:col_widths[col]]
                for col in columns
            )
            print(line)

        print(f"\n  ({len(rows)} row{'s' if len(rows) != 1 else ''})")

        # Export to CSV if requested
        if export_dir:
            csv_path = export_dir / f"{name}.csv"
            with open(csv_path, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=columns)
                writer.writeheader()
                writer.writerows(rows)
            print(f"  -> Exported to: {csv_path}")

    except Exception as e:
        print(f"  [ERROR] {e}")

    cur.close()


def run_collision_report(conn, export_dir=None):
    """Run collision analysis based on discovered schema."""
    print(f"\n{'=' * 60}")
    print(f"  COLLISION ANALYSIS")
    print(f"{'=' * 60}")
    print()

    schema_info = discover_schema(conn)

    if not schema_info:
        print("  No tables found. Import data first (Step 4).")
        return

    print(f"  Found {len(schema_info)} table(s) across schemas.")
    print()

    # Find drawing-related columns
    drawing_cols = find_drawing_columns(schema_info)

    if not drawing_cols:
        print("  Could not identify drawing/document ID columns automatically.")
        print("  Tables found:")
        for key, info in schema_info.items():
            cols_preview = ', '.join(list(info['columns'].keys())[:5])
            print(f"    {key}: {cols_preview}...")
        print()
        print("  To run collision analysis, identify the drawing number column")
        print("  and modify the query in this script.")
        return

    print("  Drawing/document ID columns found:")
    for table, cols in drawing_cols.items():
        print(f"    {table}: {', '.join(cols)}")
    print()

    # Build and run collision query
    collision_sql = build_collision_query(schema_info, drawing_cols)
    if collision_sql:
        query_def = {
            "title": "Cross-Shipyard Drawing Collisions",
            "description": "Drawings that exist in both NNSY and PSNS (need collision logic for MBPS).",
            "sql": collision_sql,
        }
        run_query(conn, "collisions", query_def, export_dir)
    else:
        print("  Need data in both NNSY and PSNS schemas to run collision analysis.")
        print("  Currently loaded schemas:")
        schemas = set(info['schema'] for info in schema_info.values())
        for s in schemas:
            count = sum(1 for info in schema_info.values() if info['schema'] == s)
            print(f"    {s}: {count} table(s)")


def run_data_quality_report(conn):
    """Run basic data quality checks."""
    print(f"\n{'=' * 60}")
    print(f"  DATA QUALITY CHECKS")
    print(f"{'=' * 60}")
    print()

    schema_info = discover_schema(conn)

    if not schema_info:
        print("  No tables found.")
        return

    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    for table_key, info in schema_info.items():
        schema = info['schema']
        table = info['table']
        columns = info['columns']

        print(f"  Table: {table_key}")

        # Row count
        try:
            cur.execute(f'SELECT COUNT(*) AS cnt FROM {schema}."{table}"')
            count = cur.fetchone()['cnt']
            print(f"    Total rows: {count:,}")
        except Exception as e:
            print(f"    [ERROR counting rows] {e}")
            conn.rollback()
            continue

        if count == 0:
            print("    (empty table)")
            print()
            continue

        # Check for NULL rates in each column
        null_info = []
        for col_name in list(columns.keys())[:20]:  # limit to first 20 cols
            try:
                cur.execute(f"""
                    SELECT COUNT(*) AS nulls
                    FROM {schema}."{table}"
                    WHERE "{col_name}" IS NULL OR CAST("{col_name}" AS TEXT) = ''
                """)
                nulls = cur.fetchone()['nulls']
                pct = round(100 * nulls / count, 1) if count > 0 else 0
                if pct > 0:
                    null_info.append(f"{col_name}: {pct}% null/empty")
            except Exception:
                conn.rollback()

        if null_info:
            print(f"    Columns with nulls/empties:")
            for ni in null_info:
                print(f"      - {ni}")
        else:
            print(f"    All columns populated (checked {min(len(columns), 20)} columns)")

        # Sample values for drawing-related columns
        drawing_cols = find_drawing_columns({table_key: info})
        if table_key in drawing_cols:
            for col in drawing_cols[table_key][:2]:
                try:
                    cur.execute(f"""
                        SELECT DISTINCT "{col}" AS val
                        FROM {schema}."{table}"
                        WHERE "{col}" IS NOT NULL AND "{col}" != ''
                        LIMIT 5
                    """)
                    samples = [r['val'] for r in cur.fetchall()]
                    if samples:
                        print(f"    Sample {col} values: {', '.join(str(s) for s in samples)}")
                except Exception:
                    conn.rollback()

        print()

    cur.close()


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="Query UNNPI data in PostgreSQL — drawing counts, collisions, etc."
    )
    parser.add_argument("--db", default="unnpi_jedmics",
                        help="PostgreSQL database name")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--password", default=None,
                        help="PostgreSQL password (will prompt if not provided)")
    parser.add_argument("--report", default="all",
                        choices=["all", "inventory", "counts", "collision", "quality", "schema"],
                        help="Which report to run")
    parser.add_argument("--export-csv", action="store_true",
                        help="Export query results to CSV files")
    parser.add_argument("--export-dir", default=None,
                        help="Directory for CSV exports (default: current dir)")
    args = parser.parse_args()

    if not HAS_PSYCOPG2:
        print("[ERROR] psycopg2 not installed. Install with:")
        print("  pip install psycopg2-binary")
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

    print("=" * 60)
    print("  UNNPI Data Query Tool")
    print("=" * 60)
    print(f"  Database: {args.db}")
    print(f"  Report:   {args.report}")
    print(f"  Time:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Setup CSV export directory
    export_dir = None
    if args.export_csv:
        export_dir = Path(args.export_dir) if args.export_dir else Path(".")
        export_dir.mkdir(parents=True, exist_ok=True)
        print(f"  Export:   {export_dir}")

    # Run requested reports
    report = args.report

    if report in ("all", "inventory"):
        run_query(conn, "table_inventory", QUERIES["table_inventory"], export_dir)

    if report in ("all", "inventory"):
        run_query(conn, "import_log", QUERIES["import_log"], export_dir)

    if report in ("all", "counts"):
        run_query(conn, "drawing_counts_by_source", QUERIES["drawing_counts_by_source"], export_dir)
        run_query(conn, "drawing_counts_by_table", QUERIES["drawing_counts_by_table"], export_dir)

    if report in ("all", "schema"):
        run_query(conn, "schema_summary", QUERIES["schema_summary"], export_dir)

    if report in ("all", "collision"):
        run_collision_report(conn, export_dir)

    if report in ("all", "quality"):
        run_data_quality_report(conn)

    # Summary
    print()
    print("=" * 60)
    print("  DONE")
    print("=" * 60)
    if export_dir:
        print(f"  CSV exports saved to: {export_dir}")
    print()
    print("Tips:")
    print("  - Run with --report collision to focus on collision analysis")
    print("  - Run with --export-csv to save results for sharing with Ely")
    print("  - Run with --report quality to check data completeness")
    print()

    conn.close()


if __name__ == "__main__":
    main()
