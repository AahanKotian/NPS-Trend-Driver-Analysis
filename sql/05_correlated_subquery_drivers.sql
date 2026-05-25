-- ============================================================
-- STEP 5: Identify Below-Average Segments via Correlated Subquery
-- ============================================================
-- Goal: For every segment, compare its NPS to the overall
-- average for that segment TYPE (not just overall NPS).
--
-- Example: Android budget devices might have NPS = +14, which
-- looks decent vs. overall NPS of +49 — but compared to other
-- device segments averaging +38, it's actually -24 below its
-- peer group. The correlated subquery reveals this.
--
-- Key technique: A correlated subquery references the outer
-- query's row in its WHERE clause — it re-executes for each
-- row in the outer query.
-- ============================================================

WITH nps_tagged AS (
  SELECT
    r.review_id,
    r.rating,
    r.category,
    COALESCE(ua.device_type, 'unknown')               AS device_type,
    COALESCE(ua.region, 'unknown')                    AS region,
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

-- Compute NPS for every (segment_type, segment_value) combination
all_segments AS (
  SELECT 'device_type' AS segment_type, device_type AS segment_value,
         COUNT(*) AS n,
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
               - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1) AS nps_score,
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1) AS detractor_pct
  FROM nps_tagged GROUP BY device_type

  UNION ALL

  SELECT 'region', region,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
               - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY region

  UNION ALL

  SELECT 'account_age', age_bucket,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
               - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY age_bucket

  UNION ALL

  SELECT 'category', category,
         COUNT(*),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='promoter') / COUNT(*)
               - 100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE nps_tier='detractor') / COUNT(*), 1)
  FROM nps_tagged GROUP BY category
)

-- ── Main query: benchmark each segment using a correlated subquery
SELECT
  a.segment_type,
  a.segment_value,
  a.n                                                 AS review_count,
  a.nps_score,
  a.detractor_pct,

  -- Overall NPS (simple scalar subquery — not correlated)
  (
    SELECT ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )
    FROM nps_tagged
  )                                                   AS overall_nps,

  -- ── CORRELATED SUBQUERY ──────────────────────────────────
  -- Average NPS across ALL segments of the same type as the current row.
  -- The WHERE b.segment_type = a.segment_type is the correlation —
  -- it references the outer query's current row (aliased as `a`).
  (
    SELECT ROUND(AVG(b.nps_score), 1)
    FROM   all_segments b
    WHERE  b.segment_type = a.segment_type   -- ← correlation clause
    AND    b.n >= 20
  )                                                   AS avg_nps_for_segment_type,

  -- Gap: how far below peer group average is this segment?
  a.nps_score - (
    SELECT ROUND(AVG(b.nps_score), 1)
    FROM   all_segments b
    WHERE  b.segment_type = a.segment_type
    AND    b.n >= 20
  )                                                   AS vs_peer_group_avg,

  -- Gap vs. overall NPS
  a.nps_score - (
    SELECT ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )
    FROM nps_tagged
  )                                                   AS vs_overall_nps

FROM
  all_segments a
WHERE
  a.n >= 20   -- minimum sample size for credible NPS
ORDER BY
  vs_overall_nps ASC  -- most negative gap first = biggest problem segments

-- ---------------------------------------------------------------
-- How a correlated subquery works:
--   For each row in `all_segments a` (outer query):
--     The database runs the inner SELECT
--     substituting a.segment_type for b.segment_type.
--   This means the inner query executes ONCE PER ROW —
--   it's computationally heavier than a JOIN but expressive
--   for "compare each row to its own peer group" problems.
-- ---------------------------------------------------------------
