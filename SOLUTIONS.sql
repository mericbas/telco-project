-- ============================================================
-- FILE   : SOLUTIONS.sql
-- PROJECT: Telco Project - i2i Systems
-- DATE   : April 2026
--
-- DESCRIPTION:
--   SQL query solutions for all six functional requirements.
--   Every query is preceded by a comment block explaining:
--     • the business question being answered
--     • the approach taken
--     • any edge-cases or assumptions
--
-- TABLES USED:
--   TARIFFS       – 4 rows  (tariff plans)
--   CUSTOMERS     – 10 000 rows (subscriber master)
--   MONTHLY_STATS – ~9 951 rows (current-month usage)
--
-- NOTE ON LIMITS FOR TARIFF 2 (Kurumsal SMS):
--   DATA_LIMIT = 0 and MINUTE_LIMIT = 0.  A limit value of 0
--   means "this service is not included in the package," not
--   "the customer has used everything."  Queries that involve
--   percentage-of-limit calculations (Q5) explicitly exclude
--   or handle zero-limit dimensions to avoid division-by-zero
--   and logical false positives.
-- ============================================================


-- ============================================================
-- Q1 – TARIFF-BASED CUSTOMER QUERIES
-- ============================================================

-- ------------------------------------------------------------
-- Q1.1  List the customers subscribed to the 'Kobiye Destek'
--        tariff.
--
-- APPROACH:
--   We join CUSTOMERS to TARIFFS on TARIFF_ID so that we can
--   filter by the human-readable tariff name rather than
--   hard-coding a numeric ID, making the query resilient to
--   changes in surrogate key values.  The result includes the
--   customer ID, name and city so the output is immediately
--   meaningful to a business user.  An ORDER BY on CUSTOMER_ID
--   is added to give a deterministic, easy-to-verify listing.
-- ------------------------------------------------------------

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME   AS TARIFF_NAME,
    t.MONTHLY_FEE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME = 'Kobiye Destek'
ORDER  BY c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- Q1.2  Find the newest customer who subscribed to the
--        'Kobiye Destek' tariff.
--
-- APPROACH:
--   "Newest" is interpreted as the subscriber with the most
--   recent SIGNUP_DATE among all Kobiye Destek customers.  We
--   use a subquery to determine the maximum signup date within
--   that tariff group, then return every customer who matches
--   that date (handling the unlikely but possible case of
--   multiple people signing up on the same day).  An
--   alternative using RANK() / FETCH FIRST is shown in the
--   comment below for environments that prefer analytic
--   functions.
-- ------------------------------------------------------------

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME       = 'Kobiye Destek'
  AND  c.SIGNUP_DATE = (
           SELECT MAX(c2.SIGNUP_DATE)
           FROM   CUSTOMERS c2
           JOIN   TARIFFS   t2 ON t2.TARIFF_ID = c2.TARIFF_ID
           WHERE  t2.NAME = 'Kobiye Destek'
       );

/* Alternative using analytic RANK() – returns the same result:

SELECT *
FROM (
    SELECT
        c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE,
        t.NAME AS TARIFF_NAME,
        RANK() OVER (ORDER BY c.SIGNUP_DATE DESC) AS RNK
    FROM   CUSTOMERS c
    JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
    WHERE  t.NAME = 'Kobiye Destek'
)
WHERE RNK = 1;
*/


-- ============================================================
-- Q2 – TARIFF DISTRIBUTION
-- ============================================================

-- ------------------------------------------------------------
-- Q2.1  Find the distribution of tariffs among the customers.
--
-- APPROACH:
--   We GROUP BY TARIFF_ID (and include the tariff NAME for
--   readability) and COUNT(*) to get how many customers are
--   subscribed to each plan.  Two additional calculated
--   columns are included: the percentage share (rounded to
--   two decimal places) and a running cumulative count, both
--   of which give business stakeholders a richer picture of
--   how the subscriber base is split across products.  The
--   results are ordered from the most popular to the least
--   popular tariff.
-- ------------------------------------------------------------

SELECT
    t.TARIFF_ID,
    t.NAME                                         AS TARIFF_NAME,
    t.MONTHLY_FEE,
    COUNT(c.CUSTOMER_ID)                           AS SUBSCRIBER_COUNT,
    ROUND(
        COUNT(c.CUSTOMER_ID) * 100.0
        / SUM(COUNT(c.CUSTOMER_ID)) OVER (),
        2
    )                                              AS PERCENTAGE_SHARE,
    SUM(COUNT(c.CUSTOMER_ID))
        OVER (ORDER BY COUNT(c.CUSTOMER_ID) DESC)  AS CUMULATIVE_COUNT
