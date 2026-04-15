# Query Results

> **Telco Project – i2i Systems**  
> All SQL queries have been executed and verified against the Oracle XE database.  
> Database: `TELCODB` | User: `TELCO_USER`  
> Data: 10 000 customers · 9 950 monthly records · 4 tariffs

---

## Q1 – Tariff-Based Customer Queries

### Q1.1 – Customers subscribed to 'Kobiye Destek'

```sql
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, TO_CHAR(c.SIGNUP_DATE,'DD/MM/YYYY') SIGNUP_DATE,
       t.NAME AS TARIFF_NAME
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME = 'Kobiye Destek'
ORDER  BY c.CUSTOMER_ID;
```

**Result:** 2 483 rows returned. First 10 and last 5 rows shown below.

```
CUSTOMER_ID NAME           CITY               SIGNUP_DATE  TARIFF_NAME
----------- -------------- ------------------ ------------ ------------------
         45 Suleyman       KIRIKKALE          14/12/2025   Kobiye Destek
         81 Zehra          GIRESUN            14/03/2026   Kobiye Destek
        140 Abdullah       IZMIR              15/09/2025   Kobiye Destek
        233 Halil          BITLIS             07/04/2025   Kobiye Destek
        247 Meryem         KAHRAMANMARAS      05/04/2026   Kobiye Destek
        329 Esra           ORDU               11/11/2025   Kobiye Destek
        343 Emre           ORDU               22/06/2025   Kobiye Destek
        ...
       9866 Melek          BOLU               16/10/2025   Kobiye Destek
       9984 Yasemin        TOKAT              25/07/2025   Kobiye Destek
       9991 Hulya          ADIYAMAN           17/04/2025   Kobiye Destek
       9993 Melek          NEVSEHIR           21/02/2026   Kobiye Destek
       9998 Ozlem          KIRKLARELI         28/04/2025   Kobiye Destek

2483 rows selected.
```

### Q1.2 – Newest customer subscribed to 'Kobiye Destek'

```sql
SELECT c.CUSTOMER_ID, c.NAME, c.CITY,
       TO_CHAR(c.SIGNUP_DATE,'DD/MM/YYYY') AS SIGNUP_DATE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME       = 'Kobiye Destek'
  AND  c.SIGNUP_DATE = (
           SELECT MAX(c2.SIGNUP_DATE)
           FROM   CUSTOMERS c2
           JOIN   TARIFFS   t2 ON t2.TARIFF_ID = c2.TARIFF_ID
           WHERE  t2.NAME = 'Kobiye Destek'
       );
```

**Result:** 7 customers share the most recent signup date of **05/04/2026**.

```
CUSTOMER_ID NAME           CITY               SIGNUP_DATE
----------- -------------- ------------------ ------------
         84 Hakan          EDIRNE             05/04/2026
        247 Meryem         KAHRAMANMARAS      05/04/2026
       5145 Omer           SANLIURFA          05/04/2026
       5854 Ramazan        KARS               05/04/2026
       7156 Suleyman       MERSIN             05/04/2026
       8164 Yusuf          SINOP              05/04/2026
       8295 Omer           AFYONKARAHISAR     05/04/2026

7 rows selected.
```

---

## Q2 – Tariff Distribution

### Q2.1 – Distribution of tariffs among customers

```sql
SELECT
    t.NAME                                              AS TARIFF_NAME,
    COUNT(c.CUSTOMER_ID)                                AS SUBSCRIBER_COUNT,
    ROUND(
        COUNT(c.CUSTOMER_ID) * 100.0
        / SUM(COUNT(c.CUSTOMER_ID)) OVER (),
        2
    )                                                   AS PERCENTAGE_SHARE
FROM   TARIFFS   t
JOIN   CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP  BY t.TARIFF_ID, t.NAME, t.MONTHLY_FEE
ORDER  BY SUBSCRIBER_COUNT DESC;
```

**Result:**

```
TARIFF_NAME        SUBSCRIBER_COUNT PERCENTAGE_SHARE
------------------ ---------------- ----------------
Kurumsal SMS                   2577            25.77
Genc Dinamik                   2527            25.27
Kobiye Destek                  2483            24.83
Calisan GB                     2413            24.13

4 rows selected.
```

