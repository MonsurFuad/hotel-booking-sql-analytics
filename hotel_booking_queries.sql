-- =========================================================================
-- HOTEL BOOKING SYSTEM - ADVANCED SQL PROJECT
-- Business Problems & Solutions (PostgreSQL)
-- Prerequisite: hotel_booking_schema.sql + generate_data.py data loaded
-- =========================================================================
-- Structure: Basic -> Intermediate -> Advanced (window functions) ->
--            Stretch (stored procedures / triggers)
-- Each query has a short comment explaining the business question and
-- the technique being applied, in the same style as the reference project.
-- =========================================================================


-- =========================================================================
-- SECTION 1: BASIC (joins, GROUP BY, aggregation)
-- =========================================================================

-- Q1. Total revenue by hotel
-- Joins bookings -> payments, sums paid amounts per hotel, sorted descending.
-- This is the most fundamental "which hotels make money" question.
SELECT
    h.hotel_id,
    h.name,
    SUM(p.amount) AS total_revenue
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
JOIN payments p ON b.booking_id = p.booking_id
WHERE p.payment_status = 'paid'
GROUP BY h.hotel_id, h.name
ORDER BY total_revenue DESC;


-- Q2. Most booked room type overall
-- Straightforward GROUP BY + COUNT to find booking volume per room type name.
SELECT
    rt.type_name,
    COUNT(b.booking_id) AS times_booked
FROM room_types rt
JOIN rooms r ON rt.room_type_id = r.room_type_id
JOIN bookings b ON r.room_id = b.room_id
GROUP BY rt.type_name
ORDER BY times_booked DESC;


-- Q3. Number of bookings per city
-- Aggregates bookings through the hotel's city, useful for regional demand analysis.
SELECT
    h.city,
    h.state,
    COUNT(b.booking_id) AS total_bookings
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
GROUP BY h.city, h.state
ORDER BY total_bookings DESC;


-- Q4. Average guest rating per hotel
-- AVG() aggregate joined from reviews back to hotels via bookings.
SELECT
    h.hotel_id,
    h.name,
    ROUND(AVG(rv.rating), 2) AS avg_rating,
    COUNT(rv.review_id) AS num_reviews
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
JOIN reviews rv ON b.booking_id = rv.booking_id
GROUP BY h.hotel_id, h.name
HAVING COUNT(rv.review_id) >= 5   -- filter out hotels with too few reviews to be meaningful
ORDER BY avg_rating DESC;


-- Q5. Total bookings per month (seasonality check)
-- DATE_TRUNC groups check-in dates by calendar month across all years.
SELECT
    DATE_TRUNC('month', check_in_date)::DATE AS booking_month,
    COUNT(*) AS total_bookings
FROM bookings
GROUP BY booking_month
ORDER BY booking_month;


-- =========================================================================
-- SECTION 2: INTERMEDIATE (subqueries, multi-table joins, CTEs)
-- =========================================================================

-- Q6. Guests who booked more than 3 times
-- GROUP BY + HAVING filters aggregated results, not raw rows.
SELECT
    g.guest_id,
    g.full_name,
    COUNT(b.booking_id) AS total_bookings
FROM guests g
JOIN bookings b ON g.guest_id = b.guest_id
GROUP BY g.guest_id, g.full_name
HAVING COUNT(b.booking_id) > 3
ORDER BY total_bookings DESC;


-- Q7. Hotel occupancy rate for a given date range (e.g. all of 2025)
-- Occupancy = booked room-nights / (total rooms * days in period).
-- Uses a CTE to first calculate booked nights, then joins to hotel room counts.
WITH booked_nights AS (
    SELECT
        b.hotel_id,
        SUM(b.check_out_date - b.check_in_date) AS total_room_nights_booked
    FROM bookings b
    WHERE b.check_in_date >= '2025-01-01'
      AND b.check_in_date < '2026-01-01'
      AND b.booking_status <> 'cancelled'
    GROUP BY b.hotel_id
)
SELECT
    h.hotel_id,
    h.name,
    h.total_rooms,
    bn.total_room_nights_booked,
    ROUND(
        bn.total_room_nights_booked::NUMERIC / (h.total_rooms * 365) * 100, 2
    ) AS occupancy_rate_pct
