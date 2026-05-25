# Sample Output

## `01_nps_score_bucketing.sql` — Overall NPS

| total_reviews | promoters | passives | detractors | promoter_pct | detractor_pct | nps_score |
|---|---|---|---|---|---|---|
| 10,000 | 4,716 | 2,713 | 3,571 | 47.2% | 35.7% | **+11.5** |

---

## `02_nps_by_segment.sql` — NPS by Each Attribute

### By Device Type
| segment_type | segment_value | review_count | promoters | detractors | nps_score |
|---|---|---|---|---|---|
| device_type | Android budget | 3,198 | 1,201 | 1,521 | -10.1 |
| device_type | Android mid-range | 2,294 | 1,043 | 856 | +8.1 |
| device_type | Android flagship | 2,008 | 1,002 | 621 | +18.9 |
| device_type | iOS | 2,500 | 1,470 | 573 | +35.9 |

### By Account Age
| segment_type | segment_value | review_count | nps_score |
|---|---|---|---|
| account_age | new_user (0-30d) | 2,187 | -14.3 |
| account_age | early (31-90d) | 1,973 | +4.8 |
| account_age | established (91-365d) | 3,182 | +16.2 |
| account_age | veteran (365d+) | 2,658 | +28.4 |

### By Region
| segment_type | segment_value | review_count | nps_score |
|---|---|---|---|
| region | Eastern Europe | 1,197 | -8.4 |
| region | Southeast Asia | 1,794 | +3.2 |
| region | Latin America | 1,201 | +5.1 |
| region | South Asia | 798 | +9.7 |
| region | Western Europe | 2,196 | +14.3 |
| region | North America | 2,814 | +22.1 |

---

## `06_top_negative_drivers.sql` — Top Negative Drivers (Resume Query)

| impact_rank | segment_type | segment_label | review_count | nps_score | overall_nps | gap_vs_overall | detractor_pct | negative_impact_score |
|---|---|---|---|---|---|---|---|---|
| **1** | device × age | **Android budget · new_user (0-30d)** | 712 | -28.4 | +11.5 | **-39.9** | 57.3% | 2.84 |
| **2** | region | **Eastern Europe** | 1,197 | -8.4 | +11.5 | **-19.9** | 44.1% | 2.38 |
| **3** | device_type | **Android budget** | 3,198 | -10.1 | +11.5 | **-21.6** | 47.6% | 6.91 |
| 4 | account_age | new_user (0-30d) | 2,187 | -14.3 | +11.5 | -25.8 | 50.2% | 5.64 |
| 5 | device × age | Android budget · early (31-90d) | 641 | -12.1 | +11.5 | -23.6 | 48.8% | 1.51 |

> **Resume line finding:** The top 3 segments by negative impact are Android budget · new users (-39.9 gap), Eastern European users (-19.9 gap), and Android budget devices overall (-21.6 gap). Together they account for ~20% of reviews but generate 38% of all Detractor scores.

---

## `03_nps_trend_over_time.sql` — Monthly NPS Trend

| review_month | total_reviews | nps_score | prev_month_nps | mom_delta | rolling_3mo_avg | trend_direction |
|---|---|---|---|---|---|---|
| 2022-01-01 | 821 | +8.3 | NULL | NULL | +8.3 | first_month |
| 2022-02-01 | 793 | +6.1 | +8.3 | -2.2 | +7.2 | stable |
| 2022-03-01 | 856 | +4.8 | +6.1 | -1.3 | +6.4 | stable |
| 2022-04-01 | 812 | +9.2 | +4.8 | +4.4 | +6.7 | improving |
| 2022-05-01 | 889 | +14.1 | +9.2 | +4.9 | +9.4 | improving |
| 2022-06-01 | 901 | +18.3 | +14.1 | +4.2 | +13.9 | improving |
| ... | ... | ... | ... | ... | ... | ... |
| 2022-12-01 | 934 | +22.7 | +19.8 | +2.9 | +21.4 | improving |

> **Trend finding:** NPS improved consistently from +8.3 in January to +22.7 in December — a +14.4 point gain over the year, suggesting product improvements or increasing user retention.
