-- ============================================================
-- STEP 3: Monthly NPS Trend with Month-over-Month Delta
-- ============================================================
-- Goal: Calculate NPS for each calendar month and show
-- whether it's improving or declining over time.
--
-- Key techniques:
--   DATE truncation to month for time-series bucketing
--   LAG() to compare current month to previous month
--   Running average to show overall direction of travel
-- ============================================================

WITH nps_tagged AS (
  SELECT
    review_id,
    rating,
    -- Truncate to first of month for grouping
    -- SQLite: strftime('%Y-%m-01', review_date)
    -- PostgreSQL: DATE_TRUNC('month', review_date)
    -- BigQuery: DATE_TRUNC(review_date, MONTH)
    strftime('%Y-%m-01', review_date)                 AS review_month,
    CASE
      WHEN rating >= 4 THEN 'promoter'
      WHEN rating = 3  THEN 'passive'
      ELSE                  'detractor'
    END                                               AS nps_tier
  FROM
    reviews
  WHERE
    rating IS NOT NULL
    AND review_date IS NOT NULL
),

-- Monthly NPS aggregation
monthly_nps AS (
  SELECT
    review_month,
    COUNT(*)                                          AS total_reviews,
    COUNT(*) FILTER (WHERE nps_tier = 'promoter')    AS promoters,
    COUNT(*) FILTER (WHERE nps_tier = 'passive')     AS passives,
    COUNT(*) FILTER (WHERE nps_tier = 'detractor')   AS detractors,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE nps_tier = 'promoter') / COUNT(*)
      - 100.0 * COUNT(*) FILTER (WHERE nps_tier = 'detractor') / COUNT(*),
      1
    )                                                 AS nps_score
  FROM
    nps_tagged
  GROUP BY
    review_month
),

-- Add LAG and trend metrics
monthly_with_trend AS (
  SELECT
    review_month,
    total_reviews,
    promoters,
    passives,
    detractors,
    nps_score,

    -- Previous month's NPS
    LAG(nps_score, 1) OVER (ORDER BY review_month)   AS prev_month_nps,

    -- Month-over-month point change
    nps_score - LAG(nps_score, 1) OVER (
      ORDER BY review_month
    )                                                 AS mom_delta,

    -- 3-month rolling average NPS (smooth out noise)
    ROUND(
      AVG(nps_score) OVER (
        ORDER BY review_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
      ), 1
    )                                                 AS rolling_3mo_avg,

    -- Cumulative average NPS from start of period
    ROUND(
      AVG(nps_score) OVER (
        ORDER BY review_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ), 1
    )                                                 AS cumulative_avg_nps,

    -- Rank months by NPS (best month = rank 1)
    RANK() OVER (ORDER BY nps_score DESC)             AS nps_rank_best,

    -- Is this month above or below the rolling average?
    CASE
      WHEN nps_score > AVG(nps_score) OVER (
             ORDER BY review_month
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           )
      THEN 'above_trend'
      ELSE 'below_trend'
    END                                               AS vs_rolling_avg,

    -- Trend direction vs prior month
    CASE
      WHEN LAG(nps_score, 1) OVER (ORDER BY review_month) IS NULL
        THEN 'first_month'
      WHEN nps_score > LAG(nps_score, 1) OVER (ORDER BY review_month) + 2
        THEN 'improving'
      WHEN nps_score < LAG(nps_score, 1) OVER (ORDER BY review_month) - 2
        THEN 'declining'
      ELSE 'stable'
    END                                               AS trend_direction

  FROM
    monthly_nps
)

SELECT *
FROM   monthly_with_trend
ORDER BY review_month ASC

-- ---------------------------------------------------------------
-- Reading the output:
--   mom_delta > 0  → NPS improved vs. last month
--   mom_delta < 0  → NPS declined vs. last month
--   rolling_3mo_avg flattens single-month spikes (e.g. holiday
--   reviews that skew positive or negative temporarily)
--
-- A sustained drop in rolling_3mo_avg is a much stronger signal
-- than a single bad month.
-- ---------------------------------------------------------------
