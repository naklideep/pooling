# 🚗 GharTak — Ride Sharing App

> **Share rides. Save money. Reduce carbon.**

GharTak is a peer-to-peer ride sharing app built for college students and daily commuters. Post or find rides in real time, verify with a 4-digit code, track live locations, chat in-app, and rate your experience — all powered by Flutter and Firebase.

---

## ✨ Features

- 🚘 **Post or Find Rides** — real-time ride listings with search and filters
- 🔐 **4-Digit Ride Code** — secure OTP-style verification before the ride starts
- 💳 **UPI Payment** — in-app payment via PhonePe, Google Pay, Paytm, or BHIM
- 🗺️ **Live GPS Tracking** — driver's location updates in real time on the map
- 💬 **In-App Chat** — per-ride group chat with typing indicators and read receipts
- ⭐ **Mutual Ratings** — 5-star post-ride ratings for both driver and rider
- 🔖 **Saved Routes** — save frequently used routes for quick posting
- 🛡️ **Admin Dashboard** — view users, ban/unban, and monitor ride stats

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter (Dart) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| Mapping | Flutter Map + OSRM |
| Location | Geolocator |
| Notifications | Flutter Local Notifications |
| Payments | UPI Deep Links via `url_launcher` |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- A Firebase project with **Email/Password Auth** and **Cloud Firestore** enabled
- Android Studio or VS Code

### Installation

```bash
# Clone the repo
git clone https://github.com/yourusername/ghartak.git
cd ghartak

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure
```

Place your `google-services.json` inside `android/app/`.

### Run

```bash
flutter run
```

---

## 📦 Dependencies

```yaml
firebase_core
firebase_auth
cloud_firestore
flutter_map
latlong2
geolocator
geocoding
http
intl
shared_preferences
flutter_local_notifications
url_launcher
```

---

## 🗂 Project Structure

```
lib/
└── pages/
    ├── login_page.dart              # Auth with ban check + admin detection
    ├── registration_page.dart       # New user registration
    ├── dashboard_page.dart          # Main hub — Post/Find tabs + drawer
    ├── post_ride.dart               # Post ride with map picker + route calc
    ├── find_ride_widget.dart        # Browse, filter, and accept rides
    ├── your_rides_page.dart         # View posted and accepted rides
    ├── ride_active_page.dart        # OTP gate + payment + ride actions
    ├── upi_payment_page.dart        # UPI payment screen
    ├── chat_page.dart               # Real-time per-ride chat
    ├── live_ride_tracking_page.dart # Live GPS map tracking
    ├── live_tracking_service.dart   # Background GPS writer
    ├── profile_page.dart            # User profile
    ├── rating_dialog.dart           # Post-ride rating sheet
    ├── saved_routes_page.dart       # Manage saved routes
    ├── admin_dashboard_page.dart    # Admin controls
    ├── enhanced_map_picker.dart     # Full-screen map coordinate picker
    └── notification_service.dart   # Local push notifications
```

---

## 🔥 Firestore Schema

### `rides/{rideId}`

| Field | Type | Description |---|---|---|
| `from`, `to` | String | Display addresses |
| `from_lat`, `from_lng` | double | Pickup coordinates |
| `to_lat`, `to_lng` | double | Destination coordinates |
| `seats`, `remainingSeats` | int | Total and available seats |
| `rideType` | String | `"Car"` or `"Bike"` |
| `estimatedCost` | int | Calculated fare |
| `status` | String | `pending` → `in_progress` → `completed` |
| `rideCode` | String | 4-digit verification code |
| `rideStarted` | bool | Set `true` after OTP verified |
| `paymentStatus` | String | `pending` → `awaiting_confirmation` → `confirmed` |
| `driverUPI` | String | Driver's UPI ID for payment |
| `isTracking` | bool | GPS tracking active |
| `currentLocation` | Map | `{ lat, lng }` live driver position |

### `users/{userId}`

| Field | Type | Description |
|---|---|---|
| `name`, `email` | String | User info |
| `role` | String | `"admin"` or empty |
| `isBanned` | bool | Ban status checked on login |
| `averageRating` | double | Recalculated after each rating |
| `totalRatings` | int | Total rating count |

---

## 🔄 Ride Lifecycle

```
Register / Login (email verified)
└── Dashboard
    ├── POST RIDE → post_ride.dart → Firestore
    └── FIND RIDE → find_ride_widget.dart
        └── Accept → RideActivePage
            ├── DRIVER shows pulsing 4-digit code
            ├── RIDER enters code → UPI payment opens
            ├── paymentStatus: awaiting_confirmation
            ├── DRIVER confirms payment received
            └── paymentStatus: confirmed → rideStarted: true
                └── Unlocked: Track | Chat | Complete | Cancel
                    └── Both confirm Done → status: completed
                        └── Rating dialog shown
```

---

## 🔒 Admin Setup

Set the admin email in `login_page.dart`:

```dart
const String adminEmail = "your@email.com";
```

Admin users are routed to `AdminDashboardPage` instead of `DashboardPage`.

---

## 🗺 Firestore Indexes Required

```
rides: riderId ASC + timestamp DESC
rides: timestamp DESC
```

---

## 🛣 Roadmap

| # | ----Feature----|---- Effort----- |
| 1 | ETA Countdown on active ride | Low |
| 2 | Ride reminders (30 min before) | Low |
| 3 | Ride history + stats page | Medium |
| 4 | SOS button with live coordinates via SMS | Medium |
| 5 | Trip sharing link for non-app users | Medium |
| 6 | Recurring rides (auto-post on schedule) | High |
| 7 | Ride requests (rider posts, driver offers) | High |
| 8 | Verified student badge via college ID | High |

---

## 📄 License

This project is private and confidential. All rights reserved © GharTak v1.0.

---
Built with ❤️ using Flutter & Firebase