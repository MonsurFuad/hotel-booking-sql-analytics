-- =========================================================
-- HOTEL BOOKING SYSTEM - ADVANCED SQL PROJECT
-- Database: PostgreSQL
-- =========================================================

-- Drop tables if they exist (useful for re-running during development)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS seasonal_pricing CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS room_types CASCADE;
DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS hotels CASCADE;

-- =========================================================
-- 1. HOTELS (top-level parent table)
-- =========================================================
CREATE TABLE hotels (
    hotel_id      INT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    city          VARCHAR(50) NOT NULL,
    state         VARCHAR(50) NOT NULL,
    country       VARCHAR(50) NOT NULL DEFAULT 'USA',
    star_rating   SMALLINT CHECK (star_rating BETWEEN 1 AND 5),
    total_rooms   INT NOT NULL DEFAULT 0
);

-- =========================================================
-- 2. GUESTS (independent parent table)
-- =========================================================
CREATE TABLE guests (
    guest_id      INT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) UNIQUE,
    phone         VARCHAR(20),
    city          VARCHAR(50),
    state         VARCHAR(50),
    country       VARCHAR(50) DEFAULT 'USA',
    signup_date   DATE NOT NULL
);

-- =========================================================
-- 3. ROOM_TYPES (depends on hotels)
-- =========================================================
CREATE TABLE room_types (
    room_type_id   INT PRIMARY KEY,
    hotel_id       INT NOT NULL,
    type_name      VARCHAR(50) NOT NULL,   -- Single, Double, Suite, Deluxe...
    base_price     NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
    max_occupancy  SMALLINT NOT NULL DEFAULT 2,
    CONSTRAINT fk_room_types_hotel
        FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id)
);

-- =========================================================
-- 4. ROOMS (depends on hotels + room_types)
-- =========================================================
CREATE TABLE rooms (
    room_id       INT PRIMARY KEY,
    hotel_id      INT NOT NULL,
    room_type_id  INT NOT NULL,
    room_number   VARCHAR(10) NOT NULL,
    floor         SMALLINT,
    status        VARCHAR(20) NOT NULL DEFAULT 'available'
                  CHECK (status IN ('available','occupied','maintenance')),
    CONSTRAINT fk_rooms_hotel
        FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id),
    CONSTRAINT fk_rooms_room_type
        FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id)
);

-- =========================================================
-- 5. STAFF (depends on hotels)
-- =========================================================
CREATE TABLE staff (
    staff_id    INT PRIMARY KEY,
    hotel_id    INT NOT NULL,
    name        VARCHAR(100) NOT NULL,
    role        VARCHAR(30) NOT NULL
                CHECK (role IN ('manager','receptionist','housekeeping','concierge')),
    hire_date   DATE NOT NULL,
    CONSTRAINT fk_staff_hotel
        FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id)
);

-- =========================================================
-- 6. SEASONAL_PRICING (depends on room_types)
-- =========================================================
CREATE TABLE seasonal_pricing (
    pricing_id        INT PRIMARY KEY,
    room_type_id      INT NOT NULL,
    season_name       VARCHAR(30) NOT NULL,   -- Peak, Off-Peak, Holiday...
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    price_multiplier  NUMERIC(4,2) NOT NULL DEFAULT 1.00 CHECK (price_multiplier > 0),
    CONSTRAINT fk_seasonal_room_type
        FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id),
    CONSTRAINT chk_season_dates CHECK (end_date >= start_date)
);

-- =========================================================
-- 7. BOOKINGS (depends on guests, hotels, rooms)
-- =========================================================
CREATE TABLE bookings (
    booking_id       INT PRIMARY KEY,
    guest_id         INT NOT NULL,
    hotel_id         INT NOT NULL,
    room_id          INT NOT NULL,
    booking_date     DATE NOT NULL,
    check_in_date    DATE NOT NULL,
    check_out_date   DATE NOT NULL,
    num_guests       SMALLINT NOT NULL DEFAULT 1,
    booking_status   VARCHAR(20) NOT NULL DEFAULT 'confirmed'
                     CHECK (booking_status IN ('confirmed','cancelled','completed')),
    CONSTRAINT fk_bookings_guest
        FOREIGN KEY (guest_id) REFERENCES guests(guest_id),
    CONSTRAINT fk_bookings_hotel
        FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id),
    CONSTRAINT fk_bookings_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id),
    CONSTRAINT chk_checkout_after_checkin CHECK (check_out_date > check_in_date)
);

-- =========================================================
-- 8. PAYMENTS (depends on bookings)
-- =========================================================
CREATE TABLE payments (
    payment_id      INT PRIMARY KEY,
    booking_id      INT NOT NULL,
    payment_date    DATE NOT NULL,
    amount          NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    payment_method  VARCHAR(30) NOT NULL
                    CHECK (payment_method IN ('credit_card','debit_card','paypal','cash')),
    payment_status  VARCHAR(20) NOT NULL DEFAULT 'paid'
                    CHECK (payment_status IN ('paid','pending','refunded')),
    CONSTRAINT fk_payments_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

-- =========================================================
-- 9. REVIEWS (depends on bookings, guests)
-- =========================================================
CREATE TABLE reviews (
    review_id     INT PRIMARY KEY,
    booking_id    INT NOT NULL,
    guest_id      INT NOT NULL,
    rating        SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_date   DATE NOT NULL,
    comment       VARCHAR(500) DEFAULT 'No comment provided',
    CONSTRAINT fk_reviews_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    CONSTRAINT fk_reviews_guest
        FOREIGN KEY (guest_id) REFERENCES guests(guest_id)
);

-- =========================================================
-- Helpful indexes for query performance (common join/filter columns)
-- =========================================================
CREATE INDEX idx_bookings_guest_id ON bookings(guest_id);
CREATE INDEX idx_bookings_hotel_id ON bookings(hotel_id);
CREATE INDEX idx_bookings_dates ON bookings(check_in_date, check_out_date);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_reviews_booking_id ON reviews(booking_id);
CREATE INDEX idx_rooms_hotel_id ON rooms(hotel_id);

