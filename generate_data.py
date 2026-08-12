"""
Synthetic data generator for the Hotel Booking System project.
Generates CSVs for all 9 tables, in dependency order, respecting
foreign keys and the constraints defined in hotel_booking_schema.sql.

Run: python3 generate_data.py
Output: CSV files in ./data/
"""

import csv
import random
from datetime import date, timedelta
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

OUT_DIR = "data"
import os
os.makedirs(OUT_DIR, exist_ok=True)

# -------------------------------------------------------------
# CONFIG - tune volumes here
# -------------------------------------------------------------
N_HOTELS = 60
ROOM_TYPES_PER_HOTEL = (3, 5)      # min, max
ROOMS_PER_HOTEL = (30, 70)
STAFF_PER_HOTEL = (6, 14)
N_GUESTS = 10000
N_BOOKINGS = 55000
SEASONS_PER_ROOM_TYPE = 3

US_STATES = [
    ("California", "Los Angeles"), ("California", "San Francisco"),
    ("New York", "New York City"), ("New York", "Buffalo"),
    ("Texas", "Austin"), ("Texas", "Houston"),
    ("Florida", "Miami"), ("Florida", "Orlando"),
    ("Illinois", "Chicago"), ("Nevada", "Las Vegas"),
    ("Colorado", "Denver"), ("Washington", "Seattle"),
    ("Arizona", "Phoenix"), ("Georgia", "Atlanta"),
    ("Massachusetts", "Boston"),
]

ROOM_TYPE_NAMES = ["Single", "Double", "Deluxe", "Suite", "Executive Suite", "Family Room"]
BASE_PRICE_RANGE = {
    "Single": (70, 120), "Double": (100, 160), "Deluxe": (150, 240),
    "Suite": (220, 380), "Executive Suite": (300, 500), "Family Room": (180, 300),
}
STAFF_ROLES = ["manager", "receptionist", "housekeeping", "concierge"]
PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "cash"]
SEASON_NAMES = [("Off-Peak", 0.85), ("Regular", 1.00), ("Peak", 1.35), ("Holiday", 1.6)]

today = date(2025, 12, 31)
data_start = date(2021, 1, 1)


def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, max(delta, 0)))


# -------------------------------------------------------------
# 1. HOTELS
# -------------------------------------------------------------
hotels = []
for hotel_id in range(1, N_HOTELS + 1):
    state, city = random.choice(US_STATES)
    hotels.append({
        "hotel_id": hotel_id,
        "name": f"{fake.last_name()} {random.choice(['Grand Hotel','Resort & Spa','Inn','Plaza Hotel','Suites'])}",
        "city": city,
        "state": state,
        "country": "USA",
        "star_rating": random.choices([2, 3, 4, 5], weights=[10, 35, 40, 15])[0],
        "total_rooms": 0,  # filled in after rooms are generated
    })

# -------------------------------------------------------------
# 2. GUESTS
# -------------------------------------------------------------
guests = []
for guest_id in range(1, N_GUESTS + 1):
    state, city = random.choice(US_STATES)
    guests.append({
        "guest_id": guest_id,
        "full_name": fake.name(),
        "email": fake.unique.email(),
        "phone": fake.phone_number()[:20],
        "city": city,
        "state": state,
        "country": "USA",
        "signup_date": rand_date(data_start, today).isoformat(),
    })

# -------------------------------------------------------------
# 3. ROOM_TYPES (depends on hotels)
# -------------------------------------------------------------
room_types = []
room_type_id = 1
room_types_by_hotel = {}
for h in hotels:
    n = random.randint(*ROOM_TYPES_PER_HOTEL)
    names = random.sample(ROOM_TYPE_NAMES, n)
    room_types_by_hotel[h["hotel_id"]] = []
    for name in names:
        lo, hi = BASE_PRICE_RANGE[name]
        rt = {
            "room_type_id": room_type_id,
            "hotel_id": h["hotel_id"],
            "type_name": name,
            "base_price": round(random.uniform(lo, hi), 2),
            "max_occupancy": {"Single": 1, "Double": 2, "Deluxe": 2,
                               "Suite": 4, "Executive Suite": 4, "Family Room": 6}[name],
        }
        room_types.append(rt)
        room_types_by_hotel[h["hotel_id"]].append(rt)
        room_type_id += 1

