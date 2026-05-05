# FCampusEatzz Flutter Customer and Canteen Admin Page-Wise Design and Button Structure

## Scope
This document explains the Flutter Customer app and Flutter Canteen Admin module page by page.

Focus:
- Page structure
- Button and control behavior
- User interaction flow

Out of scope:
- UI color and visual styling

## Part A: Customer App

### Global Shell and Navigation

#### Bootstrap Screen
- Purpose: restore session and cart data, then route to Home or Login.
- UI: loading state only. No user controls.

#### Bottom Navigation (Global)
- Tabs: Home, Wallet, Profile.
- Action: tap a tab to open the target screen and reset stack.

#### Common Headers
- Many screens use a top header with title, optional subtitle, and a back button.
- Home header includes a notifications bell button with unread badge.

### Page 1: Login

#### Purpose
Authenticate user and request OTP.

#### Main Blocks
- Brand header
- Login form card
- Canteen admin entry button

#### Buttons and Controls
- Email or Enrollment Number input
- Password input with show/hide toggle
- Continue with OTP button
- Canteen Admin Login button

#### Actions
- Continue with OTP triggers OTP request and navigates to OTP screen on success.
- Canteen Admin Login opens the Canteen Admin entry flow.

### Page 2: OTP Verification

#### Purpose
Verify 6 digit OTP for login.

#### Main Blocks
- OTP input card
- Resend action
- Session expired guard

#### Buttons and Controls
- 6 OTP digit inputs with auto focus advance
- Verify button
- Resend OTP action
- Go to Login button (session expired state)

#### Actions
- Verify logs in and routes to Home.
- Resend OTP requests a new code and shows toast.
- Session expired routes to Login.

### Page 3: Home

#### Purpose
Discover canteens and menus.

#### Main Blocks
- Search bar and filter button
- Hero banner with CTA
- Feature cards row
- Canteen list cards
- AI chat banner
- Contact us prompt
- Floating chatbot button

#### Buttons and Controls
- Search bar tap opens search sheet
- Filter icon opens filter sheet
- Browse Canteens CTA scrolls to canteen section
- Canteen card tap opens Menu screen
- Heart icon toggles Save Canteen
- AI chat banner tap opens Chatbot screen
- Contact Us prompt button opens Contact Us
- Floating chat button opens Chatbot
- Notification bell opens Notifications screen

#### Search Sheet
- Search input with clear button
- Canteens results list, tap to open Menu
- Dishes results list
- Empty state when no results

#### Filter Sheet
- Vegetarian only toggle
- Open now toggle
- Apply Filters button returns filter settings

### Page 4: Menu

#### Purpose
Browse menu items for a specific canteen.

#### Main Blocks
- Hero app bar with canteen image and back button
- Category chips (sticky)
- Menu item cards
- Maintenance banner (if canteen in maintenance)
- Checkout bar (when cart has items for this canteen)

#### Buttons and Controls
- Back button
- Category chip tap filters items
- Add button on each item
- Checkout bar tap opens Cart

#### Actions
- Add button adds item to cart.
- If cart has items from another canteen, confirm dialog appears to clear and add.
- Checkout bar shows item count and total and routes to Cart.

### Page 5: Cart

#### Purpose
Review cart items and proceed to checkout.

#### Main Blocks
- Cart item cards
- Order summary card

#### Buttons and Controls
- Quantity stepper: plus and minus
- Delete item button
- Proceed to Checkout button
- Clear Cart button
- Browse Menu button (empty state)

### Page 6: Checkout

#### Purpose
Select payment method and place order.

#### Main Blocks
- Order summary
- Payment method selector
- Method details section

#### Buttons and Controls
- Payment method chips: Wallet, UPI, Cash
- Wallet: agree checkbox
- UPI: UPI ID input and agree checkbox
- Pay button
- Back button

#### Actions
- Pay validates method inputs and places order.
- On success, clears cart and routes to Order Success.

