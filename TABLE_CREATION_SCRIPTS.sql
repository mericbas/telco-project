-- ============================================================
-- FILE   : TABLE_CREATION_SCRIPTS.sql
-- PROJECT: Telco Project - i2i Systems
-- DATE   : April 2026
--
-- SQL*PLUS COMPATIBILITY NOTE:
--   SQLBLANKLINES ON  : allows blank lines inside SQL blocks
--   DEFINE OFF        : prevents & from being treated as substitution
-- ============================================================

SET SQLBLANKLINES ON
SET DEFINE OFF
SET FEEDBACK ON

-- ============================================================
-- FILE   : TABLE_CREATION_SCRIPTS.sql
-- PROJECT: Telco Project - i2i Systems
-- DATE   : April 2026
--
-- DESCRIPTION:
--   Creates the three core tables (TARIFFS, CUSTOMERS,
--   MONTHLY_STATS) together with their primary keys, foreign
--   keys, check constraints, column comments, and indexes.
--
-- RE-RUN SAFETY:
--   Each DROP block silently ignores "table does not exist"
--   errors so the script can be run multiple times without
--   manual cleanup.
--
-- EXECUTION ORDER:
--   1. TARIFFS        (no dependencies)
--   2. CUSTOMERS      (depends on TARIFFS)
--   3. MONTHLY_STATS  (depends on CUSTOMERS)
-- ============================================================


-- ============================================================
-- STEP 0 – Drop existing tables in reverse dependency order
-- ============================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS CASCADE CONSTRAINTS PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TARIFFS CASCADE CONSTRAINTS PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/


-- ============================================================
-- STEP 1 – TARIFFS
--
-- Stores the four available mobile tariff plans.
-- DATA_LIMIT and MINUTE_LIMIT may be 0 for tariffs that
-- include no data / no voice allowance (e.g. Kurumsal SMS).
-- ============================================================

CREATE TABLE TARIFFS (
    TARIFF_ID    NUMBER(2)     NOT NULL,
    NAME         NVARCHAR2(50) NOT NULL,
    MONTHLY_FEE  NUMBER(8,2)   NOT NULL,
    DATA_LIMIT   NUMBER(10)    NOT NULL,   -- MB; 0 = no data allowance
    MINUTE_LIMIT NUMBER(6)     NOT NULL,   -- min; 0 = no voice allowance
    SMS_LIMIT    NUMBER(6)     NOT NULL,   -- count; 0 = no SMS allowance

    -- Primary key
    CONSTRAINT PK_TARIFFS PRIMARY KEY (TARIFF_ID),

    -- Business rules
    CONSTRAINT CHK_TARIFF_FEE    CHECK (MONTHLY_FEE  >  0),
    CONSTRAINT CHK_TARIFF_LIMITS CHECK (
        DATA_LIMIT   >= 0
        AND MINUTE_LIMIT >= 0
        AND SMS_LIMIT    >= 0
    )
);

COMMENT ON TABLE  TARIFFS              IS 'Mobile tariff plans offered to subscribers';
COMMENT ON COLUMN TARIFFS.TARIFF_ID   IS 'Surrogate primary key for the tariff plan';
COMMENT ON COLUMN TARIFFS.NAME        IS 'Commercial name of the tariff plan';
COMMENT ON COLUMN TARIFFS.MONTHLY_FEE IS 'Recurring monthly fee in Turkish Lira';
COMMENT ON COLUMN TARIFFS.DATA_LIMIT  IS 'Monthly data allowance in megabytes (0 = not included)';
COMMENT ON COLUMN TARIFFS.MINUTE_LIMIT IS 'Monthly voice-call allowance in minutes (0 = not included)';
COMMENT ON COLUMN TARIFFS.SMS_LIMIT   IS 'Monthly SMS allowance (0 = not included)';


-- ============================================================
-- STEP 2 – CUSTOMERS
--
-- Stores individual subscriber records.  CUSTOMER_ID values
-- run from 1 to 10 000 but the source CSV is NOT in sorted
-- order, so do not assume ordering from the file matches the
-- numeric sequence of IDs.
-- ============================================================

CREATE TABLE CUSTOMERS (
    CUSTOMER_ID NUMBER(6)      NOT NULL,
    NAME        NVARCHAR2(50)  NOT NULL,
    CITY        NVARCHAR2(50)  NOT NULL,
    SIGNUP_DATE DATE           NOT NULL,
    TARIFF_ID   NUMBER(2)      NOT NULL,

    -- Primary key
    CONSTRAINT PK_CUSTOMERS PRIMARY KEY (CUSTOMER_ID),

    -- Referential integrity
    CONSTRAINT FK_CUSTOMER_TARIFF
        FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID)
);

