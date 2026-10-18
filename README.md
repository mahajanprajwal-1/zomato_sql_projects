# zomato_sqlProject

A PostgreSQL case-study project analyzing a Zomato-style food-delivery platform —
data cleaning, customer behavior, restaurant performance, rider logistics, and
time-based trends, solved as 22 real business questions written in SQL.

## About

This project simulates the kind of SQL work a data analyst does at a food-delivery
company: cleaning messy raw data, segmenting customers, measuring restaurant
performance, analyzing delivery/rider efficiency, and spotting trends over time.
Every query is written against a 5-table relational schema and answers a specific,
stated business question — the same format used in real analytics interviews.

**Tech:** PostgreSQL · Window functions · CTEs · Conditional aggregation · Date/time logic

## Schema

```
customers    (customer_id, customer_name, reg_date, ...)
restaurants  (restaurant_id, restaurant_name, city, opening_hours, ...)
orders       (order_id, customer_id, restaurant_id, order_item, order_date,
              order_time, total_amount, order_status, ...)
riders       (rider_id, rider_name, sign_up, ...)
deliveries   (delivery_id, order_id, rider_id, delivery_time, delivery_status, ...)
```

## How this is organized

All queries live in [`queries.sql`](./queries.sql), numbered Q1–Q18, each preceded by
the business question it answers as a SQL comment block — same order they were solved in.

| # | Question | SQL Pattern used |
|---|---|---|
| Q1–Q2 | Data cleaning: find & fix NULLs in `customers`/`restaurants`, delete bad rows in `orders`/`deliveries` | Data quality / `UPDATE` / `DELETE` |
| Q3 | Customers with duplicate names | `GROUP BY` + `HAVING` |
| Q4 | Top 5 dishes ordered by a specific customer in the last year | Pattern 1 — Top-N per Group |
| Q5 | Orders bucketed into 2-hour time slots | `CASE` bucketing |
| Q6 | Customers with AOV (average order value) and 25+ orders | `GROUP BY` + `HAVING` |
| Q7 | High-value customers (total spend > 10,000) | `GROUP BY` + `HAVING` |
| Q8 | Orders with no matching delivery record | Pattern 6 — Anti-Join |
| Q9 | Top restaurants by revenue, last calendar year | Pattern 1 — Top-N per Group |
| Q10 | Most-ordered dish per city | Pattern 1 — Top-N per Group |
| Q11 | Customers who ordered in 2025 but not in 2026 | Set difference via `NOT IN` |
| Q12 | Order cancellation ratio per restaurant, by year | Pattern 8 — Funnel/Conversion Ratio |
| Q13 | Delivery time per order (minutes), handling overnight orders | Date/time arithmetic |
| Q14 | Rider star-rating counts, based on delivery speed | Pattern 7 — Conditional Aggregation |
| Q15 | Month-over-month order growth per restaurant | Pattern 3 — Period-over-Period Growth |
| Q16 | Customer segmentation: Gold vs Silver tier by spend | Pattern 9 — Cohort/Segmentation |
| Q17 | Rider monthly earnings (8% of order total) | `GROUP BY` + aggregation |
| Q18 | Busiest day-of-week per restaurant | Pattern 1 — Top-N per Group |
| Q19 | Customer lifetime value (CLV) | `GROUP BY` + aggregation |
| Q20 | Monthly total sales with previous-month comparison | Pattern 3 — Period-over-Period Growth |
| Q21 | Fastest and slowest riders by average delivery time | Pattern 1 — Top-N per Group |
| Q22 | Order volume by season (Spring/Summer/Winter) | `CASE` bucketing + `GROUP BY` |

## Fixes applied during review

A few queries had bugs caught and corrected before being added here — noted inline in
`queries.sql` as `-- FIX:` comments so the before/after reasoning isn't lost:

- **Q12 (cancellation ratio):** original had two stacked `WITH` keywords (invalid syntax)
  and referenced a CTE name that was never defined. Rebuilt as a single `WITH` chain with
  two properly named, comma-separated CTEs.
- **Q18 (busiest day per restaurant):** original grouped by the raw `order_date` (a specific
  calendar date) instead of the day **name**, which meant every group was effectively a
  single date rather than an aggregate across all occurrences of that weekday. Fixed to
  group by `TO_CHAR(order_date, 'Day')` only.
- **Q21 (fastest/slowest rider):** original CTE chain had a trailing comma before the final
  `SELECT`, which is invalid — a comma means "another CTE follows." Removed, and the final
  `SELECT` was extended to return `rider_id` alongside the min/max values, since knowing
  *which* rider is usually the point of the question.
- **Q17 (rider earnings):** first draft grouped by the raw per-row earnings value instead of
  aggregating with `SUM()`, and didn't account for the data possibly spanning multiple years.
  Fixed to `SUM()` before applying the 8%, and to group by year + month together.

## Tools and skills demonstrated

- Data cleaning (`UPDATE`, `DELETE`, `NULL` handling)
- Joins (`INNER`, `LEFT`) across a 5-table schema
- `GROUP BY` / `HAVING` with multiple aggregate conditions
- Conditional aggregation (`CASE` inside `SUM`/`COUNT`) for pivoting without `PIVOT`
- Window functions (`RANK`, `DENSE_RANK`, `LAG`) for ranking and period-over-period growth
- CTEs, including multi-CTE chains
- Date/time arithmetic, including an overnight-delivery edge case
- Business-metric design: AOV, CLV, cancellation ratio, cohort segmentation

## Known open items / things to revisit

- **Q9** filters to "last calendar year" with `date_trunc('year', CURRENT_DATE) - INTERVAL '1 year'`
  — this is relative to whenever the query runs, so results will silently shift a year forward
  every January. Worth deciding if that's intended or if a fixed year is wanted instead.
- **Q22** (seasons) has an uneven definition: Spring = Apr–Jun, Summer = Jul–Aug (the
  `BETWEEN` excludes month 9 via `<` and `>`, worth double-checking against the intended
  calendar), and everything else falls into `ELSE 'Winter'` — meaning Jan–Mar, Sep–Dec
  are *all* lumped into "Winter." Confirm this matches the actual business definition of
  the three seasons before relying on it.

## Project structure

```
zomato_sqlProject/
├── README.md       -- this file
└── queries.sql      -- all 22 questions + solutions, in solved order
```

## How to run this locally

1. Install PostgreSQL (or use any Postgres-compatible environment, e.g. Supabase, Neon, or a local Docker container).
2. Create the 5 tables (`customers`, `restaurants`, `orders`, `riders`, `deliveries`) matching the schema above, and load your data.
3. Run `queries.sql` top to bottom, or jump to any numbered question — each is self-contained.