### Page 7: Order Success

#### Purpose
Confirm order placement and next steps.

#### Buttons and Controls
- Order More button routes to Home
- View All Orders button routes to Orders

#### Guard State
- If session expired, show Login button.

### Page 8: Orders

#### Purpose
View order history and open order details.

#### Buttons and Controls
- Order card tap opens Order Details
- Back button
- Sign In button (if not logged in)

### Page 9: Order Details

#### Purpose
View order status, items, and post order actions.

#### Main Blocks
- Order info and status badges
- Items list
- Summary totals
- Status history
- Cancel order card (only within 60 seconds window)
- Refund status or request section

#### Buttons and Controls
- Back button
- Cancel Order button (shows confirm dialog)
- Request Refund button (if eligible)

#### Actions
- Cancel Order triggers cancel and refund logic, then refreshes state.
- Request Refund opens Refund Request screen.

### Page 10: Refund Request

#### Purpose
Submit a refund request with a reason.

#### Main Blocks
- Refund amount card
- Reason list

#### Buttons and Controls
- Reason selection tiles
- Submit Refund Request button

#### Actions
- Submit sends refund request and returns to Order Details.

### Page 11: Refund History

#### Purpose
Track all refund requests.

#### Buttons and Controls
- Back button
- Pull to refresh list

#### Cards
- Status badge (Approved, Pending, Rejected)
- Optional admin notes

### Page 12: Wallet

#### Purpose
View balance, add money, and see transactions.

#### Main Blocks
- Balance card
- Add money card
- Transactions list

#### Buttons and Controls
- Quick amount buttons (100, 200, 500)
- Custom amount input
- Add Money button
- Retry action on error

### Page 13: Profile

#### Purpose
Account overview and quick links.

#### Main Blocks
- Avatar card
- Wallet card
- Account menu list
- Preferences menu list
- Dark mode toggle row
- Sign out row

#### Buttons and Controls
- Open button on avatar card (shows user detail sheet)
- Wallet Manage tap opens Wallet
- My Orders, My Refunds, Saved Canteens, Payment Methods
- Notifications link
- Taste profile (shows coming soon toast)
- Dark mode switch
- Sign out button with confirm dialog

### Page 14: Notifications

#### Purpose
Activity feed and order updates.

#### Buttons and Controls
- Back button
- Mark all read action
- Pull to refresh
- Tap notification to mark read and route based on action

#### Actions
- Notification routes to Order Details, Feedback, Menu, Wallet, Profile, or Home.

### Page 15: Saved Canteens

#### Purpose
Quick access to saved canteens.

#### Buttons and Controls
- Back button
- Canteen row tap opens Menu
- Heart button removes from saved list

### Page 16: Contact Us

#### Purpose
Send support message to the team.

#### Buttons and Controls
- Name, Email, Subject, Message fields
- Send Message button
- Back button

### Page 17: Feedback

#### Purpose
Rate and review a completed order.

#### Buttons and Controls
- Star rating row (1 to 5)
- Review text field
- Submit Feedback button
- Back button

### Page 18: Chatbot

#### Purpose
AI powered food recommendations and questions.

#### Main Blocks
- Welcome panel with suggested queries
- Chat thread list
- Suggestions bar
- Input bar

#### Buttons and Controls
- Suggested query chips (tap to send)
- Clear chat button
- Send button
- Back button

## Part B: Canteen Admin Module

### Global Shell Structure (Applies to All Pages)

#### Header (Global)
Present on every page.

Contains:
- Current page title
- Current canteen name from session
- Logout button

Action:
- Logout clears canteen admin session and exits to login flow.

#### Bottom Navigation (Global)
Present on every page and used to switch major sections.

Navigation buttons:
1. Dashboard
2. Orders
3. Menu Items
4. Reports
5. Reviews
6. Wallet
7. Settings

Action:
- Tap any navigation button to load the selected page inside the same shell.

### Page 1: Dashboard

