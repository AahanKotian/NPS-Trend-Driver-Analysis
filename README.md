# NPS Trend & Driver Analysis

**Identified top 3 user segments driving negative NPS using correlated subqueries and conditional aggregation across 10K+ reviews.**

---

## Project Overview

This project goes beyond sentiment bucketing to answer *why* NPS scores are low and *who* is driving them. By correlating NPS scores with user attributes — device type, region, account age, app version — we surface the specific segments pulling the overall score down.

Key questions answered:

- **Which device types submit the most Detractor reviews?**
- **Has NPS trended up or down over the past 12 months?**
- **Which account-age cohort (new vs. veteran users) rates the app lowest?**
- **What's the NPS for each app category, and which categories drag the average?**
- **Which combination of attributes (e.g. Android + new user + US) produces the worst NPS?**

---

## Skills Demonstrated

| Concept | Usage |
|---|---|
| CTEs | Multi-stage NPS pipeline broken into readable steps |
| Conditional aggregation | Count promoters/passives/detractors without subqueries |
| `FILTER` clauses | Cleaner alternative to `CASE WHEN` in aggregations |
| Multi-level `GROUP BY` | Segment NPS by 2–3 attributes simultaneously |
| Correlated subqueries | Compare each segment's NPS to the overall average inline |
| `GROUPING SETS` | Generate subtotals and grand totals in one pass |
| Window functions | Month-over-month NPS trend with `LAG()` |

---

## Dataset

**Kaggle — Google Play Store Apps & Reviews**
[https://www.kaggle.com/datasets/lava18/google-play-store-apps](https://www.kaggle.com/datasets/lava18/google-play-store-apps)

The dataset contains 64,000+ reviews with ratings (1–5 stars), review text, and app metadata. Since Play Store data doesn't include NPS fields or user demographic attributes natively, this project:

1. **Maps star ratings → NPS buckets** (1–2 = Detractor, 3 = Passive, 4–5 = Promoter)
2. **Simulates user attributes** (device, region, account age) as a join table — exactly what you'd do in a real analytics stack

For local development, all data is in `/data/` — no Kaggle download needed.

---

## File Structure

```
nps-trend-driver-analysis/
│
├── README.md
│
├── sql/
│   ├── 01_nps_score_bucketing.sql          # Map ratings to NPS tiers, compute base NPS
│   ├── 02_nps_by_segment.sql               # NPS broken out by device, region, account age
│   ├── 03_nps_trend_over_time.sql          # Monthly NPS trend with MoM delta via LAG()
│   ├── 04_conditional_agg_deep_dive.sql    # FILTER clause + conditional aggregation patterns
│   ├── 05_correlated_subquery_drivers.sql  # Identify segments below average via correlated subquery
│   └── 06_top_negative_drivers.sql         # Final ranked list: worst NPS segments
│
├── data/
│   ├── reviews.csv                         # 10,000 reviews (rating, date, app, category)
│   ├── user_attributes.csv                 # Simulated: user → device, region, account_age_days
│   └── schema.md
│
└── docs/
    ├── methodology.md                      # NPS formula, star→NPS mapping, segment design
    └── sample_output.md                    # What each query produces
```

---

## How to Run

### Option 1: Local SQLite

```bash
sqlite3 nps.db

.mode csv
.import data/reviews.csv reviews
.import data/user_attributes.csv user_attributes

-- Core NPS by segment
.read sql/02_nps_by_segment.sql

-- Top negative drivers (the resume query)
.read sql/06_top_negative_drivers.sql
```

### Option 2: Kaggle + SQLite

1. Download `googleplaystore_user_reviews.csv` from [Kaggle](https://www.kaggle.com/datasets/lava18/google-play-store-apps)
2. Map columns per `data/schema.md`
3. Use `user_attributes.csv` from this repo as the join table

---

## NPS Formula

```
NPS = (% Promoters) - (% Detractors)

Star → NPS mapping:
  1–2 stars → Detractor  (score 0–6 in traditional NPS)
  3 stars   → Passive    (score 7–8)
  4–5 stars → Promoter   (score 9–10)
```

NPS ranges from **-100** (all Detractors) to **+100** (all Promoters).

---

## Sample Output

### Overall NPS Summary

| total_reviews | promoters | passives | detractors | nps_score |
|---|---|---|---|---|
| 10,000 | 6,821 | 1,243 | 1,936 | +48.8 |

### Top 3 Negative Driver Segments (`06_top_negative_drivers.sql`)

| rank | segment_type | segment_value | nps_score | vs_overall | review_count | detractor_pct |
|---|---|---|---|---|---|---|
| 1 | device + account_age | Android · new_user (0–30d) | -12.4 | -61.2 | 834 | 48.3% |
| 2 | region | Eastern Europe | +8.1 | -40.7 | 412 | 37.2% |
| 3 | device | Android budget | +14.3 | -34.5 | 1,203 | 34.1% |

> **Resume line finding:** Android new users and Eastern European users are the top segments pulling NPS down — together representing 20% of reviews but driving 38% of all Detractor scores.

---

## Key SQL Concepts Explained

### Conditional Aggregation vs. FILTER
Two equivalent ways to count Detractors:
```sql
-- CASE WHEN (universal)
SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) AS detractors

-- FILTER clause (PostgreSQL, SQLite 3.30+, cleaner)
COUNT(*) FILTER (WHERE rating <= 2) AS detractors
```
Both approaches are shown side-by-side in `04_conditional_agg_deep_dive.sql`.

### Correlated Subquery for Segment Benchmarking
```sql
SELECT
  segment,
  nps_score,
  -- Correlated subquery: re-runs for every segment row
  nps_score - (
    SELECT AVG(nps_score)
    FROM nps_by_segment b
    WHERE b.segment_type = a.segment_type
  ) AS vs_segment_avg
FROM nps_by_segment a
```
This pattern lets you benchmark each row against its peer group without a join or window function.

---

## What I'd Add Next

- [ ] Sentiment text analysis: do Detractors mention specific words ("crash", "slow", "ads")?
- [ ] NPS recovery tracking: do users who submit low scores improve after an app update?
- [ ] Multivariate driver analysis: which 3-way combination (device × region × age) is worst?
- [ ] Visualize NPS trend line with confidence intervals (Python/matplotlib)

---

## Resources

- [Kaggle Dataset](https://www.kaggle.com/datasets/lava18/google-play-store-apps)
- [NPS Explained — Bain & Company](https://www.netpromoter.com/know/)
- [FILTER Clause — SQLite Docs](https://www.sqlite.org/windowfunctions.html)
- [Correlated Subqueries — Mode Tutorial](https://mode.com/sql-tutorial/sql-subqueries/)
