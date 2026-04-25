# CampusEatzz Flutter App

Native Flutter customer application converted from the existing CampusEatzz web frontend.

## Highlights

- Native Flutter UI (no WebView)
- UI style aligned with existing web design (blue gradient theme, rounded cards, spacing, flow)
- Existing backend API integration via Dio
- Provider state management
- SharedPreferences persistent login and session cache
- Loading, error, and empty states for core screens

## Implemented Screens

- Login
- OTP Verification
- Register (UI placeholder, backend endpoint not available in current API)
- Home (canteens + trending dishes)
- Menu (per canteen)
- Cart
- Payment (Wallet, UPI, Cash flow)
- Wallet
- Profile
- Orders
- Order Details
- Order Success

## Backend Base URL

Default URLs are configured in [lib/core/constants/api_config.dart](lib/core/constants/api_config.dart) and aligned with your existing Android config.

- Primary: `http://10.114.114.30:5266` (set this to your current PC LAN IP)
- Fallbacks: `http://10.0.2.2:5266`, `http://localhost:5266`, `http://127.0.0.1:5266`

Update these if your backend host changes.

## Run Instructions

1. Install latest Flutter stable from the [Flutter install guide](https://docs.flutter.dev/get-started/install).

1. From this folder run:

```bash
flutter create .
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

APK output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Notes

- This app uses your existing backend APIs:
  - `api/login.php`
  - `api/auth/verify-otp`
  - `api/auth/resend-otp`
  - `api/auth/me`
  - `api/public/canteens`
  - `api/customer/wallet`
  - `api/customer/wallet/transactions`
  - `api/customer/wallet/recharge`
  - `api/customer/orders`
  - `api/customer/orders/{orderRef}`
- For `api/canteen/menu-items`, backend authorization applies. Ensure valid JWT from OTP login is available.
