# How the Canteen Admin Side Works

This guide explains in simple terms how the **Canteen Admin** section of the **FCampusEatzz** project operates. 

## 1. What is the Canteen Admin Side?
While the main "Admin Panel" manages the whole campus system (all users, all canteens), the **Canteen Admin** side is meant for the *individual canteen owners or managers*. It allows them to:
* Add or update their menu items.
* Receive and manage incoming food orders.
* View their daily sales and reports.

* **Technology used:** Pure HTML, CSS, and JavaScript.

## 2. Where are the Files?
Unlike the main Admin Panel which uses a C# server to generate pages, the Canteen Admin pages are simple static web files:
* **HTML Pages (`HTML/` folder):** Files prefixed with `canteen_` (like `canteen_admin_dashboard.html`, `canteen_manage_order.html`, `canteen_add_items.html`).
* **Styling (`CSS/` folder):** Files like `style.css` give it the look and feel.
* **Logic (`JS/` folder):** Files like `canteen-admin-dashboard.js`, `canteen-manage-order.js`. These contain the code that makes buttons work and loads the data.

## 3. How to Start and Test It
Because these are simple web files, you don't need a heavy server to run them initially:
* You can simply open `HTML/canteen_admin_login.html` or `HTML/canteen_admin_dashboard.html` in your web browser. 
* *Recommended:* Use a tool like **Live Server** in VS Code to run them, which automatically refreshes the page when you save code.

## 4. How it Connects to the Database
Similar to the main admin panel, these files do not talk to the database directly:
1. You open the HTML file in your browser.
2. The browser runs the JavaScript (`JS/canteen-*.js` files).
3. The JavaScript securely talks to the **Backend API** behind the scenes to fetch new orders or save a new menu item.

## 5. Quick Fixes
* **Orders Not Loading / Can't Add Items:** The Backend API must be running for these pages to work. Ensure the `backend_api.bat` script is running.
* **Layout Looks Broken:** Ensure the HTML files are correctly linking to the `../CSS` and `../JS` folders.