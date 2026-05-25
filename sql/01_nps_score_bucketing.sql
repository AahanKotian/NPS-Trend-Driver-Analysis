-- ============================================================
-- STEP 1: Map Star Ratings to NPS Buckets & Compute Base NPS
-- ============================================================
-- Goal: Transform raw 1–5 star ratings into the three NPS
-- tiers (Promoter, Passive, Detractor), then calculate the
-- overall NPS score.
--
-- This is the foundation every subsequent query builds on.
--
-- NPS mapping:
--   1–2 stars → Detractor  (traditionally score 0–6)
--   3 stars   → Passive    (traditionally score 7–8)
--   4–5 stars → Promoter   (traditionally score 9–10)
--
-- NPS formula:
--   NPS = (promoters / total) * 100 - (detractors / total) * 100
-- ============================================================

-- ── Part A: Tag every review with its NPS tier ────────────────
WITH nps_tagged AS (
  SELECT
    review_id,
    app_name,
    category,
    rating,
    review_date,
    user_id,
    -- Map star rating to NPS bucket
    CASE
      WHEN rating >= 4 THEN 'promoter'
      WHEN rating = 3  THEN 'passive'
      WHEN rating <= 2 THEN 'detractor'
    END                                               AS nps_tier,
    -- Numeric value for averaging and ranking
    CASE
      WHEN rating >= 4 THEN 1
      WHEN rating = 3  THEN 0
      WHEN rating <= 2 THEN -1
    END                                               AS nps_value
  FROM
    reviews
  WHERE
    rating IS NOT NULL
    AND rating BETWEEN 1 AND 5
),

-- ── Part B: Aggregate to overall NPS ─────────────────────────
overall_counts AS (
  SELECT
    COUNT(*)                                          AS total_reviews,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors
  FROM
    nps_tagged
)

SELECT
  total_reviews,
  promoters,
  passives,
  detractors,
  -- Percentage breakdown
  ROUND(100.0 * promoters  / total_reviews, 1)       AS promoter_pct,
  ROUND(100.0 * passives   / total_reviews, 1)       AS passive_pct,
  ROUND(100.0 * detractors / total_reviews, 1)       AS detractor_pct,
  -- Final NPS score (-100 to +100)
  ROUND(
    100.0 * promoters  / total_reviews
    - 100.0 * detractors / total_reviews,
    1
  )                                                   AS nps_score
FROM
  overall_counts

-- ---------------------------------------------------------------
-- FILTER clause syntax (SQLite 3.30+, PostgreSQL, DuckDB):
--   COUNT(*) FILTER (WHERE condition)
--
-- Equivalent using CASE WHEN (universal):
--   SUM(CASE WHEN nps_tier = 'promoter' THEN 1 ELSE 0 END)
--
-- Both approaches are demonstrated — see 04_conditional_agg_deep_dive.sql
-- ---------------------------------------------------------------
