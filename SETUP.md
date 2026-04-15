# Setup & Reproduction Guide

> **i2i Systems – Telco Project**  
> Step-by-step instructions for setting up Oracle XE via Docker,  
> connecting with DBeaver, and importing the dataset.

---

## Repository Structure

```
telco-project/
├── data/
│   ├── CUSTOMERS.csv              # Provided dataset – 10 000 subscriber records
│   ├── MONTHLY_STATS.csv          # Provided dataset – monthly usage (9 950 records)
│   └── TARIFFS.csv                # Provided dataset – 4 tariff plans
├── screenshots/                   # Setup and query result screenshots
├── TABLE_CREATION_SCRIPTS.sql     # DDL: CREATE TABLE + indexes + constraints
├── SOLUTIONS.sql                  # All SQL queries with explanations (Q1–Q6)
├── QUERY_RESULTS.md               # Actual output of every query
├── telco_import.py                # Python script for MONTHLY_STATS.csv import
├── docker-compose.yml             # Oracle XE container configuration
├── SETUP.md                       # This file – reproduction guide
└── README.md                      # Project documentation
```

---

## Prerequisites

| Tool | Version | Link |
|------|---------|------|
| Docker Desktop | 4.x+ | https://www.docker.com/products/docker-desktop/ |
| DBeaver Community | 24.x+ | https://dbeaver.io/download/ |

---

## Step 1 – Start the Oracle XE Container

Open a terminal in the project folder and run:

```bash
docker compose up -d
```

This will:
- Pull the `gvenzl/oracle-xe:21-slim-faststart` image (~1 GB, only on first run)
- Start an Oracle XE 21c container named `telco_oracle_xe`
- **Automatically execute** `TABLE_CREATION_SCRIPTS.sql` on first startup (database seeding)
- Expose port **1521** (SQL) and **5500** (Enterprise Manager)

**First-start time:** 3–5 minutes. Monitor progress with:

```bash
docker compose logs -f
```

Wait for: `DATABASE IS READY TO USE!`

Check status:

```bash
docker ps
```

Expected output:
```
CONTAINER ID   IMAGE                             STATUS
xxxxxxxxxxxx   gvenzl/oracle-xe:21-slim-fast…   Up X minutes (healthy)
```

---

## Step 2 – Verify Tables Were Created (Automated Seeding)

```bash
docker exec telco_oracle_xe sqlplus -s "TELCO_USER/Telco2026!@//localhost:1521/TELCODB" <<'EOF'
SELECT TABLE_NAME FROM USER_TABLES
WHERE TABLE_NAME IN ('TARIFFS','CUSTOMERS','MONTHLY_STATS')
ORDER BY TABLE_NAME;
EXIT;
EOF
```

Expected output:
```
TABLE_NAME
------------------------------
CUSTOMERS
MONTHLY_STATS
TARIFFS
```

---

## Step 3 – Connect with DBeaver

1. Open DBeaver → top menu: **Database → New Database Connection**
2. Select **Oracle** → click **Next**
3. Enter the following connection details:

| Field | Value |
|-------|-------|
| Connection Type | **Service Name** |
| Host | `localhost` |
| Port | `1521` |
| Service Name | `TELCODB` |
| Authentication | Database Native |
| Username | `TELCO_USER` |
| Password | `Telco2026!` |

4. Click **Test Connection** → should show **Connected**
5. Click **Finish**

> **Tip:** If you see "No suitable driver found", DBeaver will prompt you to download the Oracle JDBC driver automatically. Click "Download" to install it, then retry.

---

## Step 4 – Import Data

### 4.1 Import TARIFFS.csv

1. In Database Navigator (left panel): expand **TELCO_USER → Tables**
2. Right-click **TARIFFS** → **Import Data** → **CSV**
3. Select `data/TARIFFS.csv`
4. Settings: Delimiter=`,` | Header=✅ | Encoding=`UTF-8`
5. Click **Import** → 4 rows loaded

### 4.2 Import CUSTOMERS.csv

1. Right-click **CUSTOMERS** → **Import Data** → **CSV**
2. Select `data/CUSTOMERS.csv`
3. Settings: Delimiter=`,` | Header=✅ | Encoding=`UTF-8`
4. **Important:** Set date format to `dd/MM/yyyy` for the `SIGNUP_DATE` column
5. Click **Import** → 10 000 rows loaded

### 4.3 Import MONTHLY_STATS.csv

> ⚠️ This file uses a **European comma as decimal separator** in `DATA_USAGE`  
> (e.g., `18420,61` means `18 420.61 MB`), making rows appear to have 7 fields.  
> Use the Python import script below (recommended).

**Recommended: Python import script (handles encoding + decimal comma automatically)**

```bash
# Install the Oracle Python driver (one-time)
pip install oracledb

# From the project root directory:
python telco_import.py
```

