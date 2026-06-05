-- STEP 1: SANITY CHECKS
-- Row counts per survey
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


-- STEP 2: MATCH RATE CHECK
-- Adjust emails by upper/lower case and trim potential spaces
SELECT
    COUNT(*)                          AS total_survey_rows,
    COUNT(b.email)                    AS matched_to_behavioral,
    COUNT(*) - COUNT(b.email)         AS unmatched,
    ROUND(
        COUNT(b.email) * 100.0 / COUNT(*), 1
    )                                 AS match_rate_pct
FROM survey_nps s
LEFT JOIN behavioral_data b
    ON LOWER(TRIM(s.email)) = LOWER(TRIM(b.email))


-- STEP 3: QUICK ANALYSIS QUERIES
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


-- STEP 4: DEDUPLICATE BEHAVIORAL DATA
-- Preview duplicates before deduplication
SELECT
    LOWER(TRIM(email))  AS email_normalized,
    COUNT(*)            AS appearances
FROM behavioral_data
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY appearances DESC;



-- STEP 5: FINAL EXPORT QUERY
-- Deduplicates behavioral data via CTE, joins to survey on normalized email, flags user type, and excludes session outliers above a hard cutoff of 12,000 sessions.
WITH behavior_dedup AS (
    SELECT * FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(email))
                ORDER BY first_app_open_d DESC
            ) AS rn
        FROM behavioral_data b
    )
    WHERE rn = 1
)

SELECT
    s.email,
    s.nps,
    s.survey_year,                           
    s.primary_category,
    s.age,
    s.gender,
    b.total_sessions,
    b.birth_year,
    b.region,
    b.first_app_open_d,
    b.follower_count,
    b.w2_active,
    b.m2_active,
    b.lifetime_session,
    b.genres_books,
    b.genres_screenpla,
    b.genres_podcasts,

    CASE
        WHEN b.total_sessions IS NULL THEN 'newsletter'
        ELSE 'app_user'
    END AS user_type

FROM survey_nps s
LEFT JOIN behavioral_data b
    ON LOWER(TRIM(s.email)) = LOWER(TRIM(b.email))

WHERE
    b.total_sessions IS NULL
    OR
    CAST(b.total_sessions AS INTEGER) <= 12000

ORDER BY s.survey_year, s.email;


