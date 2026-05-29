SELECT
    s.email,
    s.nps,
    s.survey_year,
    s.primary_category,
    s.gender,
    s.age,
    b.total_sessions,
    b.follower_count,
    b.w2_active,
    b.m2_active,
    b.genres_books,
    b.genres_screenpla,
    b.genres_podcasts,
    b.first_app_open_d,
    CASE WHEN b.total_sessions IS NULL THEN 'newsletter'
         ELSE 'app_user'
    END AS user_type
FROM survey_nps s
LEFT JOIN behavioral_data b
    ON LOWER(TRIM(s.email)) = LOWER(TRIM(b.email))
WHERE b.total_app_sessio IS NULL
   OR CAST(b.total_sessions AS INTEGER) <= 12000;