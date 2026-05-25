# Dataset Schema

## Table 1: `reviews` (`reviews.csv`)

One row per app review. Maps to `googleplaystore_user_reviews.csv` from Kaggle.

| Column | Type | Description |
|---|---|---|
| `review_id` | INTEGER | Unique review identifier |
| `app_name` | TEXT | App name (e.g. `Chatterbox`, `TaskFlow`) |
| `category` | TEXT | App category (see values below) |
| `rating` | INTEGER | Star rating 1–5 |
| `review_date` | TEXT | Date in `YYYY-MM-DD` format |
| `user_id` | TEXT | Foreign key → `user_attributes.user_id` |

**Categories:** Social, Tools, Entertainment, Productivity, Shopping, Finance, Health & Fitness, Communication, Travel, Education

**Volume:** 10,000 reviews across 8,000 users over Jan–Dec 2022.

**Star → NPS Mapping:**

| Stars | NPS Tier | Rationale |
|---|---|---|
| 4–5 | Promoter | Enthusiastic — would recommend |
| 3 | Passive | Neutral — satisfied but not loyal |
| 1–2 | Detractor | Unhappy — would not recommend |

---

## Table 2: `user_attributes` (`user_attributes.csv`)

One row per user. Simulates UTM + CRM attribute data that would be joined to reviews in a real analytics stack.

| Column | Type | Description |
|---|---|---|
| `user_id` | TEXT | Unique user identifier (e.g. `user_00042`) |
| `device_type` | TEXT | Device category (see values below) |
| `region` | TEXT | Geographic region |
| `account_age_days` | INTEGER | Days since account creation at time of review |

**Device Types:**

| Value | Share | NPS Tendency |
|---|---|---|
| `Android budget` | ~32% | Lowest NPS — hardware limitations cause friction |
| `Android mid-range` | ~23% | Slightly below average |
| `Android flagship` | ~20% | Near average |
| `iOS` | ~25% | Highest NPS — premium UX, fewer crashes |

**Regions:**

| Value | Share | NPS Tendency |
|---|---|---|
| `North America` | ~28% | Above average |
| `Western Europe` | ~22% | Slightly above average |
| `Eastern Europe` | ~12% | Below average |
| `Southeast Asia` | ~18% | Slightly below average |
| `Latin America` | ~12% | Slightly below average |
| `South Asia` | ~8% | Near average |

**Account Age Buckets (computed in SQL):**

| Bucket | Range | NPS Tendency |
|---|---|---|
| `new_user (0-30d)` | 0–30 days | Lowest — high expectations, early frustrations |
| `early (31-90d)` | 31–90 days | Below average |
| `established (91-365d)` | 91–365 days | Near average |
| `veteran (365d+)` | 366+ days | Highest — loyalty effect |

---

## How the Tables Join

```sql
FROM reviews r
LEFT JOIN user_attributes ua ON r.user_id = ua.user_id
```

---

## Mapping to Real Kaggle Dataset

To use the real Kaggle data (`googleplaystore_user_reviews.csv`):

```sql
-- Column mapping:
-- reviews.rating      → Sentiment (map: Positive→5, Neutral→3, Negative→1)
-- reviews.app_name    → App
-- reviews.category    → (join to googleplaystore.csv on App column)
-- reviews.review_date → (not available in Kaggle data — simulate or omit Step 3)
-- reviews.user_id     → (not available — join user_attributes to app or use app as proxy)
```

The Kaggle dataset uses text sentiment labels rather than numeric ratings. The SQL queries handle both — see the comments in `01_nps_score_bucketing.sql`.