# -------------------------------------------------------------
# 4. ROOMS (depends on hotels + room_types)
# -------------------------------------------------------------
rooms = []
room_id = 1
rooms_by_hotel = {}
for h in hotels:
    n_rooms = random.randint(*ROOMS_PER_HOTEL)
    rooms_by_hotel[h["hotel_id"]] = []
    available_types = room_types_by_hotel[h["hotel_id"]]
    for i in range(n_rooms):
        rt = random.choice(available_types)
        floor = random.randint(1, 12)
        room = {
            "room_id": room_id,
            "hotel_id": h["hotel_id"],
            "room_type_id": rt["room_type_id"],
            "room_number": f"{floor}{i % 20:02d}",
            "floor": floor,
            "status": random.choices(["available", "occupied", "maintenance"],
                                      weights=[70, 25, 5])[0],
        }
        rooms.append(room)
        rooms_by_hotel[h["hotel_id"]].append(room)
        room_id += 1
    h["total_rooms"] = n_rooms

# -------------------------------------------------------------
# 5. STAFF (depends on hotels)
# -------------------------------------------------------------
staff = []
staff_id = 1
for h in hotels:
    n = random.randint(*STAFF_PER_HOTEL)
    for _ in range(n):
        staff.append({
            "staff_id": staff_id,
            "hotel_id": h["hotel_id"],
            "name": fake.name(),
            "role": random.choices(STAFF_ROLES, weights=[10, 35, 40, 15])[0],
            "hire_date": rand_date(data_start - timedelta(days=1500), today).isoformat(),
        })
        staff_id += 1

# -------------------------------------------------------------
# 6. SEASONAL_PRICING (depends on room_types)
# -------------------------------------------------------------
seasonal_pricing = []
pricing_id = 1
year_ranges = {
    "Off-Peak": [("01-15", "03-01"), ("11-01", "12-15")],
    "Regular": [("03-02", "05-31"), ("09-01", "10-31")],
    "Peak": [("06-01", "08-31")],
    "Holiday": [("12-16", "01-14")],
}
for rt in room_types:
    chosen = random.sample(SEASON_NAMES, SEASONS_PER_ROOM_TYPE)
    for season_name, multiplier in chosen:
        md_start, md_end = random.choice(year_ranges[season_name])
        start = date(2025, int(md_start[:2]), int(md_start[3:]))
        try:
            end = date(2025, int(md_end[:2]), int(md_end[3:]))
        except ValueError:
            end = date(2025, int(md_end[:2]), 28)
        if end <= start:
            end = start + timedelta(days=30)
        seasonal_pricing.append({
            "pricing_id": pricing_id,
            "room_type_id": rt["room_type_id"],
            "season_name": season_name,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "price_multiplier": multiplier,
        })
        pricing_id += 1

# -------------------------------------------------------------
# 7. BOOKINGS (depends on guests, hotels, rooms)
# -------------------------------------------------------------
bookings = []
booking_id = 1
booking_status_weights = ["confirmed", "cancelled", "completed"]
for _ in range(N_BOOKINGS):
    guest = random.choice(guests)
    hotel = random.choice(hotels)
    room = random.choice(rooms_by_hotel[hotel["hotel_id"]])

    check_in = rand_date(data_start, today - timedelta(days=1))
    stay_length = random.choices([1, 2, 3, 4, 5, 7, 10, 14], weights=[15, 25, 20, 15, 10, 8, 4, 3])[0]
    check_out = check_in + timedelta(days=stay_length)
    booking_date = check_in - timedelta(days=random.randint(0, 60))
    if booking_date < data_start:
        booking_date = data_start

    status = random.choices(["confirmed", "cancelled", "completed"], weights=[15, 10, 75])[0]
    # future check-ins can't be "completed"
    if check_in > today - timedelta(days=stay_length):
        status = random.choices(["confirmed", "cancelled"], weights=[85, 15])[0]

    bookings.append({
        "booking_id": booking_id,
        "guest_id": guest["guest_id"],
        "hotel_id": hotel["hotel_id"],
        "room_id": room["room_id"],
        "booking_date": booking_date.isoformat(),
        "check_in_date": check_in.isoformat(),
        "check_out_date": check_out.isoformat(),
        "num_guests": random.randint(1, 4),
        "booking_status": status,
    })
    booking_id += 1

