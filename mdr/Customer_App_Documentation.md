# How the Customer Side Works

This guide explains how the **Customer** (student/staff) side of the **FCampusEatzz** project is set up.

## 1. What is the Customer Side?
This is the main application that regular users interact with. It allows customers to:
* Browse available canteens and their menus.
* Add items to their cart.
* Top up their digital wallet and pay for orders.
* Track their order status.

* **Technology used:** **Flutter (Dart)** for the mobile app UI and flow, connected to the existing backend APIs.

## 2. Where are the Files?
The customer app is now fully Flutter-based.

**Flutter App (`flutter_app/` folder):**
* **App entry:** `flutter_app/lib/main.dart`
* **Customer features:** `flutter_app/lib/features/` (home, menu, cart, orders, wallet, profile)
* **State/providers:** `flutter_app/lib/state/`
* **API integration services:** `flutter_app/lib/data/services/`
* **Shared UI/theme/constants:** `flutter_app/lib/core/`
* **Static assets:** `flutter_app/assets/`

**Flutter Android runner (required by Flutter):**
* `flutter_app/android/` contains only the Flutter Android host project and build config.

## 3. How to Start and Test It
You can test the customer Flutter app directly:

* **Run on emulator/device:**
  1. Open a terminal.
  2. Go to `flutter_app` (`cd flutter_app`).
  3. Run `flutter pub get`.
  4. Run `flutter run`.

* **Build APK:**
  1. Go to `flutter_app` (`cd flutter_app`).
  2. Run `flutter build apk --debug`.
  3. Use the generated APK at `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`.

## 4. How it Connects to the Database
1. The customer taps a button (like "Place Order") in the app.
2. The JavaScript code (`JS/cart.js`) sends a request to the main **Backend API** over the network.
3. The Backend API saves the order to the database, deducts wallet balance, and replies with a success message.

## 5. Quick Fixes
* **App Not Connecting on Phone:** If your phone app cannot see menus or fails to login, ensure phone and backend machine are on the same Wi-Fi and verify base URL settings in `flutter_app/lib/core/constants/api_config.dart`.
* **White Screen on Browser:** Ensure the Backend API is open and running. Without the backend running, the frontend has no data to display.