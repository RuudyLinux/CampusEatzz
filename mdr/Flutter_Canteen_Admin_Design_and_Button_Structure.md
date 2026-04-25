# FCampusEatzz Flutter Canteen Admin Page-Wise Design and Button Structure

## Scope
This document explains the Flutter Canteen Admin module according to each page.

Focus:
- Page structure
- Button and control behavior
- User interaction flow

Out of scope:
- UI color description

## Global Shell Structure (Applies to All Pages)

### Header (Global)
Present on every page.

Contains:
- Current page title
- Current canteen name from session
- Logout button

Action:
- Logout: clears canteen admin session and exits to login flow.

### Bottom Navigation (Global)
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

## Page 1: Dashboard

### Purpose
Gives a quick operational snapshot of canteen activity.

### Main Blocks
- Stats summary cards
- Recent orders list
- Empty state for no orders

### Buttons and Controls
- Pull-to-refresh gesture
  - Reloads dashboard data.
- Retry action (when API error occurs)
  - Retries dashboard fetch.

## Page 2: Orders

### Purpose
Manage and update incoming order lifecycle.

### Main Blocks
- Order status filter area
- Orders list with per-order action
- Status badge and item summary per order

### Buttons and Controls
- Status filter dropdown
  - Filters orders and reloads list.
- Refresh icon button
  - Reloads the current filtered list.
- Update Status button (per order)
  - Opens update bottom sheet.

### Update Status Bottom Sheet
Controls:
- Status dropdown
- Estimated time input
- Cancel button
- Update button

Actions:
- Cancel: closes sheet with no change.
- Update: submits status and time update, then reloads orders.

## Page 3: Menu Items

### Purpose
Create, edit, delete, and control availability of menu items.

### Main Blocks
- Header with item count and Add action
- Menu item list cards
- Inline availability toggle

### Buttons and Controls
- Add button
  - Opens menu item form (create mode).
- Edit icon button (per item)
  - Opens same form (edit mode).
- Delete icon button (per item)
  - Opens delete confirmation dialog.
- Availability switch (per item)
  - Toggles active/inactive availability.

### Menu Item Form
Controls:
- Name, description, price, category, image URL
- Upload Image button
- Availability and vegetarian switches
- Cancel and Save buttons

Actions:
- Upload Image: picks image, uploads to backend, fills image URL.
- Cancel: closes form without save.
- Save: validates fields and creates or updates item.

### Delete Confirmation Dialog
- Cancel button: stops delete.
- Delete button: confirms delete and refreshes list.

## Page 4: Reports

### Purpose
Analyze orders and revenue using filter-based reporting.

### Main Blocks
- Period and status filter row
- Optional custom date range section
- Apply Filters action
- Summary cards
- Top items list
- Daily breakdown list

### Buttons and Controls
- Period dropdown
  - Selects daily, weekly, monthly, or custom mode.
- Status dropdown
  - Filters report by order status.
- From date button (custom mode)
  - Opens date picker for start date.
- To date button (custom mode)
  - Opens date picker for end date.
- Apply Filters button
  - Loads report with active filters.
- Pull-to-refresh gesture
  - Reloads reports with current filter state.

## Page 5: Reviews

### Purpose
Monitor customer feedback and allow admin responses.

### Main Blocks
- Review stats cards
- Review list
- Existing response area or reply action

### Buttons and Controls
- Reply button (for reviews without response)
  - Opens reply dialog.

### Reply Dialog
- Text input for response
- Cancel button
- Send button

Actions:
- Cancel: closes dialog.
- Send: submits response and reloads reviews.

## Page 6: Wallet

### Purpose
Show revenue summary, payment method breakdown, and recent transactions.

### Main Blocks
- Revenue summary cards
- Payment breakdown list
- Recent transactions list

### Buttons and Controls
- Pull-to-refresh gesture
  - Reloads wallet data.
- Retry action (error state)
  - Retries wallet fetch.

## Page 7: Settings

### Purpose
Manage canteen details, admin profile details, and password security.

### Main Blocks
- Canteen Info card
- Admin Profile card
- Change Password card

### Section A: Canteen Info
Controls:
- Canteen name
- Phone
- Opening time
- Closing time
- Save Canteen Info button

Action:
- Validates required fields and updates canteen details.

### Section B: Admin Profile
Controls:
- Full name
- Email
- Profile image URL
- Save Profile button

Action:
- Validates required fields and updates profile/session display data.

### Section C: Change Password
Controls:
- Current password
- New password
- Confirm new password
- Change Password button

Action:
- Validates all fields, matching confirmation, and minimum length before submit.

## Validation and Guard Rules
- Required fields are checked before submit.
- Password update checks:
  - Current, new, and confirm are present.
  - New password matches confirm password.
  - New password satisfies minimum length.
- Empty review reply is not submitted.
- Success usually shows confirmation and refreshes data.
- Failure shows error feedback and keeps page state for retry.

## Data Flow (Common Across Pages)
1. User triggers an action through button, dropdown, switch, or gesture.
2. UI updates local state where needed.
3. Service layer calls backend endpoints.
4. On success, page confirms and refreshes data.
5. On failure, page shows error and allows retry.

## Structure-Only Improvement Ideas
- Bulk order status update
- Multi-select menu operations
- Quick inline price editing
- Report export actions (CSV/PDF)
- Draft autosave for forms