FROM hotels h
JOIN booked_nights bn ON h.hotel_id = bn.hotel_id
ORDER BY occupancy_rate_pct DESC;


-- Q8. Revenue by room type per hotel
-- Multi-table join (hotels -> rooms -> room_types -> bookings -> payments),
-- grouped by two dimensions at once.
SELECT
    h.name AS hotel_name,
    rt.type_name,
    SUM(p.amount) AS revenue
FROM hotels h
JOIN rooms r ON h.hotel_id = r.hotel_id
JOIN room_types rt ON r.room_type_id = rt.room_type_id
JOIN bookings b ON r.room_id = b.room_id
JOIN payments p ON b.booking_id = p.booking_id
WHERE p.payment_status = 'paid'
GROUP BY h.name, rt.type_name
ORDER BY h.name, revenue DESC;


-- Q9. Hotels with the most low-rated reviews (below 3 stars)
-- Filters on the review rating, then aggregates by hotel to flag quality issues.
SELECT
    h.hotel_id,
    h.name,
    COUNT(rv.review_id) AS low_rating_count
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
JOIN reviews rv ON b.booking_id = rv.booking_id
WHERE rv.rating < 3
GROUP BY h.hotel_id, h.name
ORDER BY low_rating_count DESC
LIMIT 10;


-- Q10. Cancellation rate per hotel
-- Uses conditional aggregation (FILTER) to compute a percentage in one pass,
-- rather than two separate queries joined together.
SELECT
    h.hotel_id,
    h.name,
    COUNT(b.booking_id) AS total_bookings,
    COUNT(b.booking_id) FILTER (WHERE b.booking_status = 'cancelled') AS cancelled_bookings,
    ROUND(
        COUNT(b.booking_id) FILTER (WHERE b.booking_status = 'cancelled')::NUMERIC
        / COUNT(b.booking_id) * 100, 2
    ) AS cancellation_rate_pct
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
GROUP BY h.hotel_id, h.name
ORDER BY cancellation_rate_pct DESC;


-- Q11. Average length of stay per hotel
-- Computes nights per booking via date subtraction, then averages per hotel.
SELECT
    h.hotel_id,
    h.name,
    ROUND(AVG(b.check_out_date - b.check_in_date), 2) AS avg_nights_stayed
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
WHERE b.booking_status <> 'cancelled'
GROUP BY h.hotel_id, h.name
ORDER BY avg_nights_stayed DESC;


-- Q12. Guests who completed a stay but never left a review
-- Classic "anti-join" pattern using NOT EXISTS, more efficient than a
-- LEFT JOIN ... WHERE IS NULL for large tables since it can short-circuit.
SELECT
    g.guest_id,
    g.full_name,
    b.booking_id,
    b.check_out_date
FROM guests g
JOIN bookings b ON g.guest_id = b.guest_id
WHERE b.booking_status = 'completed'
  AND NOT EXISTS (
      SELECT 1 FROM reviews rv WHERE rv.booking_id = b.booking_id
  )
ORDER BY b.check_out_date DESC
LIMIT 50;


-- =========================================================================
-- SECTION 3: ADVANCED (window functions, ranking, time-series comparisons)
-- =========================================================================

-- Q13. Rank hotels by revenue within each state
-- RANK() OVER (PARTITION BY ...) resets the ranking per state, so each
-- state gets its own #1, #2, #3 hotel by revenue.
WITH hotel_revenue AS (
    SELECT
        h.hotel_id,
        h.name,
        h.state,
        SUM(p.amount) AS revenue
    FROM hotels h
    JOIN bookings b ON h.hotel_id = b.hotel_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.payment_status = 'paid'
    GROUP BY h.hotel_id, h.name, h.state
)
SELECT
    state,
    name,
    revenue,
    RANK() OVER (PARTITION BY state ORDER BY revenue DESC) AS state_rank
