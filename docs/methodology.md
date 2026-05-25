# Methodology

## NPS Formula

Net Promoter Score runs from -100 to +100:

```
NPS = (% Promoters) − (% Detractors)

Example:
  Total reviews:  10,000
  Promoters (4-5★): 4,716 → 47.2%
  Passives  (3★):   2,713 → 27.1%
  Detractors (1-2★): 3,571 → 35.7%

  NPS = 47.2 − 35.7 = +11.5
```

Passives are counted in the denominator but not the numerator — they dilute NPS without actively improving it.

**Industry benchmarks:**
- Below 0: Needs urgent attention
- 0–30: Acceptable
- 30–70: Good
- Above 70: Excellent (Apple, Netflix territory)

---

## Star Rating → NPS Mapping

Traditional NPS uses a 0–10 scale (directly asked: "How likely are you to recommend?"). App store ratings use 1–5 stars. The mapping used here is the industry standard proxy:

| Stars | Traditional NPS | Bucket | Rationale |
|---|---|---|---|
| 5 | 9–10 | Promoter | Strong advocacy |
| 4 | 9–10 | Promoter | Positive but not perfect |
| 3 | 7–8 | Passive | "It's fine" — no advocacy |
| 2 | 0–6 | Detractor | Disappointed |
| 1 | 0–6 | Detractor | Strongly negative |

Some analysts put 4-stars as Passive — this project uses 4+ = Promoter because app store users tend to rate conservatively (4 stars is effectively "highly recommended" in most app categories).

---

## Segment Driver Analysis

### Why Negative Impact Score?

A segment can have a very low NPS but be statistically irrelevant if it's tiny. Conversely, a segment with a moderate NPS gap but huge volume might be the real driver.

**Negative Impact Score** combines both dimensions:

```
negative_impact_score = |gap_vs_overall| × (segment_size / total_reviews)
```

Only segments below the overall NPS are scored. This surfaces the segments where *fixing the problem would move the overall NPS needle most*.

### Minimum Sample Size (HAVING n >= 30)

Without a minimum sample filter, a segment of 2 reviews where both are 1-star shows NPS = -100 and looks like a crisis. We require at least 30 reviews per segment to include it in the driver analysis. Adjust this threshold based on your total review volume.

### Correlated vs. Non-Correlated Subquery

Two subquery patterns appear in the code:

**Scalar subquery** (non-correlated) — runs once, returns one value:
```sql
-- Computes overall NPS once, used in every row
(SELECT overall_nps FROM ...)
```

**Correlated subquery** — runs once *per row*, referencing the outer row:
```sql
-- Computes peer-group average NPS for THIS segment's type
(SELECT AVG(nps) FROM segments WHERE segment_type = a.segment_type)
--                                                   ↑ outer row reference
```

The correlated version is more powerful but more expensive. For large datasets, consider materializing the peer group averages into a CTE first, then joining — same result, better performance.

---

## Data Simulation Notes

The `user_attributes.csv` file is generated with realistic NPS biases:

- **Android budget devices** have the worst NPS (~18 points below average) due to simulated hardware friction
- **Eastern European users** rate ~15 points below average (reflects real localization/pricing friction patterns)
- **New users (0-30 days)** rate ~25 points below average (high initial expectations, early bugs)
- **iOS users** rate ~14 points above average (premium hardware, optimized UX)

These biases ensure the driver analysis surfaces meaningful, realistic findings — not random noise.
