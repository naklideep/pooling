# 🚗 RideBuddyy — Daily Commute & Publisher–Subscriber Ride-Pooling Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#)

> **Share recurring commutes. Reserve seats with atomic safety. Pool rides seamlessly.**

**RideBuddyy** is a full-scale hybrid ride-pooling and daily commute platform built with **Flutter** and **Firebase**. It supports open ride discovery alongside a **Publisher–Subscriber** model for regular commuters (office, college, daily transit) with direct invitations, shareable invite codes, intermediate waypoint routing, and atomic seat reservation transactions.

---

## 🌟 Key Features

### 1. 📢 Dedicated Publisher Workflow
- **Recurring Commute Templates:** Create reusable schedules (e.g., *Home to Office every weekday at 9:00 AM*).
- **Flexible Recurrence:** Daily, weekdays (Mon–Fri), or custom weekday schedules.
- **Intermediate Waypoints:** Add stops along the route with custom labels and GPS coordinates.
- **Detour Tolerance:** Set maximum acceptable detour distance (1–15 km) for passenger pickups.
- **Ride Visibility:** Configure commutes as `public`, `subscribers_only`, or `invite_only`.
- **Idempotent Occurrence Generator:** Automatically creates individual ride occurrences in the `/rides` collection for the upcoming 14 days using deterministic IDs (`${scheduleId}_${YYYY-MM-DD}`) without overwriting existing bookings.
- **Schedule Controls:** Pause, resume, edit, or permanently end recurring commute schedules.

### 2. 👥 Commuter & Subscriber Experience
- **Discover Publishers:** Browse active recurring commutes with route preview chips and weekday filters.
- **Persistent Subscriptions:** Subscribe to a publisher's recurring route with preferred pickup points and notifications.
- **Subscription Management:** Pause or cancel subscriptions with automatic subscriber-count adjustments.
- **Direct Invitations & Codes:** Accept or decline personalized invitations or redeem shareable `POOL-XXXX` invite codes.

### 3. 🎯 Proximity & Route Matching Engine
- **Geographic Proximity:** Computes straight-line and route distance using the **Haversine formula**.
- **Waypoint Detection:** Evaluates whether passenger pickup/drop points lie near intermediate route stops.
- **Time Window Tolerance:** Filters commutes matching the commuter’s departure window (within $\pm 30$ minutes).
- **Score & Explanations:** Computes a compatibility score (0–100) with natural-language match explanations (e.g., *"Pickup within 0.8 km of route • Departs 15 min after your time"*).

### 4. 🔒 Atomic Booking & Capacity Protection
- **No Overbooking Guarantee:** All seat allocations (invitation acceptances and join-request approvals) execute in atomic **Firestore Transactions**.
- **Duplicate Prevention:** Prevents users from booking multiple seats or sending duplicate requests on the same ride.
- **Authoritative Bookings:** Generates a dedicated `/bookings` record per seat reservation with 4-digit boarding security PIN.
- **Seat Restoration:** Automatically restores seats back to the ride when a booking is cancelled.

### 5. 🛡️ Safety & Commute Operations
- **Boarding Security PIN:** Unique 4-digit verification code required to validate boarding before trip start.
- **Passenger Management:** Drivers can view passenger lists, inspect boarding PINs, or remove passengers.
- **Live Tracking & Chat:** Real-time driver GPS tracking and per-ride group chat.
- **UPI Settlement:** Direct in-app UPI fare settlement via Google Pay, PhonePe, Paytm, or BHIM.
- **In-App Notification Center:** Real-time notification tray for invites, booking status updates, and schedule alerts.

---

## 🛠️ Architecture & Tech Stack

```
┌────────────────────────────────────────────────────────┐
│                      UI Layer                          │
│   (Features: Commute, Invitations, Bookings, Home)     │
└──────────────────────────┬─────────────────────────────┘
                           │ calls
┌──────────────────────────▼─────────────────────────────┐
│                  Repositories Layer                    │
│  (CommuteRepo, SubscriptionRepo, InvitationRepo, etc.)  │
└──────────────────────────┬─────────────────────────────┘
                           │ executes
┌──────────────────────────▼─────────────────────────────┐
│             Atomic Firestore Transactions              │
│       (Seat Validation, Capacity Bounds Check)         │
└──────────────────────────┬─────────────────────────────┘
                           │ enforced by
┌──────────────────────────▼─────────────────────────────┐
│                Cloud Firestore Rules                   │
│          (Role-based access, Seat decrements)          │
└────────────────────────────────────────────────────────┘
```