FROM   TARIFFS   t
JOIN   CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP  BY t.TARIFF_ID, t.NAME, t.MONTHLY_FEE
ORDER  BY SUBSCRIBER_COUNT DESC;


-- ============================================================
-- Q3 – CUSTOMER SIGNUP ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- Q3.1  Identify the earliest customers to sign up.
--
-- APPROACH:
--   The task hint explicitly warns that the earliest customers
--   do not necessarily have the lowest CUSTOMER_IDs, meaning
--   we must use SIGNUP_DATE – not the surrogate key – to
--   determine seniority.  We first compute the global minimum
--   signup date via a scalar subquery, then return all
--   customers whose SIGNUP_DATE equals that minimum.  Using
--   MIN() in a subquery is semantically clearer than a HAVING
--   clause and also avoids a full aggregation of the outer
--   result set.  If we needed a broader "earliest cohort"
--   (e.g. first week or first month), a BETWEEN range could
--   replace the equality predicate.
-- ------------------------------------------------------------

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  c.SIGNUP_DATE = (
           SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS
       )
ORDER  BY c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- Q3.2  Distribution of the earliest customers across cities,
--        including the total count for each city.
--
-- APPROACH:
--   Building on Q3.1, we wrap the earliest-customer filter in
--   a CTE (Common Table Expression) named EARLIEST_CUSTOMERS,
--   which makes the logic modular and easy to read.  We then
--   GROUP BY CITY on that CTE result and count occurrences per
--   city.  The TOTAL_EARLIEST column in the SELECT list uses a
--   SUM() OVER () window function so both the per-city count
--   and the grand total appear on every row without a second
--   aggregation pass, enabling a single query to serve both
--   detail and summary needs.
-- ------------------------------------------------------------

WITH EARLIEST_CUSTOMERS AS (
    SELECT c.*
    FROM   CUSTOMERS c
    WHERE  c.SIGNUP_DATE = (
               SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS
           )
)
SELECT
    CITY,
    COUNT(*)                      AS CUSTOMER_COUNT,
    SUM(COUNT(*)) OVER ()         AS TOTAL_EARLIEST
FROM   EARLIEST_CUSTOMERS
GROUP  BY CITY
ORDER  BY CUSTOMER_COUNT DESC, CITY;


-- ============================================================
-- Q4 – MISSING MONTHLY RECORDS
-- ============================================================

-- ------------------------------------------------------------
-- Q4.1  Identify the IDs of customers whose monthly stats
--        record is missing.
--
-- APPROACH:
--   Every customer in the CUSTOMERS table should have exactly
--   one corresponding row in MONTHLY_STATS (one record per
--   billing month per subscriber).  We use a NOT IN subquery
--   to find CUSTOMER_IDs present in CUSTOMERS but absent from
--   MONTHLY_STATS; this is semantically the most direct
--   expression of the business question.  An equivalent LEFT
--   JOIN / IS NULL approach is shown in the comment below and
--   performs identically on indexed columns.  The count of
--   missing customers is included as a second query so the
--   magnitude of the insertion error is immediately visible.
-- ------------------------------------------------------------

-- Full list of missing customer IDs with their details
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME,
    t.MONTHLY_FEE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  c.CUSTOMER_ID NOT IN (
           SELECT CUSTOMER_ID FROM MONTHLY_STATS
       )
ORDER  BY c.CUSTOMER_ID;

-- Count of missing records (quick sanity check)
SELECT COUNT(*) AS MISSING_RECORD_COUNT
FROM   CUSTOMERS
WHERE  CUSTOMER_ID NOT IN (
           SELECT CUSTOMER_ID FROM MONTHLY_STATS
       );

/* Alternative using LEFT JOIN (equivalent, often preferred on large tables):

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM   CUSTOMERS     c
JOIN   TARIFFS       t  ON t.TARIFF_ID  = c.TARIFF_ID
LEFT   JOIN MONTHLY_STATS ms ON ms.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  ms.CUSTOMER_ID IS NULL
ORDER  BY c.CUSTOMER_ID;
*/


-- ------------------------------------------------------------
-- Q4.2  Distribution of the missing customers across cities.
--
-- APPROACH:
--   We reuse the NOT IN pattern from Q4.1 but wrap it in a
--   CTE named MISSING_CUSTOMERS to avoid repetition and keep
--   the city-level GROUP BY clean.  The percentage share
--   column (computed with a window SUM) shows which cities
--   were most affected by the insertion error in relative
--   terms, which is useful for investigating whether the
--   error was geographically correlated (e.g. a regional
--   batch import that partially failed).  Results are sorted
--   by city count descending so the most-affected cities
--   appear first.
-- ------------------------------------------------------------