# -------------------------------------------------------------
# 8. PAYMENTS (depends on bookings)
# -------------------------------------------------------------
payments = []
payment_id = 1
# need base_price lookup per room -> room_type -> price
room_to_price = {r["room_id"]: next(rt["base_price"] for rt in room_types
                                     if rt["room_type_id"] == r["room_type_id"])
                  for r in rooms}

for b in bookings:
    nights = (date.fromisoformat(b["check_out_date"]) - date.fromisoformat(b["check_in_date"])).days
    base_price = room_to_price[b["room_id"]]
    amount = round(base_price * nights * random.uniform(0.95, 1.15), 2)

    if b["booking_status"] == "cancelled":
        pay_status = random.choices(["refunded", "pending"], weights=[80, 20])[0]
    elif b["booking_status"] == "confirmed":
        pay_status = random.choices(["paid", "pending"], weights=[70, 30])[0]
    else:  # completed
        pay_status = "paid"

    pay_date = date.fromisoformat(b["booking_date"]) + timedelta(days=random.randint(0, 3))

    payments.append({
        "payment_id": payment_id,
        "booking_id": b["booking_id"],
        "payment_date": pay_date.isoformat(),
        "amount": amount,
        "payment_method": random.choice(PAYMENT_METHODS),
        "payment_status": pay_status,
    })
    payment_id += 1

# -------------------------------------------------------------
# 9. REVIEWS (depends on bookings + guests) - only for completed bookings, ~45% leave one
# -------------------------------------------------------------
reviews = []
review_id = 1
completed_bookings = [b for b in bookings if b["booking_status"] == "completed"]
reviewers = random.sample(completed_bookings, int(len(completed_bookings) * 0.45))

comments_pool = [
    "Great stay, would come back again.",
    "Room was clean and staff were friendly.",
    "Average experience, nothing special.",
    "Loved the location and amenities.",
    "Check-in took too long.",
    "Room smelled a bit musty.",
    "Excellent service from the front desk.",
    "Would not recommend, poor housekeeping.",
    "Perfect for a weekend getaway.",
    "Bed was uncomfortable but view was great.",
]

for b in reviewers:
    review_date = date.fromisoformat(b["check_out_date"]) + timedelta(days=random.randint(0, 14))
    rating = random.choices([1, 2, 3, 4, 5], weights=[5, 8, 17, 35, 35])[0]
    reviews.append({
        "review_id": review_id,
        "booking_id": b["booking_id"],
        "guest_id": b["guest_id"],
        "rating": rating,
        "review_date": review_date.isoformat(),
        "comment": random.choice(comments_pool),
    })
    review_id += 1


# -------------------------------------------------------------
# WRITE ALL CSVs
# -------------------------------------------------------------
def write_csv(filename, rows):
    if not rows:
        return
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"{filename:25s} {len(rows):>7,} rows")


print("Generating CSVs...\n")
write_csv("hotels.csv", hotels)
write_csv("guests.csv", guests)
write_csv("room_types.csv", room_types)
write_csv("rooms.csv", rooms)
write_csv("staff.csv", staff)
write_csv("seasonal_pricing.csv", seasonal_pricing)
write_csv("bookings.csv", bookings)
write_csv("payments.csv", payments)
write_csv("reviews.csv", reviews)

total = sum(len(x) for x in [hotels, guests, room_types, rooms, staff,
                              seasonal_pricing, bookings, payments, reviews])
print(f"\nTotal rows across all tables: {total:,}")