| Layer | Technology |
|---|---|
| **Frontend Framework** | Flutter 3.x (Dart 3.x) |
| **Backend & Auth** | Firebase Authentication (Email/Password, Google Sign-In) |
| **Primary Database** | Cloud Firestore |
| **Maps & Routing** | OpenStreetMap (OSM) via `flutter_map`, `latlong2`, `geocoding` |
| **Location & GPS** | `geolocator` |
| **Push & Local Alerts** | `flutter_local_notifications` + In-app notification center |
| **Payments** | UPI Intent deep-linking via `url_launcher` |

---

## 🗂️ Project File Structure

```
RideBuddyy/
├── firestore.rules                         # Production Firestore security rules
├── firestore.indexes.json                  # Firestore composite indexes
├── android/                                # Android native build configuration (AGP 8.11.1, Gradle 8.14)
└── lib/
    ├── main.dart                           # App initialization & Firebase setup
    │
    ├── core/                               # Design system & shared utilities
    │   ├── theme/
    │   │   ├── app_colors.dart             # Brand colors (Navy, Yellow, Surface)
    │   │   └── app_theme.dart              # Global Material 3 theme data
    │   ├── utils/
    │   │   ├── matching_service.dart       # Haversine distance & route matching engine
    │   │   └── role_utils.dart             # User role & vehicle helpers
    │   └── widgets/
    │       ├── loading_states.dart         # Shimmer skeletons, loaders, & empty states
    │       ├── pooling_header.dart         # Standardized screen header
    │       └── ride_card.dart              # Interactive ride card with passenger & invite actions
    │
    ├── data/                               # Data models & Firestore repositories
    │   ├── models/
    │   │   ├── booking_model.dart          # Authoritative seat reservation model
    │   │   ├── commute_schedule_model.dart # Recurring commute schedule & waypoints
    │   │   ├── invitation_model.dart       # Direct invite & POOL-XXXX code schema
    │   │   ├── notification_model.dart     # In-app notification data model
    │   │   ├── ride_model.dart             # Ride occurrence model (backward compatible)
    │   │   ├── ride_request_model.dart     # Join-request schema
    │   │   ├── subscription_model.dart     # Commuter subscription schema
    │   │   └── vehicle_model.dart          # Registered vehicle model
    │   └── repositories/
    │       ├── booking_repository.dart     # Atomic seat booking, approval, & cancellation
    │       ├── commute_repository.dart     # Commute schedules & idempotent occurrence generation
    │       ├── invitation_repository.dart  # User search, invite dispatch, & transactional accept
    │       ├── notification_repository.dart# In-app & FCM notification dispatcher
    │       └── subscription_repository.dart# Subscription CRUD & subscriber counter
    │
    ├── features/                           # User-facing modules & workflows
    │   ├── main_shell.dart                 # 5-tab root navigation container
    │   ├── home/
    │   │   └── home_tab.dart               # Home dashboard with quick commute actions
    │   ├── commute/
    │   │   ├── create_commute_page.dart    # Multi-step recurring commute publisher
    │   │   ├── discover_publishers_page.dart # Commute discovery & subscription dialog
    │   │   ├── my_schedules_page.dart      # Publisher schedule manager
    │   │   └── my_subscriptions_page.dart  # Commuter subscriptions list
    │   ├── invitations/
    │   │   ├── invitations_page.dart       # Incoming/Sent invites & code redemption
    │   │   └── send_invitation_sheet.dart  # Modal to search riders & send invites
    │   ├── bookings/
    │   │   └── passenger_list_sheet.dart   # Driver passenger roster & boarding PIN view
    │   ├── notifications/
    │   │   └── notification_center_page.dart # In-app notification center
    │   ├── find_ride/
    │   │   └── find_ride_tab.dart          # One-time ride search (filters out invite-only)
    │   ├── offer_ride/
    │   │   └── offer_ride_tab.dart         # One-time ride posting tab
    │   ├── my_trips/
    │   │   ├── my_trips_tab.dart           # Past and upcoming trip history
    │   │   └── driver_requests_modal.dart  # Driver join-request review sheet
    │   ├── profile/
    │   │   └── profile_tab.dart            # User profile & stats
    │   ├── safety/
    │   │   └── safety_sheet.dart           # Emergency SOS & contact sharing
    │   └── vehicles/
    │       └── vehicles_page.dart          # Vehicle registration & selection
    │
    └── pages/                              # Core screens & utility services
        ├── login_page.dart                 # Google Sign-In & Auth routing
        ├── registration_page.dart          # Profile completion
        ├── enhanced_map_picker.dart        # OSM map picker with geocoding
        ├── map_picker_page.dart            # Lightweight coordinate selector
        ├── live_ride_tracking_page.dart    # Active ride live GPS map
        ├── live_tracking_service.dart      # Background position tracking
        ├── chat_page.dart                  # Per-ride messaging channel
        ├── upi_payment_page.dart           # UPI payment gateway
        └── rating_dialog.dart              # 5-star mutual rating dialog
```

