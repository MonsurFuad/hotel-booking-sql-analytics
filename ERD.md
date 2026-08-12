# Entity-Relationship Diagram — Hotel Booking System

This diagram renders automatically on GitHub (and most modern Markdown viewers) since it uses [Mermaid](https://mermaid.js.org/) syntax.

```mermaid
erDiagram
  HOTELS ||--o{ ROOM_TYPES : offers
  HOTELS ||--o{ ROOMS : contains
  HOTELS ||--o{ STAFF : employs
  HOTELS ||--o{ BOOKINGS : hosts
  ROOM_TYPES ||--o{ ROOMS : defines
  ROOM_TYPES ||--o{ SEASONAL_PRICING : has
  GUESTS ||--o{ BOOKINGS : makes
  ROOMS ||--o{ BOOKINGS : booked_as
  BOOKINGS ||--o{ PAYMENTS : generates
  BOOKINGS ||--o{ REVIEWS : receives
  GUESTS ||--o{ REVIEWS : writes

  HOTELS {
    int hotel_id PK
    string name
    string city
    string state
    int star_rating
    int total_rooms
  }
  GUESTS {
    int guest_id PK
    string full_name
    string email
    date signup_date
  }
  ROOM_TYPES {
    int room_type_id PK
    int hotel_id FK
    string type_name
    numeric base_price
  }
  ROOMS {
    int room_id PK
    int hotel_id FK
    int room_type_id FK
    string status
  }
  STAFF {
    int staff_id PK
    int hotel_id FK
    string role
  }
  SEASONAL_PRICING {
    int pricing_id PK
    int room_type_id FK
    string season_name
    numeric price_multiplier
  }
  BOOKINGS {
    int booking_id PK
    int guest_id FK
    int hotel_id FK
    int room_id FK
    date check_in_date
    date check_out_date
    string booking_status
  }
  PAYMENTS {
    int payment_id PK
    int booking_id FK
    numeric amount
    string payment_status
  }
  REVIEWS {
    int review_id PK
    int booking_id FK
    int guest_id FK
    int rating
  }
```

## How to read it

- `hotels` and `guests` are the two independent parent tables.
- `bookings` is the central hub — it references `guests`, `hotels`, and `rooms`, and is itself referenced by both `payments` and `reviews`.
- `room_types` bridges `hotels` to both `rooms` and `seasonal_pricing`.