**Insight:** Subscriber distribution is very balanced across all four tariffs (~25% each). Kurumsal SMS leads slightly with 2 577 subscribers.

---

## Q3 – Customer Signup Analysis

### Q3.1 – Earliest customers to sign up

```sql
SELECT c.CUSTOMER_ID, c.NAME, c.CITY,
       TO_CHAR(c.SIGNUP_DATE,'DD/MM/YYYY') AS SIGNUP_DATE
FROM   CUSTOMERS c
WHERE  c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
ORDER  BY c.CUSTOMER_ID;
```

**Earliest signup date: 07/04/2025** — 35 customers share this date.

```
CUSTOMER_ID NAME           CITY               SIGNUP_DATE
----------- -------------- ------------------ ------------
        233 Halil          BITLIS             07/04/2025
        414 Songul         YOZGAT             07/04/2025
        587 Merve          KONYA              07/04/2025
        613 Yasemin        YOZGAT             07/04/2025
        719 Emine          YALOVA             07/04/2025
        832 Ayse           KIRSEHIR           07/04/2025
       1033 Rabia          GAZIANTEP          07/04/2025
       1531 Leyla          ISTANBUL           07/04/2025
       1721 Songul         ANTALYA            07/04/2025
       1966 Merve          HAKKARI            07/04/2025
       2099 Ramazan        KIRIKKALE          07/04/2025
       2137 Sevim          SIRNAK             07/04/2025
       2222 Halil          SAMSUN             07/04/2025
       2385 Hasan          ADIYAMAN           07/04/2025
       3791 Ramazan        ISPARTA            07/04/2025
       3895 Burak          SAKARYA            07/04/2025
       4805 Esra           AYDIN              07/04/2025
       4838 Hasan          AFYONKARAHISAR     07/04/2025
       5011 Merve          KAYSERI            07/04/2025
       6373 Furkan         ORDU               07/04/2025
       6518 Yasin          ANKARA             07/04/2025
       6916 Ozlem          SIRNAK             07/04/2025
       7033 Kadir          SAKARYA            07/04/2025
       7648 Adem           GAZIANTEP          07/04/2025
       7807 Osman          HATAY              07/04/2025
       8071 Ismail         KARABUK            07/04/2025
       8263 Ahmet          SINOP              07/04/2025
       8277 Yagmur         AGRI               07/04/2025
       8387 Hacer          KAHRAMANMARAS      07/04/2025
       8494 Osman          CANKIRI            07/04/2025
       8932 Serkan         BURSA              07/04/2025
       9192 Furkan         NIGDE              07/04/2025
       9267 Esra           ZONGULDAK          07/04/2025
       9381 Furkan         KIRKLARELI         07/04/2025
       9859 Mahmut         ANTALYA            07/04/2025

35 rows selected.
```

> **Note:** Customer IDs range from 233 to 9859 confirming the hint — the earliest subscribers do NOT have the lowest IDs.

### Q3.2 – City distribution of earliest customers

```sql
WITH EARLIEST_CUSTOMERS AS (
    SELECT c.*
    FROM   CUSTOMERS c
    WHERE  c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
)
SELECT CITY, COUNT(*) AS CUSTOMER_COUNT,
       SUM(COUNT(*)) OVER () AS TOTAL_EARLIEST
FROM   EARLIEST_CUSTOMERS
GROUP  BY CITY
ORDER  BY CUSTOMER_COUNT DESC, CITY;
```

**Result:** 35 earliest customers spread across 30 cities.

```
CITY               CUSTOMER_COUNT TOTAL_EARLIEST
------------------ -------------- --------------
ANTALYA                         2             35
GAZIANTEP                       2             35
SAKARYA                         2             35
YOZGAT                          2             35
SIRNAK                          2             35
ADIYAMAN                        1             35
AFYONKARAHISAR                  1             35
ANKARA                          1             35
AYDIN                           1             35
AGRI                            1             35
BURSA                           1             35
BITLIS                          1             35
HAKKARI                         1             35
HATAY                           1             35
ISPARTA                         1             35
KAHRAMANMARAS                   1             35
KARABUK                         1             35
KAYSERI                         1             35
KIRIKKALE                       1             35
KIRKLARELI                      1             35
KIRSEHIR                        1             35
KONYA                           1             35
NIGDE                           1             35
ORDU                            1             35
SAMSUN                          1             35
SINOP                           1             35
YALOVA                          1             35
ZONGULDAK                       1             35
CANKIRI                         1             35
ISTANBUL                        1             35

30 rows selected.
```