---

## 🗄️ Firestore Database Schema

### 1. `commuteSchedules/{scheduleId}`
Recurring commute templates created by publishers:
```json
{
  "publisherId": "uid_driver_123",
  "publisherName": "Alex Driver",
  "from": "Koramangala, Bengaluru",
  "to": "Whitefield, Bengaluru",
  "from_lat": 12.9352,
  "from_lng": 77.6245,
  "to_lat": 12.9698,
  "to_lng": 77.7500,
  "waypoints": [
    {"name": "Marathahalli Bridge", "lat": 12.9569, "lng": 77.7011, "order": 0}
  ],
  "departureTime": "09:00",
  "daysOfWeek": [1, 2, 3, 4, 5],
  "seats": 3,
  "visibility": "public",
  "status": "active",
  "subscriberCount": 4,
  "maxDetourKm": 3.0,
  "estimatedCostPerSeat": 90,
  "createdAt": "Timestamp"
}
```

### 2. `rides/{rideId}`
Individual ride occurrences (deterministic IDs `${scheduleId}_${YYYY-MM-DD}` for recurring rides):
```json
{
  "scheduleId": "schedule_123",
  "occurrenceDate": "2026-10-20",
  "riderId": "uid_driver_123",
  "from": "Koramangala",
  "to": "Whitefield",
  "seats": 3,
  "remainingSeats": 1,
  "acceptedByList": ["uid_rider_1", "uid_rider_2"],
  "rideCode": "7482",
  "status": "published",
  "visibility": "public",
  "dateTime": "Timestamp",
  "timestamp": "Timestamp"
}
```

### 3. `subscriptions/{subscriptionId}`
Commuter subscriptions to a publisher's schedule:
```json
{
  "subscriberId": "uid_rider_1",
  "subscriberName": "John Commuter",
  "scheduleId": "schedule_123",
  "publisherId": "uid_driver_123",
  "preferredDays": [1, 2, 3, 4, 5],
  "status": "active",
  "createdAt": "Timestamp"
}
```

### 4. `invitations/{invitationId}`
Direct invitations and shareable `POOL-XXXX` codes:
```json
{
  "publisherId": "uid_driver_123",
  "recipientId": "uid_rider_1",
  "rideId": "ride_456",
  "inviteCode": "POOL-9K2F",
  "status": "pending",
  "seatsOffered": 1,
  "expiresAt": "Timestamp",
  "createdAt": "Timestamp"
}
```

### 5. `bookings/{bookingId}`
Authoritative seat reservations created upon approval or invitation acceptance:
```json
{
  "rideId": "ride_456",
  "driverId": "uid_driver_123",
  "passengerId": "uid_rider_1",
  "seatsBooked": 1,
  "boardingPin": "7482",
  "status": "confirmed",
  "createdAt": "Timestamp"
}
```

---

## 🚀 Setup & Installation

### 1. Prerequisites
- **Flutter SDK:** `^3.x`
- **Dart SDK:** `^3.x`
- **Android Studio / VS Code** with Flutter & Dart extensions
- **Firebase Project** with Authentication and Cloud Firestore enabled

### 2. Clone & Install
```bash
# Clone the repository
git clone https://github.com/your-username/RideBuddyy.git
cd RideBuddyy

# Install dependencies
flutter pub get
```

### 3. Deploy Firebase Rules & Indexes
Deploy the production Firestore security rules and composite indexes:
```bash
# Ensure Firebase CLI is installed and logged in
npm install -g firebase-tools
firebase login

# Deploy rules and indexes to your Firebase project
firebase deploy --only firestore:rules,firestore:indexes
```

### 4. Build & Run
```bash
# Run code analysis
flutter analyze

# Launch on connected Android device or emulator
flutter run

# Or build debug APK
flutter build apk --debug
```

---

## 🔒 Security & Rules Validation

All security boundaries are enforced server-side by `firestore.rules`:
1. **Seat Capacity Invariance:** Firestore enforces that `remainingSeats` can never fall below $0$ or exceed the vehicle's total `seats`.
2. **Access Control:** Commute management actions are restricted strictly to the authentic publisher (`request.auth.uid == resource.data.publisherId`).
3. **Private Rides:** Rides marked `invite_only` are filtered out from open discovery.
4. **Non-Tamperable Bookings:** Bookings can only be altered or cancelled by the respective driver or passenger.

---

## 📄 License
This project is proprietary and confidential. All rights reserved © 2026 RideBuddyy Team.