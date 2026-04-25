# Frontend Design Inventory (Implementation Only)

Date: 2026-04-21
Project: CampusEatzz
Scope: This document lists what currently exists in the frontend codebase. It intentionally excludes visual design choices and color palette guidance.

## 1) Frontend Surfaces Present

1. Web Admin frontend (ASP.NET Core MVC + shared JS/CSS assets)
2. Flutter mobile frontend (Customer app + Canteen Admin module)
3. Standalone web feedback frontend page served from backend static files

## 2) Web Admin Frontend

### 2.1 Entry and Routing

- Frontend host project: `admin_files`
- Controller that maps admin pages: `admin_files/Controllers/HomeController.cs`
- View folder: `admin_files/Views/Home`
- Shared partials/layout: `admin_files/Views/Shared`
- Shared web assets used by admin pages:
  - CSS: `CSS/style.css`
  - JS: `JS/admin-*.js`
  - Images and misc assets: `assets/`

### 2.2 Implemented Admin Pages

| Action/Route | View File | Page JS Wiring | Functional Area |
|---|---|---|---|
| `AdminLogin` | `admin_files/Views/Home/AdminLogin.cshtml` | `admin-common.js`, `admin-login.js` | Admin authentication |
| `AdminDashboard` | `admin_files/Views/Home/AdminDashboard.cshtml` | `admin-common.js`, `admin-dashboard.js` | KPI dashboard + quick actions |
| `AdminAllOrders` | `admin_files/Views/Home/AdminAllOrders.cshtml` | `admin-common.js`, `admin-all-orders.js` | Order list and order status operations |
| `AdminOrderInvoice` | `admin_files/Views/Home/AdminOrderInvoice.cshtml` | `admin-common.js`, `admin-order-invoice.js` | Order invoice/details view |
| `AdminManageUsers` | `admin_files/Views/Home/AdminManageUsers.cshtml` | `admin-common.js`, `admin-manage-users.js` | Customer/user management |
| `AdminWallets` | `admin_files/Views/Home/AdminWallets.cshtml` | `admin-common.js`, `admin-wallets.js` | Wallet balances and wallet overview |
| `AdminWalletTransactions` | `admin_files/Views/Home/AdminWalletTransactions.cshtml` | `admin-common.js`, `admin-wallet-transactions.js` | Wallet transaction log |
| `AdminManageCanteens` | `admin_files/Views/Home/AdminManageCanteens.cshtml` | `admin-common.js`, `admin-manage-canteens.js` | Canteen CRUD + logo/image support |
| `AdminManageCanteenAdmins` | `admin_files/Views/Home/AdminManageCanteenAdmins.cshtml` | `admin-common.js`, `admin-manage-canteen-admins.js` | Canteen admin account management |
| `AdminContactMessages` | `admin_files/Views/Home/AdminContactMessages.cshtml` | `admin-common.js`, `admin-contact-messages.js` | Contact message queue and status updates |
| `AdminReviews` | `admin_files/Views/Home/AdminReviews.cshtml` | `admin-common.js`, `admin-reviews.js` | Review listing and filtering |
| `AdminReports` | `admin_files/Views/Home/AdminReports.cshtml` | `admin-common.js`, `admin-reports.js` | Sales/report analytics views |
| `AdminSettings` | `admin_files/Views/Home/AdminSettings.cshtml` | `admin-common.js`, `admin-settings.js` | Platform/app settings, profile, maintenance |
| `Index` | `admin_files/Views/Home/Index.cshtml` | No page-specific admin JS mapped | Default MVC starter page |
| `Privacy` | `admin_files/Views/Home/Privacy.cshtml` | No page-specific admin JS mapped | Privacy page |

### 2.3 Shared Admin Frontend Components Present

- `admin_files/Views/Shared/_AdminTopNav.cshtml`
  - Admin top navigation links for Dashboard, Orders, Users, Wallets, Canteens, Canteen Admins, Messages, Reviews, Reports, Settings
  - Desktop and mobile nav states
  - Logout trigger integration
- `admin_files/Views/Shared/_AdminFooter.cshtml`
- `admin_files/Views/Shared/_Layout.cshtml` (default MVC layout file)

### 2.4 Shared Admin JS Capabilities Present

- `JS/admin-common.js`
  - API base candidate resolution/fallback
  - Auth token/session header wiring
  - Admin session guard + logout
  - Generic request helper
  - Branding/application name and logo application