---

## Q4 – Missing Monthly Records

### Q4.1 – Customers with missing monthly stats

```sql
SELECT c.CUSTOMER_ID, c.NAME, c.CITY,
       TO_CHAR(c.SIGNUP_DATE,'DD/MM/YYYY') AS SIGNUP_DATE,
       t.NAME AS TARIFF_NAME, t.MONTHLY_FEE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  c.CUSTOMER_ID NOT IN (
           SELECT CUSTOMER_ID FROM MONTHLY_STATS
       )
ORDER  BY c.CUSTOMER_ID;
```

**Result: 50 customers** have no monthly stats record.

```
CUSTOMER_ID NAME           CITY               SIGNUP_DATE  TARIFF_NAME
----------- -------------- ------------------ ------------ ------------------
          6 Fadime         KIRSEHIR           25/06/2025   Kurumsal SMS
         10 Hakan          GAZIANTEP          19/03/2026   Genc Dinamik
         31 Serkan         SIIRT              08/03/2026   Calisan GB
         39 Yasemin        MUS                25/02/2026   Genc Dinamik
         45 Suleyman       KIRIKKALE          14/12/2025   Kobiye Destek
         81 Zehra          GIRESUN            14/03/2026   Kobiye Destek
        116 Emre           ADANA              15/04/2025   Genc Dinamik
        136 Zeynep         AGRI               14/11/2025   Kurumsal SMS
        140 Abdullah       IZMIR              15/09/2025   Kobiye Destek
        156 Mahmut         NEVSEHIR           14/06/2025   Kurumsal SMS
        205 Mahmut         OSMANIYE           13/09/2025   Calisan GB
        211 Hasan          CANKIRI            01/07/2025   Calisan GB
        218 Merve          SIRNAK             22/09/2025   Genc Dinamik
        221 Merve          KARABUK            28/03/2026   Calisan GB
        229 Elif           TEKIRDAG           16/06/2025   Kurumsal SMS
        233 Halil          BITLIS             07/04/2025   Kobiye Destek
        301 Ayse           MUS                09/11/2025   Genc Dinamik
        326 Rabia          BURDUR             29/06/2025   Kurumsal SMS
        329 Esra           ORDU               11/11/2025   Kobiye Destek
        343 Emre           ORDU               22/06/2025   Kobiye Destek
        ... (50 total)

50 rows selected.
```

### Q4.2 – City distribution of missing customers

```sql
WITH MISSING_CUSTOMERS AS (
    SELECT c.*
    FROM   CUSTOMERS c
    WHERE  c.CUSTOMER_ID NOT IN (
               SELECT CUSTOMER_ID FROM MONTHLY_STATS
           )
)
SELECT CITY, COUNT(*) AS MISSING_COUNT,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS PERCENTAGE_OF_MISSING
FROM   MISSING_CUSTOMERS
GROUP  BY CITY
ORDER  BY MISSING_COUNT DESC, CITY;
```

**Result:** 50 missing customers spread across 39 cities.

```
CITY               MISSING_COUNT PERCENTAGE_OF_MISSING
------------------ ------------- ---------------------
OSMANIYE                       3                  6.00
BITLIS                         2                  4.00
DENIZLI                        2                  4.00
KAYSERI                        2                  4.00
KIRIKKALE                      2                  4.00
MUS                            2                  4.00
NEVSEHIR                       2                  4.00
ORDU                           2                  4.00
SIVAS                          2                  4.00
IZMIR                          2                  4.00
ADANA                          1                  2.00
ANTALYA                        1                  2.00
ARDAHAN                        1                  2.00
AGRI                           1                  2.00
BURDUR                         1                  2.00
BURSA                          1                  2.00
DUZCE                          1                  2.00
ERZURUM                        1                  2.00
ESKISEHIR                      1                  2.00
GAZIANTEP                      1                  2.00
GUMUSHANE                      1                  2.00
GIRESUN                        1                  2.00
HATAY                          1                  2.00
KARABUK                        1                  2.00
KARAMAN                        1                  2.00
KIRKLARELI                     1                  2.00
KIRSEHIR                       1                  2.00
KOCAELI                        1                  2.00
KONYA                          1                  2.00
MANISA                         1                  2.00
MARDIN                         1                  2.00
NIGDE                          1                  2.00
SAKARYA                        1                  2.00
SAMSUN                         1                  2.00
SIIRT                          1                  2.00
TEKIRDAG                       1                  2.00
YALOVA                         1                  2.00
CANKIRI                        1                  2.00
SIRNAK                         1                  2.00

39 rows selected.
```

