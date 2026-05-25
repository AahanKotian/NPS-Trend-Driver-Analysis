-- ============================================================
-- STEP 2: NPS Broken Out by User Segment Attributes
-- ============================================================
-- Goal: Calculate NPS separately for each value of each
-- user attribute — device type, region, account age bucket,
-- and app category — to find which segments score lowest.
--
-- Key technique: Multi-level GROUP BY with conditional
-- aggregation. One CTE per segment dimension, then UNION ALL
-- to produce a single comparable table.
-- ============================================================

WITH nps_tagged AS (
  SELECT
    r.review_id,
    r.app_name,
    r.category,
    r.rating,
    r.review_date,
    r.user_id,
    -- Join in user attributes
    ua.device_type,
    ua.region,
    ua.account_age_days,
    -- Account age bucket
    CASE
      WHEN ua.account_age_days <= 30   THEN 'new_user (0-30d)'
      WHEN ua.account_age_days <= 90   THEN 'early (31-90d)'
      WHEN ua.account_age_days <= 365  THEN 'established (91-365d)'
      ELSE                                  'veteran (365d+)'
    END                                               AS age_bucket,
    -- NPS tier
    CASE
      WHEN r.rating >= 4 THEN 'promoter'
      WHEN r.rating = 3  THEN 'passive'
      ELSE                    'detractor'
    END                                               AS nps_tier
  FROM
    reviews r
    LEFT JOIN user_attributes ua ON r.user_id = ua.user_id
  WHERE
    r.rating IS NOT NULL
),

-- ── Reusable NPS calculation macro (as a CTE) ─────────────────
-- Helper: given a segment_type and segment_value, compute NPS
-- We'll reproduce this pattern for each dimension below.

-- ── By Device Type ────────────────────────────────────────────
nps_by_device AS (
  SELECT
    'device_type'                                     AS segment_type,
    COALESCE(device_type, 'unknown')                  AS segment_value,
    COUNT(*)                                          AS review_count,
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
),

-- ── By Region ─────────────────────────────────────────────────
nps_by_region AS (
  SELECT
    'region'                                          AS segment_type,
    COALESCE(region, 'unknown')                       AS segment_value,
    COUNT(*)                                          AS review_count,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )                                                 AS nps_score
  FROM nps_tagged
  GROUP BY region
),

-- ── By Account Age Bucket ─────────────────────────────────────
nps_by_age AS (
  SELECT
    'account_age'                                     AS segment_type,
    COALESCE(age_bucket, 'unknown')                   AS segment_value,
    COUNT(*)                                          AS review_count,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )                                                 AS nps_score
  FROM nps_tagged
  GROUP BY age_bucket
),

-- ── By App Category ───────────────────────────────────────────
nps_by_category AS (
  SELECT
    'category'                                        AS segment_type,
    COALESCE(category, 'unknown')                     AS segment_value,
    COUNT(*)                                          AS review_count,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )                                                 AS nps_score
  FROM nps_tagged
  GROUP BY category
)

-- ── Stack all segments into one table ─────────────────────────
SELECT * FROM nps_by_device
UNION ALL
SELECT * FROM nps_by_region
UNION ALL
SELECT * FROM nps_by_age
UNION ALL
SELECT * FROM nps_by_category
ORDER BY
  segment_type,
  nps_score ASC  -- lowest NPS first — these are the problem segments

-- ---------------------------------------------------------------
-- Multi-level GROUP BY extension:
-- To group by TWO attributes simultaneously (e.g. device + region),
-- add a new CTE:
--
-- SELECT device_type, region, COUNT(*), [nps calc]
-- FROM nps_tagged
-- GROUP BY device_type, region
--
-- This multi-dimensional view is the input to Step 5 (correlated subquery).
-- ---------------------------------------------------------------
