# How the Admin Panel Works

This guide explains in simple terms how the Admin side of the **FCampusEatzz** project is set up and functions.

## 1. What is the Admin Panel?
The admin panel is the website used to manage the canteen system. It is a separate mini-website that provides the dashboards, menus, and controls for the administrators. 

* **Where to find it:** Once running, you can access it in your browser at `http://localhost:5001`.
* **Technology used:** It is built using .NET (ASP.NET Core MVC).

## 2. Where are the Files?
* **`admin_files/` folder**: This is the heart of the admin website. It handles loading the web pages and checking the paths you visit.
  * **Controllers & Views**: These are the files that actually draw the web pages (like the dashboard or user management screens).
* **Shared Folders (`JS/`, `CSS/`, `assets/`)**: To keep things organized, the admin website shares its design (CSS), interactivity (JS), and branding files (assets) with the rest of the project. The admin panel links to these main folders so you don't have to copy files around.

## 3. How to Start and Stop It
* **To Start:** Double-click or run the `admin_api.bat` file in the main folder. This will start the website on port `5001`.
* **To Stop:** Run the `stop-admin-files.bat` file.

## 4. How it Connects to the Database
The admin panel itself *does not* talk directly to the database. Instead:
1. The admin panel draws the website on your screen.
2. The JavaScript files (inside the `JS/` folder) run in your browser.
3. When you click a button (like "Delete User" or "View Orders"), the JavaScript talks to the main **Backend API** to get the actual data from the database.

## 5. Quick Fixes
* **"Address Already in Use" Error:** This means another program is already using port 5001. You can stop it by opening the terminal and stopping the running task, or simply run the `fix_firewall.bat` or `stop-admin-files.bat` to clear it out.
* **Missing Images or Styles:** Make sure the `CSS`, `JS`, and `assets` folders exist in the main folder (right outside `admin_files`), because the admin panel relies on them.