- Page modules:
  - `admin-dashboard.js`
  - `admin-all-orders.js`
  - `admin-order-invoice.js`
  - `admin-manage-users.js`
  - `admin-wallets.js`
  - `admin-wallet-transactions.js`
  - `admin-manage-canteens.js`
  - `admin-manage-canteen-admins.js`
  - `admin-contact-messages.js`
  - `admin-reviews.js`
  - `admin-reports.js`
  - `admin-settings.js`
  - `admin-login.js`

### 2.5 Other Web Utility Script Present

- `assets/disable_back.js`
  - Browser back-navigation interception utility with redirect target support.

## 3) Flutter Mobile Frontend

### 3.1 Entry and App Wiring

- App entry: `flutter_app/lib/main.dart`
- Boot/home decision: `features/auth/bootstrap_screen.dart`
  - Restores auth session and cart state before deciding between login and home.
- Dependency/state setup in app root uses Provider/ChangeNotifier patterns.

### 3.2 State Notifiers Present

- `flutter_app/lib/state/auth_provider.dart`
- `flutter_app/lib/state/canteen_provider.dart`
- `flutter_app/lib/state/cart_provider.dart`
- `flutter_app/lib/state/notification_provider.dart`
- `flutter_app/lib/state/orders_provider.dart`
- `flutter_app/lib/state/wallet_provider.dart`

### 3.3 Customer Navigation and Core Screen Areas

- Bottom navigation tabs defined in `core/widgets/customer_bottom_nav.dart`:
  - Home
  - Cart
  - Wallet
  - Profile

### 3.4 Customer/Auth Screens Present

- `features/auth/login_screen.dart`
- `features/auth/otp_screen.dart`
- `features/auth/bootstrap_screen.dart`

### 3.5 Customer Functional Screens Present

- Home and discovery:
  - `features/home/home_screen.dart`
  - `features/menu/menu_screen.dart`
- Cart and checkout:
  - `features/cart/cart_screen.dart`
  - `features/payment/payment_screen.dart`
- Orders:
  - `features/orders/orders_screen.dart`
  - `features/orders/order_details_screen.dart`
  - `features/orders/order_success_screen.dart`
- Account and wallet:
  - `features/profile/profile_screen.dart`
  - `features/wallet/wallet_screen.dart`
- Communication/feedback/notifications:
  - `features/contact/contact_us_screen.dart`
  - `features/feedback/feedback_screen.dart`
  - `features/notifications/notifications_screen.dart`
  - `features/notifications/notification_navigation.dart`

### 3.6 Canteen Admin (Inside Flutter App) Present

- Entry/login/shell:
  - `features/canteen_admin/canteen_admin_entry_screen.dart`
  - `features/canteen_admin/canteen_admin_login_screen.dart`
  - `features/canteen_admin/canteen_admin_shell_screen.dart`
- In-shell tabs implemented in canteen admin shell:
  - Dashboard
  - Orders
  - Menu Items
  - Reports
  - Reviews
  - Wallet
  - Settings

### 3.7 Shared Flutter Layering Present

- Core constants/theme/widgets:
  - `flutter_app/lib/core/constants/`
  - `flutter_app/lib/core/theme/`
  - `flutter_app/lib/core/widgets/`
- Data models:
  - `flutter_app/lib/data/models/`
- API/service layer:
  - `flutter_app/lib/data/services/`
    - `api_client.dart`
    - `auth_service.dart`
    - `canteen_service.dart`
    - `canteen_admin_service.dart`
    - `customer_service.dart`
    - `push_notification_service.dart`

### 3.8 Flutter Frontend Assets Present

- Asset root: `flutter_app/assets/images/`
- Includes logo and food/canteen image assets referenced by home/menu/ui widgets.

## 4) Standalone Web Feedback Frontend (Static)

- File: `backend/UniversityCanteen.Api/wwwroot/feedback/index.html`
- Implemented frontend behavior in page script:
  - Reads `email` and `orderRef` from URL query params
  - Collects star rating and text feedback
  - Submits review payload to `POST /api/customer/reviews`

## 5) Frontend Documentation Already Present

- `mdr/Admin_Panel_Documentation.md`
- `mdr/Customer_App_Documentation.md`
- `mdr/Canteen_Admin_Documentation.md`
- `mdr/Flutter_Canteen_Admin_Design_and_Button_Structure.md`

This file is the implementation inventory version focused strictly on what is currently present in frontend code.