---

## Step 5 – Run the Queries

### Option A – DBeaver

1. **File → Open File** → select `SOLUTIONS.sql`  
   *(or drag-drop the file onto the DBeaver window)*
2. In the SQL editor toolbar: click the **connection dropdown** (shows `< No connection >`) → select **TELCO_USER @ TELCODB**
3. Click inside any query block → press **Ctrl+Enter** to execute that single query

### Option B – Terminal (no DBeaver required)

```bash
docker exec -e NLS_LANG=.AL32UTF8 telco_oracle_xe \
  sqlplus -s "TELCO_USER/Telco2026!@//localhost:1521/TELCODB" \
  "@/tmp/SOLUTIONS.sql"
```

---

## Database Schema

```
TARIFFS (4 rows)
┌─────────────────────────────────────────────────────┐
│ TARIFF_ID   NUMBER(2)      PK                       │
│ NAME        NVARCHAR2(50)  NOT NULL                 │
│ MONTHLY_FEE NUMBER(8,2)    NOT NULL  CHECK > 0      │
│ DATA_LIMIT  NUMBER(10)     NOT NULL  (MB, 0=none)   │
│ MINUTE_LIMIT NUMBER(6)     NOT NULL  (0=none)       │
│ SMS_LIMIT   NUMBER(6)      NOT NULL                 │
└─────────────────────────────────────────────────────┘
         │ 1
         │
         │ N
CUSTOMERS (10 000 rows)
┌─────────────────────────────────────────────────────┐
│ CUSTOMER_ID NUMBER(6)      PK                       │
│ NAME        NVARCHAR2(50)  NOT NULL                 │
│ CITY        NVARCHAR2(50)  NOT NULL                 │
│ SIGNUP_DATE DATE           NOT NULL                 │
│ TARIFF_ID   NUMBER(2)      FK → TARIFFS             │
└─────────────────────────────────────────────────────┘
         │ 1
         │
         │ 0..1
MONTHLY_STATS (9 950 rows — 50 missing due to insertion error)
┌─────────────────────────────────────────────────────┐
│ STAT_ID       NUMBER(6)    PK                       │
│ CUSTOMER_ID   NUMBER(6)    FK → CUSTOMERS           │
│ DATA_USAGE    NUMBER(10,2) NOT NULL  (MB)           │
│ MINUTE_USAGE  NUMBER(6)    NOT NULL                 │
│ SMS_USAGE     NUMBER(6)    NOT NULL                 │
│ PAYMENT_STATUS VARCHAR2(10) CHECK IN                │
│               ('PAID','UNPAID','LATE')              │
└─────────────────────────────────────────────────────┘
```

**Indexes:**

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| PK_TARIFFS | TARIFFS | TARIFF_ID | Primary key |
| PK_CUSTOMERS | CUSTOMERS | CUSTOMER_ID | Primary key |
| IDX_CUSTOMERS_TARIFF | CUSTOMERS | TARIFF_ID | Q1, Q2, Q6 lookups |
| IDX_CUSTOMERS_SIGNUP | CUSTOMERS | SIGNUP_DATE | Q3 date queries |
| IDX_CUSTOMERS_CITY | CUSTOMERS | CITY | Q3.2, Q4.2 GROUP BY |
| PK_MONTHLY_STATS | MONTHLY_STATS | STAT_ID | Primary key |
| IDX_STATS_CUSTOMER | MONTHLY_STATS | CUSTOMER_ID | Q4, Q5, Q6 JOINs |
| IDX_STATS_PAYMENT | MONTHLY_STATS | PAYMENT_STATUS | Q6 filtering |
| IDX_STATS_CUST_PAY | MONTHLY_STATS | CUSTOMER_ID, PAYMENT_STATUS | Combined filters |

---

## Default Credentials

| | Value |
|---|---|
| Host | `localhost` |
| Port | `1521` |
| Service Name | `TELCODB` |
| Application User | `TELCO_USER` |
| Application Password | `Telco2026!` |
| SYS/SYSTEM Password | `TelcoAdmin2026` |
| Enterprise Manager | `https://localhost:5500/em` |

---

## Stop / Reset

```bash
# Stop the container (data preserved)
docker compose down

# Full reset – deletes all data
docker compose down -v
docker compose up -d
```

---

## Known Data Issues

| Issue | Detail | Resolution |
|-------|--------|------------|
| European decimal in DATA_USAGE | `MONTHLY_STATS.csv` uses `,` as decimal separator | Handled by the Python import script |
| Missing monthly records | 50 customers have no MONTHLY_STATS row (Q4 answer) | Expected — intentional insertion error in the dataset |
| Non-sequential file order | `CUSTOMERS.csv` is not sorted by CUSTOMER_ID | Use SIGNUP_DATE for chronological analysis (Q3) |
