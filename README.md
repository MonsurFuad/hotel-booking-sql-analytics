# Hotel Booking System — Advanced SQL Project

An advanced-level SQL portfolio project analyzing a synthetic hotel booking dataset across 9 interconnected tables and 143,000+ records. Covers joins, subqueries, CTEs, window functions, conditional aggregation, and stored procedures/triggers to solve 25 real-world business problems.

Built with **PostgreSQL**. Data generated synthetically with **Python (Faker)** to guarantee referential integrity while keeping full control over volume, realism, and edge cases.

---

## Project overview

| | |
|---|---|
| **Domain** | Hotel & travel booking platform |
| **Tables** | 9 (hotels, guests, room_types, rooms, staff, seasonal_pricing, bookings, payments, reviews) |
| **Total rows** | 143,299 |
| **Main fact table** | `bookings` — 55,000 rows |
| **Date range** | 2021–2025 (5 years, enables real YoY/seasonal analysis) |
| **Business queries solved** | 25, across 4 difficulty tiers |
| **Advanced techniques** | Window functions (RANK, DENSE_RANK, LAG, LEAD, NTILE), CTEs, anti-joins, conditional aggregation, stored procedures, triggers |

---

## Entity-relationship diagram

`hotels` and `guests` are the two independent parent tables. `bookings` is the central hub — every other transactional table (`payments`, `reviews`) hangs off it, and it in turn references `guests`, `hotels`, and `rooms`. `room_types` bridges `hotels` to both `rooms` and `seasonal_pricing`.

```
hotels ──┬──< room_types ──┬──< rooms ──┐
         ├──< staff        └──< seasonal_pricing
         └──< bookings >───────┐
guests ──┴──< bookings         │
                rooms ──< bookings
                bookings ──┬──< payments
                           └──< reviews >── guests
```

(Full interactive ERD generated separately — see the diagram shared in this conversation.)

---

## Files in this project

| File | Purpose |
|---|---|
| `hotel_booking_schema.sql` | DDL — creates all 9 tables with PK/FK constraints, CHECK constraints, and indexes |
| `generate_data.py` | Generates synthetic CSV data for all 9 tables using Faker, respecting every foreign key |
| `data/*.csv` | The generated dataset (9 files) |
| `hotel_booking_queries.sql` | All 25 business-problem queries, organized in 4 difficulty tiers |
| `README.md` | This file |

---

## Schema design notes

- **CHECK constraints** enforce valid values at the database level (`star_rating` 1–5, `booking_status` in a fixed set, `check_out_date > check_in_date`, etc.) rather than relying on application code.
- **Foreign keys** cascade correctly through the dependency chain: `hotels` → `room_types` → `rooms` → `bookings` → `payments`/`reviews`.
- **Indexes** are added on the most common join/filter columns (`bookings.guest_id`, `bookings.hotel_id`, date ranges) since the fact table has 55,000 rows and several queries filter or join on these repeatedly.

---

## Synthetic data generation

`generate_data.py` builds all 9 tables in dependency order, so every foreign key always points to a real, already-generated parent row — no orphaned references possible by construction. Key design choices:

- **Reproducible**: seeded with `Faker.seed(42)` / `random.seed(42)`, so re-running the script produces an identical dataset.
- **Logically consistent**: a booking's room always belongs to that booking's hotel; a payment's amount is derived from the room's actual price × nights stayed; reviews only exist for `completed` bookings (and only ~45% of those, matching real-world review rates); cancelled bookings skew toward `refunded` payment status.
- **5-year date range (2021–2025)**: long enough to support meaningful year-over-year and multi-year trend queries, rather than a single snapshot.

All foreign key and business-logic integrity was validated programmatically before import (every FK resolves, `check_out_date > check_in_date` holds for all 55,000 bookings, no duplicate primary keys or emails).

> **Note on data realism**: ratings and check-in dates are generated from uniform/weighted-random distributions independent of hotel quality or season. This means queries like "average rating per hotel" or "bookings by month" run correctly and demonstrate the SQL technique well, but won't show dramatic real-world patterns (no hotel is deliberately bad, no month is a true seasonal peak) — that's a property of the synthetic data, not the queries.

---

## Setup instructions

1. **Create a database** (e.g. `hotel_booking_db`) in PostgreSQL. Tables are created in the default `public` schema.
2. **Run the schema script**: execute `hotel_booking_schema.sql` in full — creates all 9 empty tables with constraints and indexes.
3. **Import the data**, in this exact dependency order (parent tables before child tables):
   `hotels → guests → room_types → rooms → staff → seasonal_pricing → bookings → payments → reviews`
   Using `psql`: `\copy <table> FROM 'data/<table>.csv' WITH (FORMAT csv, HEADER true);`
   Using DBeaver: right-click each table → **Import Data** → CSV, in the same order.
4. **Verify row counts** match the expected totals below before running queries.
5. **Run `hotel_booking_queries.sql`** section by section.

### Expected row counts after import

| Table | Rows |
|---|---|
| hotels | 60 |
| guests | 10,000 |
| room_types | 234 |
| rooms | 3,079 |
| staff | 605 |
| seasonal_pricing | 702 |
| bookings | 55,000 |
| payments | 55,000 |
| reviews | 18,619 |

---

## Business problems solved

### Section 1 — Basic (joins, GROUP BY, aggregation)
1. Total revenue by hotel
2. Most booked room type overall
3. Number of bookings per city
4. Average guest rating per hotel
5. Total bookings per month (seasonality check)

### Section 2 — Intermediate (subqueries, CTEs, multi-table joins)
6. Guests who booked more than 3 times
7. Hotel occupancy rate for a given date range
8. Revenue by room type per hotel
9. Hotels with the most low-rated reviews
10. Cancellation rate per hotel
11. Average length of stay per hotel
12. Guests who completed a stay but never left a review (anti-join via `NOT EXISTS`)

### Section 3 — Advanced (window functions, ranking, time-series)
13. Rank hotels by revenue within each state (`RANK() OVER PARTITION BY`)
14. Month-over-month revenue growth/decline per hotel (`LAG()`)
15. Top 5 guests by spend per country, handling ties (`DENSE_RANK()`)
16. Running total of bookings per hotel over the year (cumulative window frame)
17. Rooms with the longest idle gaps between bookings (`LEAD()`)
18. Year-over-year revenue comparison, flagging hotels in decline
19. Average payment delay per hotel
20. Seasonal pricing impact — actual vs. base-price revenue during peak season
21. Bookings-per-staff ratio by hotel star rating
22. Guest spend quartiles (`NTILE(4)`)

### Section 4 — Stretch goals (stored procedures & triggers)
23. `book_room()` — validates availability, inserts booking + payment atomically, raises an exception on date conflicts
24. `cancel_booking()` — updates booking status and auto-refunds the linked payment
25. Trigger `trg_update_room_status` — automatically flips a room's status between `occupied`/`available` on every booking insert or cancellation

All 25 queries and the full procedure/trigger chain (`book_room` → insert → trigger fires → `cancel_booking` → update → trigger fires again) have been tested end-to-end against the live dataset.

---

## Skills demonstrated

- Relational schema design with constraints and referential integrity
- Synthetic data generation with reproducibility and logical consistency
- Multi-table joins, CTEs, and subquery patterns (including anti-joins)
- Window functions: ranking, lag/lead comparisons, cumulative sums, quartile bucketing
- Conditional aggregation (`FILTER`)
- Stored procedures with transactional logic and exception handling (PL/pgSQL)
- Triggers for automatic state synchronization
- ERD documentation
