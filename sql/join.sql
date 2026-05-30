-- =============================================================
-- NPS Retention Analysis — Full Data Pipeline
-- Author: Ross Sauby
-- Tool:   SQLite
-- Description:
--   Combines four NPS survey waves (2021, 2023, 2024, 2025)
--   with Mixpanel behavioral data. Normalizes email casing,
--   flags user type, and excludes session outliers.
-- =============================================================


-- -------------------------------------------------------------
-- STEP 1: SANITY CHECKS
-- Run these before anything else to understand your data.
-- -------------------------------------------------------------

-- Row counts per survey
SELECT 'survey_2021' AS source, COUNT(*) AS rows FROM survey_2021
UNION ALL
SELECT 'survey_nps',            COUNT(*)         FROM survey_nps
UNION ALL
SELECT 'behavioral_data',       COUNT(*)         FROM behavioral_data;

-- Check for duplicate emails in behavioral data
SELECT email, COUNT(*) AS appearances
FROM behavioral_data
GROUP BY email
HAVING COUNT(*) > 1;

-- Check for duplicate emails in combined survey
SELECT email, COUNT(*) AS appearances
FROM survey_nps
GROUP BY email
HAVING COUNT(*) > 1;

-- Survey year breakdown
SELECT survey_year, COUNT(*) AS respondents
FROM survey_nps
GROUP BY survey_year;

-- Preview column names and structure
SELECT * FROM survey_nps       LIMIT 3;
SELECT * FROM behavioral_data  LIMIT 3;


-- -------------------------------------------------------------
-- STEP 2: MATCH RATE CHECK
-- Understand how many survey respondents have behavioral data
-- before committing to the full join.
-- -------------------------------------------------------------

SELECT
    COUNT(*)                          AS total_survey_rows,
    COUNT(b.email)                    AS matched_to_behavioral,
    COUNT(*) - COUNT(b.email)         AS unmatched,
    ROUND(
        COUNT(b.email) * 100.0 / COUNT(*), 1
    )                                 AS match_rate_pct
FROM survey_nps s
LEFT JOIN behavioral_data b
    ON LOWER(s.email) = LOWER(b.email);


-- -------------------------------------------------------------
-- STEP 3: QUICK ANALYSIS QUERIES
-- Useful for validating data before exporting to Python.
-- -------------------------------------------------------------

-- Promoter rate by platform
SELECT
    b.platform,
    COUNT(*)                                        AS total_users,
    ROUND(AVG(CAST(s.nps AS FLOAT)), 2)             AS avg_nps,
    SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END)    AS promoters,
    ROUND(
        SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    )                                               AS promoter_rate_pct
FROM survey_nps s
LEFT JOIN behavioral_data b
    ON LOWER(s.email) = LOWER(b.email)
GROUP BY b.platform;

-- Promoter rate by survey year
SELECT
    s.survey_year,
    COUNT(*)                                        AS total_respondents,
    SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END)    AS promoters,
    ROUND(
        SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    )                                               AS promoter_rate_pct
FROM survey_nps s
GROUP BY s.survey_year
ORDER BY s.survey_year;

-- Promoter rate by primary category
SELECT
    s.primary_category,
    COUNT(*)                                        AS total_respondents,
    SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END)    AS promoters,
    ROUND(
        SUM(CASE WHEN s.nps >= 9 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    )                                               AS promoter_rate_pct
FROM survey_nps s
GROUP BY s.primary_category
ORDER BY promoter_rate_pct DESC;


-- -------------------------------------------------------------
-- STEP 4: DEDUPLICATE BEHAVIORAL DATA
-- The behavioral export contained duplicate email records
-- (same user appearing multiple times). A CTE using ROW_NUMBER()
-- keeps only the most recent record per user before joining.
-- LOWER(TRIM()) applied to handle casing and whitespace variants.
-- -------------------------------------------------------------

-- Preview duplicates before deduplication
SELECT
    LOWER(TRIM(email))  AS email_normalized,
    COUNT(*)            AS appearances
FROM behavioral_data
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY appearances DESC;


-- -------------------------------------------------------------
-- STEP 5: FINAL EXPORT QUERY
-- Deduplicates behavioral data via CTE, joins to survey on
-- normalized email, flags user type, and excludes session
-- outliers above a hard cutoff of 12,000 sessions.
-- -------------------------------------------------------------

WITH behavior_dedup AS (
    SELECT * FROM (
        SELECT
            *,
            -- Assign row number per user, most recent first_app_open first
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(email))
                ORDER BY first_app_open DESC
            ) AS rn
        FROM behavioral_data
    )
    -- Keep only the most recent record per user
    WHERE rn = 1
)

SELECT
    -- Survey fields
    s.email,
    s.nps,
    s.survey                                AS survey_year,
    s.primary_media                         AS primary_category,
    s.age,
    s.gender,

    -- Behavioral fields
    b.total_app_sessions,
    b.first_app_open,
    b.birth_year,
    b.region,

    -- Derived: user type flag
    -- Newsletter users have no Mixpanel match (no session data)
    CASE
        WHEN b.total_app_sessions IS NULL THEN 'newsletter'
        ELSE 'app_user'
    END AS user_type

FROM survey_nps s
LEFT JOIN behavior_dedup b
    ON LOWER(TRIM(s.email)) = LOWER(TRIM(b.email))

WHERE
    -- Retain newsletter users for survey-only models in Python
    b.total_app_sessions IS NULL
    OR
    -- Exclude session outliers (hard cutoff at 12,000 sessions)
    CAST(b.total_app_sessions AS INTEGER) <= 12000

ORDER BY s.survey, s.email;