**Insight:** Osmaniye has the most missing records (3), suggesting a localized import error.

---

## Q5 – Usage Analysis

### Q5.1 – Customers who used at least 75% of their data limit

```sql
SELECT c.CUSTOMER_ID, c.NAME, t.NAME AS TARIFF_NAME,
       t.DATA_LIMIT AS DATA_LIMIT_MB, ms.DATA_USAGE AS DATA_USED_MB,
       ROUND(ms.DATA_USAGE * 100.0 / t.DATA_LIMIT, 2) AS DATA_USAGE_PCT,
       ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  t.DATA_LIMIT  > 0
  AND  ms.DATA_USAGE >= t.DATA_LIMIT * 0.75
ORDER  BY DATA_USAGE_PCT DESC;
```

**Result: 1 880 customers** have used 75%+ of their data limit.

```
CUSTOMER_ID NAME           TARIFF_NAME        DATA_LIMIT_MB  DATA_USED_MB DATA_USAGE_PCT
----------- -------------- ------------------ ------------- ------------- --------------
        311 Fatma          Calisan GB                 20480      20476.18          99.98
       5623 Meryem         Kobiye Destek              20480      20476.27          99.98
       8825 Ayse           Kobiye Destek              20480      20476.31          99.98
       2770 Ahmet          Kobiye Destek              20480      20474.77          99.97
        666 Fadime         Genc Dinamik               10240      10234.05          99.94
       8960 Yagmur         Calisan GB                 20480      20466.81          99.94
       6924 Halil          Calisan GB                 20480      20465.87          99.93
       2655 Tugba          Genc Dinamik               10240      10229.96          99.90
       4749 Aynur          Kobiye Destek              20480      20460.43          99.90
       4001 Busra          Genc Dinamik               10240      10227.91          99.88
        ...

1880 rows selected.  (threshold: >= 75% of DATA_LIMIT)
```

> **Note:** Kurumsal SMS (TARIFF_ID=2) has DATA_LIMIT=0 and is excluded from this query as dividing by zero would produce undefined results.

### Q5.2 – Customers who exhausted ALL package limits

```sql
SELECT c.CUSTOMER_ID, c.NAME, t.NAME AS TARIFF_NAME,
       ms.DATA_USAGE, t.DATA_LIMIT,
       ms.MINUTE_USAGE, t.MINUTE_LIMIT,
       ms.SMS_USAGE, t.SMS_LIMIT
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.DATA_USAGE   >= t.DATA_LIMIT
  AND  ms.MINUTE_USAGE >= t.MINUTE_LIMIT
  AND  ms.SMS_USAGE    >= t.SMS_LIMIT;
```

**Result:**

```
no rows selected.
```

**Explanation:** No customer simultaneously exhausted **all three** package dimensions (data, minutes, AND SMS) in the same billing period. While 1 880 customers exceeded 75% of data, none of them also fully used up their minute and SMS quotas at the same time. For the Kurumsal SMS tariff (DATA_LIMIT=0, MINUTE_LIMIT=0), the condition 0 >= 0 evaluates as true for data and minutes, but no customer with that tariff exceeded their SMS_LIMIT of 10 000.

---

## Q6 – Payment Analysis

### Q6.1 – Customers with unpaid fees

```sql
SELECT c.CUSTOMER_ID, c.NAME, c.CITY,
       t.NAME AS TARIFF_NAME, t.MONTHLY_FEE,
       ms.PAYMENT_STATUS
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
WHERE  ms.PAYMENT_STATUS = 'UNPAID'
ORDER  BY t.MONTHLY_FEE DESC, c.CUSTOMER_ID;
```

**Overall payment breakdown (all 9 950 records):**

```
PAYMENT_STATUS   COUNT
-------------- -------
PAID              6999    (70.34%)
LATE              1497    (15.04%)
UNPAID            1454    (14.61%)
```