COMMENT ON TABLE  CUSTOMERS              IS 'Telecom subscriber master records';
COMMENT ON COLUMN CUSTOMERS.CUSTOMER_ID IS 'Unique customer identifier (1–10 000)';
COMMENT ON COLUMN CUSTOMERS.NAME        IS 'First name of the subscriber';
COMMENT ON COLUMN CUSTOMERS.CITY        IS 'City of residence in uppercase Turkish';
COMMENT ON COLUMN CUSTOMERS.SIGNUP_DATE IS 'Date of initial subscription';
COMMENT ON COLUMN CUSTOMERS.TARIFF_ID   IS 'FK – currently active tariff plan';

-- Speed up tariff-based lookups (Q1, Q2, Q6.2)
CREATE INDEX IDX_CUSTOMERS_TARIFF  ON CUSTOMERS (TARIFF_ID);

-- Speed up date-range / MIN-date queries (Q3)
CREATE INDEX IDX_CUSTOMERS_SIGNUP  ON CUSTOMERS (SIGNUP_DATE);

-- Speed up GROUP BY CITY aggregations (Q3.2, Q4.2)
CREATE INDEX IDX_CUSTOMERS_CITY    ON CUSTOMERS (CITY);


-- ============================================================
-- STEP 3 – MONTHLY_STATS
--
-- Stores the current month's usage record for each customer.
-- Due to a known data-insertion error, 50 customers are
-- missing from this table (see Q4 in SOLUTIONS.sql).
--
-- DATA FORMAT NOTE:
--   In the source CSV (MONTHLY_STATS.csv) the DATA_USAGE
--   column uses European decimal notation (comma as decimal
--   separator, e.g. "18420,61" = 18 420.61 MB).  This causes
--   the column to appear as two separate CSV fields for
--   customers with non-integer data usage.  See the import
--   instructions in the README / SETUP.md for how to handle
--   this during SQL*Loader / DBeaver import.
-- ============================================================

CREATE TABLE MONTHLY_STATS (
    STAT_ID        NUMBER(6)    NOT NULL,
    CUSTOMER_ID    NUMBER(6)    NOT NULL,
    DATA_USAGE     NUMBER(10,2) NOT NULL,   -- MB (2 dp)
    MINUTE_USAGE   NUMBER(6)    NOT NULL,   -- minutes used
    SMS_USAGE      NUMBER(6)    NOT NULL,   -- SMS sent
    PAYMENT_STATUS VARCHAR2(10) NOT NULL,

    -- Primary key
    CONSTRAINT PK_MONTHLY_STATS PRIMARY KEY (STAT_ID),

    -- Referential integrity
    CONSTRAINT FK_STATS_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),

    -- Allowed payment status values
    CONSTRAINT CHK_PAYMENT_STATUS
        CHECK (PAYMENT_STATUS IN ('PAID', 'UNPAID', 'LATE')),

    -- Usage values must be non-negative
    CONSTRAINT CHK_STATS_NONNEG
        CHECK (DATA_USAGE >= 0 AND MINUTE_USAGE >= 0 AND SMS_USAGE >= 0)
);

COMMENT ON TABLE  MONTHLY_STATS                IS 'Current-month usage stats per subscriber';
COMMENT ON COLUMN MONTHLY_STATS.STAT_ID        IS 'Surrogate PK for the usage record';
COMMENT ON COLUMN MONTHLY_STATS.CUSTOMER_ID    IS 'FK – links to CUSTOMERS.CUSTOMER_ID';
COMMENT ON COLUMN MONTHLY_STATS.DATA_USAGE     IS 'Data consumed this month in MB (2 dp)';
COMMENT ON COLUMN MONTHLY_STATS.MINUTE_USAGE   IS 'Voice minutes used this month';
COMMENT ON COLUMN MONTHLY_STATS.SMS_USAGE      IS 'SMS messages sent this month';
COMMENT ON COLUMN MONTHLY_STATS.PAYMENT_STATUS IS 'PAID = settled; UNPAID = not paid; LATE = overdue';

-- Speed up JOIN / subquery lookups by customer (Q4, Q5, Q6)
CREATE INDEX IDX_STATS_CUSTOMER ON MONTHLY_STATS (CUSTOMER_ID);

-- Speed up payment-status filtering and grouping (Q6)
CREATE INDEX IDX_STATS_PAYMENT  ON MONTHLY_STATS (PAYMENT_STATUS);

-- Composite index: customer + payment status for combined filters
CREATE INDEX IDX_STATS_CUST_PAY ON MONTHLY_STATS (CUSTOMER_ID, PAYMENT_STATUS);


-- ============================================================
-- VERIFICATION – confirm all objects were created
-- ============================================================

SELECT TABLE_NAME, NUM_ROWS
FROM   USER_TABLES
WHERE  TABLE_NAME IN ('TARIFFS', 'CUSTOMERS', 'MONTHLY_STATS')
ORDER  BY TABLE_NAME;

SELECT INDEX_NAME, TABLE_NAME, UNIQUENESS
FROM   USER_INDEXES
WHERE  TABLE_NAME IN ('TARIFFS', 'CUSTOMERS', 'MONTHLY_STATS')
ORDER  BY TABLE_NAME, INDEX_NAME;