#### Purpose
Quick operational snapshot of canteen activity.

#### Main Blocks
- Stats summary cards
- Recent orders list
- Empty state for no orders

#### Buttons and Controls
- Pull to refresh gesture
- Retry action (API error state)

### Page 2: Orders

#### Purpose
Manage and update incoming order lifecycle.

#### Main Blocks
- Order status filter area
- Orders list with per order action
- Status badge and item summary per order

#### Buttons and Controls
- Status filter dropdown
- Refresh icon button
- Update Status button (per order)

#### Update Status Bottom Sheet
Controls:
- Status dropdown
- Estimated time input
- Cancel button
- Update button

Actions:
- Cancel closes sheet with no change.
- Update submits status and time update, then reloads orders.

### Page 3: Menu Items

#### Purpose
Create, edit, delete, and control availability of menu items.

#### Main Blocks
- Header with item count and Add action
- Menu item list cards
- Inline availability toggle

#### Buttons and Controls
- Add button opens menu item form (create mode)
- Edit icon button opens menu item form (edit mode)
- Delete icon button opens delete confirmation dialog
- Availability switch toggles active or inactive

#### Menu Item Form
Controls:
- Name, description, price, category, image URL
- Upload Image button
- Availability and vegetarian switches
- Cancel and Save buttons

Actions:
- Upload Image picks image, uploads to backend, fills image URL
- Cancel closes form without save
- Save validates fields and creates or updates item

#### Delete Confirmation Dialog
- Cancel button stops delete
- Delete button confirms delete and refreshes list

### Page 4: Reports

#### Purpose
Analyze orders and revenue using filter based reporting.

#### Main Blocks
- Period and status filter row
- Optional custom date range section
- Apply Filters action
- Summary cards
- Top items list
- Daily breakdown list

#### Buttons and Controls
- Period dropdown (daily, weekly, monthly, custom)
- Status dropdown
- From date button (custom mode)
- To date button (custom mode)
- Apply Filters button
- Pull to refresh gesture

### Page 5: Reviews

#### Purpose
Monitor customer feedback and allow admin responses.

#### Main Blocks
- Review stats cards
- Review list
- Existing response area or reply action

#### Buttons and Controls
- Reply button (reviews without response)

#### Reply Dialog
- Response text input
- Cancel button
- Send button

Actions:
- Cancel closes dialog
- Send submits response and reloads reviews

### Page 6: Wallet

#### Purpose
Revenue summary, payment breakdown, and recent transactions.

#### Main Blocks
- Revenue summary cards
- Payment breakdown list
- Recent transactions list

#### Buttons and Controls
- Pull to refresh gesture
- Retry action (error state)

### Page 7: Settings

#### Purpose
Manage canteen details, admin profile, and password security.

#### Main Blocks
- Canteen Info card
- Admin Profile card
- Change Password card

#### Section A: Canteen Info
Controls:
- Canteen name
- Phone
- Opening time
- Closing time
- Save Canteen Info button

Action:
- Validates required fields and updates canteen details.

#### Section B: Admin Profile
Controls:
- Full name
- Email
- Profile image URL
- Save Profile button

Action:
- Validates required fields and updates profile and session display data.

#### Section C: Change Password
Controls:
- Current password
- New password
- Confirm new password
- Change Password button

Action:
- Validates all fields, matching confirmation, and minimum length before submit.

### Validation and Guard Rules
- Required fields checked before submit.
- Password update checks:
  - Current, new, and confirm are present.
  - New password matches confirm password.
  - New password meets minimum length.
- Empty review reply is not submitted.
- Success shows confirmation and refreshes data.
- Failure shows error feedback and keeps page state for retry.

### Data Flow (Common Across Pages)
1. User triggers an action through button, dropdown, switch, or gesture.
2. UI updates local state where needed.
3. Service layer calls backend endpoints.
4. On success, page confirms and refreshes data.
5. On failure, page shows error and allows retry.