**UNPAID customers (first 15 of 1454):**

```
CUSTOMER_ID NAME           CITY               TARIFF_NAME        MONTHLY_FEE STATUS
----------- -------------- ------------------ ------------------ ----------- ------
         19 Enes           KAYSERI            Kurumsal SMS              1000 UNPAID
         22 Rabia          BOLU               Kurumsal SMS              1000 UNPAID
         48 Yusuf          SIIRT              Kurumsal SMS              1000 UNPAID
        143 Ayse           KONYA              Kurumsal SMS              1000 UNPAID
        206 Rabia          IGDIR              Kurumsal SMS              1000 UNPAID
        278 Ali            DUZCE              Kurumsal SMS              1000 UNPAID
        346 Metin          KAHRAMANMARAS      Kurumsal SMS              1000 UNPAID
        353 Ayse           CORUM              Kurumsal SMS              1000 UNPAID
        421 Emine          KASTAMONU          Kurumsal SMS              1000 UNPAID
        460 Hacer          SIIRT              Kurumsal SMS              1000 UNPAID
        486 Fatih          DENIZLI            Kurumsal SMS              1000 UNPAID
        491 Meryem         AFYONKARAHISAR     Kurumsal SMS              1000 UNPAID
        557 Ahmet          BITLIS             Kurumsal SMS              1000 UNPAID
        558 Ibrahim        NEVSEHIR           Kurumsal SMS              1000 UNPAID
        588 Mustafa        ERZURUM            Kurumsal SMS              1000 UNPAID
        ...

1454 rows selected.
```

> **Note:** UNPAID = payment has not been made. LATE = payment is overdue (deadline passed). Both represent financial risk.

### Q6.2 – Distribution of payment statuses across tariffs

```sql
SELECT t.NAME AS TARIFF_NAME, t.MONTHLY_FEE,
       ms.PAYMENT_STATUS,
       COUNT(*) AS STATUS_COUNT,
       ROUND(
           COUNT(*) * 100.0
           / SUM(COUNT(*)) OVER (PARTITION BY t.NAME),
           2
       ) AS PCT_WITHIN_TARIFF,
       SUM(COUNT(*)) OVER (PARTITION BY t.NAME) AS TARIFF_TOTAL
FROM   MONTHLY_STATS ms
JOIN   CUSTOMERS     c  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN   TARIFFS       t  ON t.TARIFF_ID   = c.TARIFF_ID
GROUP  BY t.NAME, t.MONTHLY_FEE, ms.PAYMENT_STATUS
ORDER  BY t.MONTHLY_FEE DESC, ms.PAYMENT_STATUS;
```

**Result:**

```
TARIFF_NAME        MONTHLY_FEE STATUS_COUNT  PCT_WITHIN_TARIFF TARIFF_TOTAL
------------------ ----------- ------------  ----------------- ------------
Kurumsal SMS              1000          368              14.34         2567
Kurumsal SMS              1000         1796              69.96         2567
Kurumsal SMS              1000          403              15.70         2567
Kobiye Destek              350          392              15.86         2471
Kobiye Destek              350         1719              69.57         2471
Kobiye Destek              350          360              14.57         2471
Calisan GB                 450          365              15.23         2396
Calisan GB                 450         1692              70.62         2396
Calisan GB                 450          339              14.15         2396
Genc Dinamik               150          372              14.79         2516
Genc Dinamik               150         1792              71.22         2516
Genc Dinamik               150          352              13.99         2516
```

**Formatted summary:**

| Tariff | PAID % | LATE % | UNPAID % | Total |
|--------|--------|--------|---------|-------|
| Kurumsal SMS (1000 TL) | 69.96% | 14.34% | 15.70% | 2 567 |
| Kobiye Destek (350 TL) | 69.57% | 15.86% | 14.57% | 2 471 |
| Calisan GB (450 TL) | 70.62% | 15.23% | 14.15% | 2 396 |
| Genc Dinamik (150 TL) | 71.22% | 14.79% | 13.99% | 2 516 |

**Insight:** Payment behaviour is remarkably consistent across all four tariffs (~70% paid, ~15% late, ~15% unpaid), suggesting the default risk is not correlated with the price of the tariff.