WITH MISSING_CUSTOMERS AS (
    SELECT c.*
    FROM   CUSTOMERS c
    WHERE  c.CUSTOMER_ID NOT IN (
               SELECT CUSTOMER_ID FROM MONTHLY_STATS
           )
)
SELECT
    CITY,
    COUNT(*)                                            AS MISSING_COUNT,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    )                                                   AS PERCENTAGE_OF_MISSING
FROM   MISSING_CUSTOMERS
GROUP  BY CITY
ORDER  BY MISSING_COUNT DESC, CITY;


-- ============================================================
-- Q5 – USAGE ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- Q5.1  Find the customers who have used at least 75% of
--        their data limit.
--
-- APPROACH:
--   We join MONTHLY_STATS to CUSTOMERS and then to TARIFFS to
--   obtain both the actual DATA_USAGE and the tariff's
--   DATA_LIMIT for each subscriber.  The filter
--   DATA_LIMIT > 0 is essential: Tariff 2 (Kurumsal SMS) has
--   a DATA_LIMIT of 0, meaning data is not part of that plan;
--   dividing by zero or comparing usage against a zero limit
--   would produce meaningless results.  The utilisation ratio
--   is calculated as (DATA_USAGE / DATA_LIMIT) * 100 and we
--   include it in the output so stakeholders can immediately
--   see how close each customer is to exhausting their
--   allowance.
-- ------------------------------------------------------------

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME                                                              AS TARIFF_NAME,
    t.DATA_LIMIT                                                        AS DATA_LIMIT_MB,
    ms.DATA_USAGE                                                       AS DATA_USED_MB,
    ROUND(ms.DATA_USAGE * 100.0 / t.DATA_LIMIT, 2)                    AS DATA_USAGE_PCT,
    ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  t.DATA_LIMIT  > 0                                -- exclude unlimited/non-data tariffs
  AND  ms.DATA_USAGE >= t.DATA_LIMIT * 0.75            -- at least 75% consumed
ORDER  BY DATA_USAGE_PCT DESC, c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- Q5.2  Identify customers who have completely exhausted ALL
--        of their package limits (data, minutes, AND SMS).
--
-- APPROACH:
--   For a customer to have exhausted all limits, their usage
--   must be greater than or equal to every applicable package
--   allowance.  For tariffs where a limit is 0 (e.g. Kurumsal
--   SMS has DATA_LIMIT=0 and MINUTE_LIMIT=0), the comparison
--   0 >= 0 is mathematically true, which effectively means
--   "this dimension does not apply and should not block
--   qualification."  This correctly handles SMS-only tariff
--   subscribers: they qualify if and only if SMS_USAGE >=
--   SMS_LIMIT (the only non-zero limit on their plan).  We
--   include a breakdown of all three utilisation percentages
--   so the reader can verify the logic.
-- ------------------------------------------------------------

SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME                                             AS TARIFF_NAME,
    -- Data
    t.DATA_LIMIT                                       AS DATA_LIMIT_MB,
    ms.DATA_USAGE                                      AS DATA_USED_MB,
    -- Minutes
    t.MINUTE_LIMIT                                     AS MINUTE_LIMIT,
    ms.MINUTE_USAGE                                    AS MINUTES_USED,
    -- SMS
    t.SMS_LIMIT                                        AS SMS_LIMIT,
    ms.SMS_USAGE                                       AS SMS_USED,
    ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.DATA_USAGE   >= t.DATA_LIMIT     -- data exhausted (0>=0 passes for non-data tariffs)
  AND  ms.MINUTE_USAGE >= t.MINUTE_LIMIT  -- minutes exhausted
  AND  ms.SMS_USAGE    >= t.SMS_LIMIT     -- SMS exhausted
ORDER  BY c.CUSTOMER_ID;

-- Count of customers who exhausted all limits
SELECT COUNT(*) AS FULLY_EXHAUSTED_CUSTOMERS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.DATA_USAGE   >= t.DATA_LIMIT
  AND  ms.MINUTE_USAGE >= t.MINUTE_LIMIT
  AND  ms.SMS_USAGE    >= t.SMS_LIMIT;