FROM hotel_revenue
ORDER BY state, state_rank;


-- Q14. Month-over-month revenue growth/decline per hotel
-- LAG() looks back one row (one month) within each hotel's own timeline
-- to compute the change from the previous month.
WITH monthly_revenue AS (
    SELECT
        b.hotel_id,
        DATE_TRUNC('month', p.payment_date)::DATE AS revenue_month,
        SUM(p.amount) AS revenue
    FROM bookings b
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.payment_status = 'paid'
    GROUP BY b.hotel_id, revenue_month
)
SELECT
    hotel_id,
    revenue_month,
    revenue,
    LAG(revenue) OVER (PARTITION BY hotel_id ORDER BY revenue_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY hotel_id ORDER BY revenue_month))
        / NULLIF(LAG(revenue) OVER (PARTITION BY hotel_id ORDER BY revenue_month), 0) * 100
    , 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY hotel_id, revenue_month;


-- Q15. Top 5 guests by total spend per country, handling ties
-- DENSE_RANK() (rather than RANK()) ensures tied spend amounts share the
-- same rank without skipping the next rank number.
WITH guest_spend AS (
    SELECT
        g.guest_id,
        g.full_name,
        g.country,
        SUM(p.amount) AS total_spend
    FROM guests g
    JOIN bookings b ON g.guest_id = b.guest_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.payment_status = 'paid'
    GROUP BY g.guest_id, g.full_name, g.country
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY country ORDER BY total_spend DESC) AS spend_rank
    FROM guest_spend
)
SELECT *
FROM ranked
WHERE spend_rank <= 5
ORDER BY country, spend_rank;


