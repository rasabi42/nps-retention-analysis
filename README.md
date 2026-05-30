# NPS Retention Analysis — Multi-Year Mixed-Methods Study

**Tools:** Python · SQL · Excel · Power BI · Mixpanel  
**Methods:** Logistic regression · Linear regression · Two-proportion Z-tests  
**Dataset:** 4 survey waves (2021, 2023, 2024, 2025) + Mixpanel behavioral export  

---

## Research Question

As the product transitioned toward a new product (PRODUCTB) and acquisition model, a strategic question emerged: **do media category preferences and early engagement behaviors predict long-term retention and user satisfaction?** And does NPS hold up as the newsletter audience grows?

This project tested three standing product hypotheses using a longitudinal dataset I assembled from four independent NPS surveys combined with behavioral data from Mixpanel.

> **Hypothesis 1:** Users who engage across multiple media categories have longer retention  
> **Hypothesis 2:** Social features (follower count) are associated with higher engagement  
> **Hypothesis 3:** NPS differs meaningfully between ProductA and ProductB users  

---

## Dataset

| Source | Description | N |
|---|---|---|
| NPS Surveys (2021, 2023, 2024, 2025) | Designed, recruited, administered, and analyzed by the author | ~1500 responses |
| Mixpanel Behavioral Export | Total sessions, early retention flags, genre engagement, follower count | Joined on email |

**Key variables:**

- `nps` — raw NPS score (0–10)
- `is_promoter` — binary outcome: 1 if NPS ≥ 9
- `primary_category` — self-reported primary media type (TV/Movies, Books, Podcasts)
- `behavioral_category` — derived from Mixpanel genre flags
- `total_sessions` — lifetime app sessions (log-transformed in models)
- `w2_active` / `m2_active` — binary flags: active at week 2 / month 2
- `follower_count` — social graph size (log-transformed)
- `user_type` — app_user or newsletter (derived from session data presence)
- `survey_year` — 2021, 2023, 2024, or 2025

> **Note:** Raw data is not included in this repo as it contains personally identifiable information. An anonymized sample with the same structure is provided in `/data/analysis_ready.csv`.

---

## Data Pipeline

Data preparation happened in three stages before any analysis:

### Stage 1 — Excel
- Combined four survey exports with differing structures
- Encoded 2025 frequency responses numerically (`Often=3`, `Occasionally=2`, `Rarely=1`, `Never=0`)
- Derived `primary_category` using `TEXTJOIN`/`IFS` with tie handling
- Merged TV and Movies into one combined category for consistency across years

### Stage 2 — SQLite
- Stacked survey waves using `UNION ALL`, preserving year labels and NULL-padding mismatched columns
- Joined Mixpanel export via `LEFT JOIN ON LOWER(email)` to normalize case inconsistencies
- Flagged user type using `CASE WHEN` based on presence of session data
- Excluded session outliers above z-score threshold before export

The full SQL query is in [`/sql/join_and_flag.sql`](sql/join_and_flag.sql).

### Stage 3 — Python
- Loaded single joined CSV into Google Colab
- Engineered `behavioral_category` from Mixpanel genre flags
- Log-transformed `total_sessions` and `follower_count` to address right skew
- Computed `tenure_days` from `first_app_open`

---

## Analysis

Nine statistical models across primary and secondary research questions.

### Primary

| Question | Method | Key Finding |
|---|---|---|
| Does category predict Promoter status? | Logistic regression | TV/Movies+Books users 54% more likely to be Promoters (OR=1.54, p<0.05) |
| How has NPS trended 2021–2025? | Z-tests by year | Significant decline 2021→2025 (39.1% → 26.1%), coinciding with newsletter growth |
| Does engagement predict Promoter status? | Logistic regression | Each unit increase in log_sessions associated with 23% higher Promoter likelihood (OR=1.23) |
| Do app and newsletter users differ? | Z-test | App users: 33.8% Promoter rate vs newsletter users: 24.0% (significant) |

### Secondary / Exploratory

| Question | Method | Key Finding |
|---|---|---|
| Do early retention signals predict sessions? | Linear regression | Both w2_active and m2_active significant positive predictors of long-term sessions |
| Do early retention signals predict NPS? | Logistic regression + Z-test | W2 active users: 37.5% vs 31.6% Promoter rate (significant) |
| Does follower count predict engagement? | Logistic regression | log_followers significant predictor of both sessions and Promoter status (OR=1.18) |
| Do genre interests predict NPS? | Z-tests per genre | Mixed results by genre — see notebook for detail |
| Self-reported vs behavioral category | Model comparison | Behavioral multi-category users 61% more likely to be Promoters (OR=1.61) |

Full model outputs and odds ratio forest plots are in the notebook.

---

## Key Takeaway

Multi-category users — particularly those engaging with TV/Movies and Books together — were significantly more likely to be Promoters and showed higher long-term engagement. The NPS decline between 2021 and 2025 was partly **compositional**: the growing newsletter segment had a lower baseline Promoter rate (24%) than app users (34%), rather than reflecting deteriorating experience among existing users.

**Decision:** Multi-category newsletters were retained as the primary format based on these findings.

**Secondary recommendation:** Early retention intervention. W2 and M2 activity were leading indicators of both sessions and NPS — onboarding investment in the first 8 weeks is likely high-leverage.

---

## Repository Structure

```
nps-retention-analysis/
│
├── README.md
├── data/
│   └── analysis_ready.csv               # Anonymized sample (same structure as full dataset)
├── sql/
│   └── join_and_flag.sql        # Full SQLite pipeline query
├── notebooks/
│   └── nps_regression_analysis.ipynb   # Full analysis notebook
└── outputs/
    ├── p1_nps_trend.png
    ├── p2_category.png
    ├── p3_sessions.png
    ├── p4_user_type.png
    ├── s1_retention_sessions.png
    ├── s2_retention_nps.png
    ├── s3_genres.png
    ├── s4_demographics.png
    ├── s5_followers.png
    └── s6_full_model.png
```

---

## How to Run

1. Clone the repo
2. Open `notebooks/nps_regression_analysis.ipynb` in [Google Colab](https://colab.research.google.com) or Jupyter
3. Upload your own data CSV when prompted in Step 2, or use `data/analysis_ready.csv` to explore the structure
4. Update column mappings in Step 4 if using your own data
5. Run all cells in order

**Dependencies** are installed automatically in the first cell:
```
pandas · numpy · matplotlib · seaborn · statsmodels
```

---

## About

This analysis was conducted as part of a mixed-methods research program during my work for an entertainent company. I designed all four survey instruments, recruited participants, administered the surveys, built the data pipeline, and performed the statistical analysis independently.

**Ross Sauby** — UX Researcher & Data Analyst
[Portfolio](https://rosssauby.myportfolio.com)