-- ============================================================
-- Q6 – PAYMENT ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- Q6.1  Find the customers who have unpaid fees.
--
-- APPROACH:
--   The MONTHLY_STATS table tracks three payment statuses:
--   PAID (fee settled), UNPAID (invoice issued but not yet
--   paid), and LATE (overdue – the payment deadline has
--   passed without settlement).  "Unpaid fees" in a billing
--   context most naturally refers to UNPAID records, since
--   those represent customers who owe money and have not yet
--   made any payment; LATE records share the same financial
--   risk and are therefore included in a second query for
--   completeness.  Both queries join to CUSTOMERS and TARIFFS
--   so the output includes the monthly fee amount, helping
--   the billing team prioritise collection efforts.
-- ------------------------------------------------------------

-- Primary answer: strictly UNPAID records
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME          AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.PAYMENT_STATUS = 'UNPAID'
ORDER  BY t.MONTHLY_FEE DESC, c.CUSTOMER_ID;

-- Count of UNPAID records
SELECT COUNT(*) AS UNPAID_CUSTOMER_COUNT
FROM   MONTHLY_STATS
WHERE  PAYMENT_STATUS = 'UNPAID';

-- Extended view: all customers NOT in 'PAID' status (UNPAID + LATE)
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME          AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.PAYMENT_STATUS IN ('UNPAID', 'LATE')
ORDER  BY ms.PAYMENT_STATUS, t.MONTHLY_FEE DESC, c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- Q6.2  Distribution of all payment statuses across the
--        different tariffs.
--
-- APPROACH:
--   We perform a two-level aggregation: first grouping by
--   tariff name and payment status to get raw counts, then
--   applying window functions to compute both the row-level
--   percentage within its tariff group and the overall
--   percentage across all records.  This "pivot-style" output
--   gives management an at-a-glance view of which tariffs
--   carry the highest financial risk (high rates of UNPAID or
--   LATE), enabling targeted collection strategies or tariff
--   re-pricing decisions.  Because we join on TARIFFS we get
--   the human-readable tariff name and monthly fee, keeping
--   the result self-documenting without needing a separate
--   lookup.
-- ------------------------------------------------------------

SELECT
    t.NAME                                                         AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS,
    COUNT(*)                                                       AS STATUS_COUNT,
    -- Percentage within the tariff (how healthy is each plan's payment rate?)
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY t.NAME),
        2
    )                                                              AS PCT_WITHIN_TARIFF,
    -- Percentage across the entire subscriber base
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    )                                                              AS PCT_OF_ALL_RECORDS,
    -- Total subscribers on this tariff (for easy verification)
    SUM(COUNT(*)) OVER (PARTITION BY t.NAME)                      AS TARIFF_TOTAL
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
GROUP  BY t.NAME, t.MONTHLY_FEE, ms.PAYMENT_STATUS
ORDER  BY t.MONTHLY_FEE DESC, ms.PAYMENT_STATUS;


-- ============================================================
-- BONUS – SUMMARY DASHBOARD (optional cross-check query)
--
-- A single query that aggregates key statistics across all
-- questions into one concise view, useful for validating
-- the above individual results against the full dataset.
-- ============================================================

SELECT
    t.NAME                                           AS TARIFF_NAME,
    COUNT(DISTINCT c.CUSTOMER_ID)                    AS TOTAL_CUSTOMERS,
    COUNT(DISTINCT ms.CUSTOMER_ID)                   AS CUSTOMERS_WITH_STATS,
    COUNT(DISTINCT c.CUSTOMER_ID)
        - COUNT(DISTINCT ms.CUSTOMER_ID)             AS MISSING_STATS,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'PAID'   THEN 1 ELSE 0 END)   AS PAID_COUNT,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'UNPAID' THEN 1 ELSE 0 END)   AS UNPAID_COUNT,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'LATE'   THEN 1 ELSE 0 END)   AS LATE_COUNT,
    SUM(CASE
            WHEN t.DATA_LIMIT > 0
             AND ms.DATA_USAGE >= t.DATA_LIMIT * 0.75
            THEN 1 ELSE 0
        END)                                         AS AT_75PCT_DATA,
    SUM(CASE
            WHEN ms.DATA_USAGE   >= t.DATA_LIMIT
             AND ms.MINUTE_USAGE >= t.MINUTE_LIMIT
             AND ms.SMS_USAGE    >= t.SMS_LIMIT
            THEN 1 ELSE 0
        END)                                         AS ALL_LIMITS_EXHAUSTED
FROM   TARIFFS       t
JOIN   CUSTOMERS     c  ON c.TARIFF_ID   = t.TARIFF_ID
LEFT   JOIN MONTHLY_STATS ms ON ms.CUSTOMER_ID = c.CUSTOMER_ID
GROUP  BY t.NAME
ORDER  BY t.NAME;
