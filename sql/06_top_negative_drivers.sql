-- ============================================================
-- STEP 6: Top Negative NPS Drivers — Final Ranked Report
-- ============================================================
-- Goal: Produce the final ranked list of segments pulling
-- NPS below average, prioritized by impact (volume × gap).
--
-- This is the resume query: "Identified top 3 user segments
-- driving negative NPS using correlated subqueries and
-- conditional aggregation across 10K+ reviews."
--
-- Two sections:
--   A) Single-dimension worst segments (device, region, age, category)
--   B) Two-dimension combinations (device × age_bucket) — finds
--      the most dangerous intersection of attributes
-- ============================================================

WITH nps_tagged AS (
  SELECT
    r.review_id,
    r.rating,
    r.category,
    COALESCE(ua.device_type,                   'unknown') AS device_type,
    COALESCE(ua.region,                        'unknown') AS region,
    CASE
      WHEN ua.account_age_days IS NULL         THEN 'unknown'
      WHEN ua.account_age_days <= 30           THEN 'new_user (0-30d)'
      WHEN ua.account_age_days <= 90           THEN 'early (31-90d)'
      WHEN ua.account_age_days <= 365          THEN 'established (91-365d)'
      ELSE                                          'veteran (365d+)'
    END                                              AS age_bucket,
    CASE
      WHEN r.rating >= 4 THEN 'promoter'
      WHEN r.rating = 3  THEN 'passive'
      ELSE                    'detractor'
    END                                              AS nps_tier
  FROM
    reviews r
    LEFT JOIN user_attributes ua ON r.user_id = ua.user_id
  WHERE r.rating IS NOT NULL
),

-- Overall NPS anchor (used in all comparisons)
overall AS (
  SELECT
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    ) AS overall_nps,
    COUNT(*) AS total_reviews
  FROM nps_tagged
),

-- ── A) Single-dimension segments ─────────────────────────────
single_dim AS (
  SELECT 'device_type' AS dim, device_type AS val1, NULL AS val2,
         COUNT(*) AS n,
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
             - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1) AS seg_nps,
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1) AS det_pct
  FROM nps_tagged GROUP BY device_type

  UNION ALL

  SELECT 'region', region, NULL,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
             - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY region

  UNION ALL

  SELECT 'account_age', age_bucket, NULL,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
             - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY age_bucket

  UNION ALL

  SELECT 'category', category, NULL,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
             - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY category
),

-- ── B) Two-dimension combinations ────────────────────────────
two_dim AS (
  SELECT
    'device × age'                                   AS dim,
    device_type                                      AS val1,
    age_bucket                                       AS val2,
    COUNT(*)                                         AS n,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*),
      1
    )                                                AS seg_nps,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*),
      1
    )                                                AS det_pct
  FROM
    nps_tagged
  GROUP BY
    device_type, age_bucket
),

-- Combine and score
all_segs AS (
  SELECT * FROM single_dim
  UNION ALL
  SELECT * FROM two_dim
),

scored AS (
  SELECT
    s.dim                                            AS segment_type,
    CASE WHEN s.val2 IS NULL
         THEN s.val1
         ELSE s.val1 || ' · ' || s.val2
    END                                              AS segment_label,
    s.n                                              AS review_count,
    s.seg_nps                                        AS nps_score,
    s.det_pct                                        AS detractor_pct,
    o.overall_nps,
    ROUND(s.seg_nps - o.overall_nps, 1)             AS gap_vs_overall,
    -- Impact score: how much is this segment dragging down overall NPS?
    -- Larger negative gap × larger review share = higher impact
    ROUND(
      ABS(LEAST(s.seg_nps - o.overall_nps, 0))
      * (1.0 * s.n / o.total_reviews),
      2
    )                                                AS negative_impact_score
  FROM
    all_segs s
    CROSS JOIN overall o
  WHERE
    s.n >= 30                -- minimum sample
    AND s.seg_nps < o.overall_nps  -- only below-average segments
)

SELECT
  DENSE_RANK() OVER (ORDER BY negative_impact_score DESC) AS impact_rank,
  segment_type,
  segment_label,
  review_count,
  nps_score,
  overall_nps,
  gap_vs_overall,
  detractor_pct,
  negative_impact_score
FROM
  scored
ORDER BY
  negative_impact_score DESC
LIMIT 15   -- top 15 problem segments (top 3 are the resume finding)

-- ---------------------------------------------------------------
-- negative_impact_score interpretation:
--   Combines HOW FAR below average a segment is with HOW LARGE
--   that segment is. A segment that is -20 NPS below average
--   and represents 15% of reviews scores higher than a segment
--   that is -50 NPS below average but represents 0.5% of reviews.
--
-- This is the difference between "statistical anomaly" and
-- "actually hurting your overall NPS" — the key business insight.
-- ---------------------------------------------------------------
