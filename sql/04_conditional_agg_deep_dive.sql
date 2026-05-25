-- ============================================================
-- STEP 4: Conditional Aggregation & FILTER Clause Deep Dive
-- ============================================================
-- Goal: Demonstrate both approaches to conditional aggregation
-- side-by-side, then apply multi-level GROUP BY to compute NPS
-- across TWO dimensions simultaneously.
--
-- This file is the skill showcase: it shows you know both
-- syntaxes and can apply them to complex GROUP BY hierarchies.
-- ============================================================

-- ── Part A: CASE WHEN vs FILTER — exact equivalents ──────────

WITH nps_tagged AS (
  SELECT
    r.review_id,
    r.rating,
    r.category,
    ua.device_type,
    ua.region,
    CASE
      WHEN ua.account_age_days <= 30  THEN 'new_user'
      WHEN ua.account_age_days <= 90  THEN 'early'
      WHEN ua.account_age_days <= 365 THEN 'established'
      ELSE                                 'veteran'
    END                                               AS age_bucket,
    CASE
      WHEN r.rating >= 4 THEN 'promoter'
      WHEN r.rating = 3  THEN 'passive'
      ELSE                    'detractor'
    END                                               AS nps_tier
  FROM
    reviews r
    LEFT JOIN user_attributes ua ON r.user_id = ua.user_id
  WHERE r.rating IS NOT NULL
),

-- ── Approach 1: CASE WHEN (works everywhere) ─────────────────
case_when_approach AS (
  SELECT
    'case_when'                                       AS approach,
    device_type,
    COUNT(*)                                          AS total,
    SUM(CASE WHEN nps_tier = 'promoter'  THEN 1 ELSE 0 END) AS promoters,
    SUM(CASE WHEN nps_tier = 'passive'   THEN 1 ELSE 0 END) AS passives,
    SUM(CASE WHEN nps_tier = 'detractor' THEN 1 ELSE 0 END) AS detractors,
    ROUND(
      100.0 * SUM(CASE WHEN nps_tier = 'promoter'  THEN 1 ELSE 0 END) / COUNT(*)
      - 100.0 * SUM(CASE WHEN nps_tier = 'detractor' THEN 1 ELSE 0 END) / COUNT(*),
      1
    )                                                 AS nps_score
  FROM nps_tagged
  GROUP BY device_type
),

-- ── Approach 2: FILTER clause (SQLite 3.30+, PostgreSQL) ─────
filter_approach AS (
  SELECT
    'filter'                                          AS approach,
    device_type,
    COUNT(*)                                          AS total,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )                                                 AS nps_score
  FROM nps_tagged
  GROUP BY device_type
)

-- ── Part B: Multi-level GROUP BY (device × account age) ──────
-- Groups by two dimensions simultaneously, producing one row
-- per unique combination of device_type AND age_bucket.

SELECT
  device_type,
  age_bucket,
  COUNT(*)                                            AS review_count,

  -- Conditional aggregation across BOTH dimensions
  COUNT(*) FILTER (WHERE nps_tier = 'promoter')      AS promoters,
  COUNT(*) FILTER (WHERE nps_tier = 'detractor')     AS detractors,

  ROUND(
    100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
    - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
    1
  )                                                   AS nps_score,

  -- What % of this segment's reviews are detractors?
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
    1
  )                                                   AS detractor_pct,

  -- Average star rating in this segment
  ROUND(AVG(rating), 2)                               AS avg_star_rating

FROM
  nps_tagged
GROUP BY
  device_type,    -- first grouping dimension
  age_bucket      -- second grouping dimension
HAVING
  COUNT(*) >= 20  -- exclude tiny segments (noise filter)
ORDER BY
  nps_score ASC   -- worst segments first

-- ---------------------------------------------------------------
-- HAVING COUNT(*) >= 20:
-- Without a minimum sample filter, a segment with 2 reviews
-- could show NPS = -100 (both detractors) and dominate the
-- report. Setting a minimum makes the findings credible.
-- Adjust the threshold based on your total review volume.
-- ---------------------------------------------------------------