-- Q16. Running total of bookings per hotel over 2025
-- A cumulative window frame (ROWS UNBOUNDED PRECEDING) builds a running
-- total ordered by date, useful for growth-curve charts.
WITH daily_counts AS (
    SELECT
        hotel_id,
        check_in_date,
        COUNT(*) AS bookings_that_day
    FROM bookings
    WHERE check_in_date >= '2025-01-01' AND check_in_date < '2026-01-01'
    GROUP BY hotel_id, check_in_date
)
SELECT
    hotel_id,
    check_in_date,
    bookings_that_day,
    SUM(bookings_that_day) OVER (
        PARTITION BY hotel_id ORDER BY check_in_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_2025
FROM daily_counts
ORDER BY hotel_id, check_in_date;


-- Q17. Rooms with the longest idle gaps between bookings
-- LEAD() looks ahead to the *next* booking's check-in date for the same
-- room, so we can measure the gap until the room is booked again.
WITH room_bookings AS (
    SELECT
        room_id,
        check_in_date,
        check_out_date,
        LEAD(check_in_date) OVER (PARTITION BY room_id ORDER BY check_in_date) AS next_check_in
    FROM bookings
    WHERE booking_status <> 'cancelled'
)
SELECT
    room_id,
    check_out_date,
    next_check_in,
    (next_check_in - check_out_date) AS idle_days
FROM room_bookings
WHERE next_check_in IS NOT NULL
ORDER BY idle_days DESC
LIMIT 20;


-- Q18. Year-over-year revenue comparison per hotel, flagging hotels in decline
-- Two CTEs (current year vs previous year) are joined side by side, then
-- a decline ratio is calculated - same pattern as the reference project's
-- product revenue-decline analysis, applied here to hotels.
WITH yearly_revenue AS (
    SELECT
        b.hotel_id,
        EXTRACT(YEAR FROM p.payment_date) AS revenue_year,
        SUM(p.amount) AS revenue
    FROM bookings b
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.payment_status = 'paid'
    GROUP BY b.hotel_id, revenue_year
),
this_year AS (
    SELECT * FROM yearly_revenue WHERE revenue_year = 2025
),
last_year AS (
    SELECT * FROM yearly_revenue WHERE revenue_year = 2024
)
SELECT
    h.hotel_id,
    h.name,
    ly.revenue AS revenue_2024,
    ty.revenue AS revenue_2025,
    ROUND((ty.revenue - ly.revenue) / NULLIF(ly.revenue, 0) * 100, 2) AS yoy_change_pct
FROM hotels h
JOIN this_year ty ON h.hotel_id = ty.hotel_id
JOIN last_year ly ON h.hotel_id = ly.hotel_id
WHERE ty.revenue < ly.revenue   -- only hotels in decline
ORDER BY yoy_change_pct ASC;


-- Q19. Average payment delay (payment_date vs booking_date)
-- Simple date-difference aggregation, flags hotels whose guests are slow to pay.
SELECT
    h.hotel_id,
    h.name,
    ROUND(AVG(p.payment_date - b.booking_date), 2) AS avg_payment_delay_days
FROM hotels h
JOIN bookings b ON h.hotel_id = b.hotel_id
JOIN payments p ON b.booking_id = p.booking_id
GROUP BY h.hotel_id, h.name
ORDER BY avg_payment_delay_days DESC;


-- Q20. Seasonal pricing impact - compare actual revenue vs base-price revenue
-- during each room type's Peak season window.
-- Joins bookings to seasonal_pricing where the stay falls inside the season's
-- date range, then compares real paid amount to what base price alone would predict.
WITH peak_bookings AS (
    SELECT
        b.booking_id,
        rt.type_name,
        rt.base_price,
        (b.check_out_date - b.check_in_date) AS nights,
        p.amount AS actual_paid,
        sp.price_multiplier
    FROM bookings b
    JOIN rooms r ON b.room_id = r.room_id
    JOIN room_types rt ON r.room_type_id = rt.room_type_id
    JOIN payments p ON b.booking_id = p.booking_id
    JOIN seasonal_pricing sp
        ON sp.room_type_id = rt.room_type_id
        AND sp.season_name = 'Peak'
        AND b.check_in_date BETWEEN sp.start_date AND sp.end_date
    WHERE p.payment_status = 'paid'
)
SELECT
    type_name,
    COUNT(*) AS peak_bookings_count,
    ROUND(AVG(actual_paid), 2) AS avg_actual_paid,
    ROUND(AVG(base_price * nights), 2) AS avg_base_price_revenue,
    ROUND(AVG(actual_paid) - AVG(base_price * nights), 2) AS avg_peak_premium
FROM peak_bookings
GROUP BY type_name
ORDER BY avg_peak_premium DESC;


-- Q21. Bookings-per-staff ratio grouped by hotel star rating
-- Correlates operational load (bookings) with hotel quality tier (star_rating),
-- a good example of combining two dimension tables through a shared FK.
SELECT
    h.star_rating,
    COUNT(DISTINCT s.staff_id) AS staff_count,
    COUNT(b.booking_id) AS total_bookings,
    ROUND(COUNT(b.booking_id)::NUMERIC / NULLIF(COUNT(DISTINCT s.staff_id), 0), 2) AS bookings_per_staff
FROM hotels h
JOIN staff s ON h.hotel_id = s.hotel_id
JOIN bookings b ON h.hotel_id = b.hotel_id
GROUP BY h.star_rating
ORDER BY h.star_rating;


-- Q22. Guest spend quartiles (NTILE)
-- Splits all paying guests into 4 spend quartiles - useful for building a
-- loyalty-tier or marketing-segmentation system.
WITH guest_totals AS (
    SELECT
        g.guest_id,
        g.full_name,
        SUM(p.amount) AS total_spend
    FROM guests g
    JOIN bookings b ON g.guest_id = b.guest_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.payment_status = 'paid'
    GROUP BY g.guest_id, g.full_name
)
SELECT
    guest_id,
    full_name,
    total_spend,
    NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
FROM guest_totals
ORDER BY total_spend DESC;


-- =========================================================================
-- SECTION 4: STRETCH GOALS (stored procedures & triggers)
-- =========================================================================

-- Q23. Stored procedure: book_room()
-- Checks room availability for the requested dates, then inserts a booking
-- + matching payment record in a single call. Raises an exception if the
-- room already has an overlapping booking for those dates.
CREATE OR REPLACE PROCEDURE book_room(
    p_booking_id     INT,
    p_guest_id       INT,
    p_hotel_id       INT,
    p_room_id        INT,
    p_check_in       DATE,
    p_check_out      DATE,
    p_num_guests     INT,
    p_amount         NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_count INT;
BEGIN
    -- Check for overlapping bookings on the same room
    SELECT COUNT(*) INTO v_conflict_count
    FROM bookings
    WHERE room_id = p_room_id
      AND booking_status <> 'cancelled'
      AND (p_check_in, p_check_out) OVERLAPS (check_in_date, check_out_date);

    IF v_conflict_count > 0 THEN
        RAISE EXCEPTION 'Room % is not available between % and %', p_room_id, p_check_in, p_check_out;
    END IF;

    INSERT INTO bookings (booking_id, guest_id, hotel_id, room_id, booking_date,
                           check_in_date, check_out_date, num_guests, booking_status)
    VALUES (p_booking_id, p_guest_id, p_hotel_id, p_room_id, CURRENT_DATE,
            p_check_in, p_check_out, p_num_guests, 'confirmed');

    INSERT INTO payments (payment_id, booking_id, payment_date, amount, payment_method, payment_status)
    VALUES (p_booking_id, p_booking_id, CURRENT_DATE, p_amount, 'credit_card', 'paid');

    RAISE NOTICE 'Booking % created successfully for room %', p_booking_id, p_room_id;
END;
$$;

-- Example call:
-- CALL book_room(99999, 1, 1, 5, '2026-03-01', '2026-03-05', 2, 480.00);


-- Q24. Stored procedure: cancel_booking()
-- Updates booking status to 'cancelled' and automatically marks the
-- related payment as 'refunded', keeping both tables in sync in one call.
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE bookings
    SET booking_status = 'cancelled'
    WHERE booking_id = p_booking_id;

    UPDATE payments
    SET payment_status = 'refunded'
    WHERE booking_id = p_booking_id
      AND payment_status = 'paid';

    RAISE NOTICE 'Booking % cancelled and payment refunded', p_booking_id;
END;
$$;

-- Example call:
-- CALL cancel_booking(99999);


-- Q25. Trigger: auto-update room status on booking insert/cancel
-- Whenever a new confirmed booking is inserted, the room's status flips to
-- 'occupied'. Whenever a booking is cancelled, the room flips back to
-- 'available'. This keeps the rooms table's status column always accurate
-- without the application having to remember to update it manually.
CREATE OR REPLACE FUNCTION fn_update_room_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.booking_status = 'confirmed' THEN
        UPDATE rooms SET status = 'occupied' WHERE room_id = NEW.room_id;

    ELSIF TG_OP = 'UPDATE' AND NEW.booking_status = 'cancelled' AND OLD.booking_status <> 'cancelled' THEN
        UPDATE rooms SET status = 'available' WHERE room_id = NEW.room_id;
    END IF;

    RETURN NEW;
END;
$$;



DROP TRIGGER IF EXISTS trg_update_room_status ON bookings;

CREATE TRIGGER trg_update_room_status
AFTER INSERT OR UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_update_room_status();

--Execution of Q23-Q25
CALL book_room(99996, 3, 1, 7, '2026-05-01', '2026-05-05', 2, 500.00);
SELECT room_id, status FROM rooms WHERE room_id = 7;

CALL cancel_booking(99996);
SELECT booking_status FROM bookings WHERE booking_id = 99996;  
SELECT payment_status FROM payments WHERE booking_id = 99996;   
SELECT status FROM rooms WHERE room_id = 7;                     
