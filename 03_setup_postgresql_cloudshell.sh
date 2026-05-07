#!/bin/bash
# ============================================================
# STEP 3: Set Up PostgreSQL for UNNPI Data (CloudShell Edition)
# ============================================================
# Creates the database and schemas for importing JEDMICS data
# Run in AWS CloudShell (Amazon Linux 2)
# ============================================================

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="postgres"
DB_NAME="unnpi_jedmics"

echo "============================================"
echo "  PostgreSQL Setup for UNNPI Data"
echo "  (CloudShell Edition)"
echo "============================================"
echo ""

# Check if PostgreSQL is installed
if command -v psql &> /dev/null; then
    echo "[OK] PostgreSQL is already installed: $(psql --version)"
else
    echo "[INFO] Installing PostgreSQL..."
    sudo yum update -y
    sudo yum install -y postgresql postgresql-server postgresql-devel

    # Initialize database
    sudo postgresql-setup initdb

    # Start PostgreSQL service
    sudo systemctl start postgresql
    sudo systemctl enable postgresql

    echo "[OK] PostgreSQL installed and started"
fi

echo ""
echo "============================================"
echo "  Database Setup"
echo "============================================"

# Create database and user
sudo -u postgres psql -c "CREATE USER IF NOT EXISTS ${PG_USER} WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "ALTER USER ${PG_USER} CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE IF NOT EXISTS ${DB_NAME} OWNER ${PG_USER};"

echo "[OK] Database '${DB_NAME}' created"
echo "[OK] User '${PG_USER}' configured"

echo ""
echo "============================================"
echo "  Connection Test"
echo "============================================"

# Test connection
PGPASSWORD=postgres psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" -c "SELECT version();"

echo ""
echo "Setup complete! Database connection details:"
echo "Host: ${PG_HOST}"
echo "Port: ${PG_PORT}"
echo "User: ${PG_USER}"
echo "Database: ${DB_NAME}"
echo "Password: postgres"
echo ""
echo "Proceed to Step 4."