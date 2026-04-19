# Backend Integration Guide (.NET Web API)

This folder contains the ASP.NET Web API backend for your existing web and WebView app.

## Folder

- `backend/UniversityCanteen.Api`

## What is implemented

- OTP-based user login endpoints:
  - `POST /api/login.php` (alias for request OTP)
  - `POST /api/auth/request-otp`
  - `POST /api/auth/verify-otp`
  - `POST /api/auth/resend-otp`
- OTP flow in .NET with:
  - cryptographically random OTP generation,
  - SMTP email delivery,
  - hashed OTP storage in MySQL (`users.OtpCode`),
  - expiry-based verification.
- Additional role login endpoints:
  - `POST /api/admin/login`
  - `POST /api/canteen-admin/login`
- Health endpoints:
  - `GET /api/health`
  - `GET /api/health/db`
- MySQL integration using your database schema (`users`, `student`, `faculty`).
- CORS configured for Android WebView origin and local browser testing.

## Database setup

Your SQL dump file is at:

- `universitycanteendb.sql`

Import it into MariaDB/MySQL.

For XAMPP users:

1. Open XAMPP Control Panel.
2. Start `Apache` and `MySQL`.
3. Open phpMyAdmin (`http://localhost/phpmyadmin`).
4. Create database `universitycanteendb`.
5. Import `universitycanteendb.sql`.

Example (PowerShell):

```powershell
Set-Location "d:\#practicals\CampusEatzz"
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS universitycanteendb;"
mysql -u root -p universitycanteendb < .\universitycanteendb.sql
```

## Configure connection string

Edit:

- `backend/UniversityCanteen.Api/appsettings.json`
- `backend/UniversityCanteen.Api/appsettings.Development.json`

Key:

- `ConnectionStrings:DefaultConnection`

Default for XAMPP MySQL is already configured as:

`Server=127.0.0.1;Port=3306;Database=universitycanteendb;User ID=root;Password=;SslMode=None;TreatTinyAsBoolean=true;`

If your XAMPP MySQL has a password, update `Password=` accordingly.

## Configure SMTP for OTP emails

Edit these files:

- `backend/UniversityCanteen.Api/appsettings.json` (production placeholders)
- `backend/UniversityCanteen.Api/appsettings.Development.json` (local development values)

Keys used:

- `Smtp:Host`
- `Smtp:Port`
- `Smtp:EnableSsl`
- `Smtp:UserName`
- `Smtp:Password`
- `Smtp:FromEmail`
- `Smtp:FromName`
- `Otp:CodeLength`
- `Otp:ExpiryMinutes`
- `Otp:EmailSubject`

Important:

- For Gmail SMTP use host `smtp.gmail.com` with port `587` and SSL enabled.
- Use an App Password (not your normal Gmail account password).
- App startup automatically ensures `users.OtpCode` is `VARCHAR(255)` so hashed OTP values can be stored.

## Optional: set a known test password

If you do not know existing plaintext passwords from the SQL dump, create a known one for testing OTP flow.

Generate a bcrypt hash using XAMPP PHP:

```powershell
C:\xampp\php\php.exe -r "echo password_hash('admin123', PASSWORD_BCRYPT), PHP_EOL;"
```

Use this BCrypt.Net-compatible hash for `admin123`:

`$2a$10$Hs1PEbjYz32jKOnqi1CG9O3gBUuy84aX9DUI7M7/uwE/L9GzT1BKq`

Use phpMyAdmin SQL:

```sql
UPDATE users
SET PasswordHash = '$2a$10$Hs1PEbjYz32jKOnqi1CG9O3gBUuy84aX9DUI7M7/uwE/L9GzT1BKq'
WHERE EmailId = '23bmii147@gmail.com';
```

Then login with:

- Email: `23bmii147@gmail.com`
- Password: `admin123`

## Run backend

```powershell
Set-Location "d:\#practicals\CampusEatzz\backend\UniversityCanteen.Api"
dotnet restore
dotnet run --urls "http://0.0.0.0:5000"
```

For Android device/emulator testing, prefer a stable public HTTPS endpoint (for example Ngrok) so API calls continue working when the device network changes.

## Match Flutter app base URL

Set your Flutter app backend URL in:

- `flutter_app/lib/core/constants/api_config.dart`

Example:

```text
primaryBaseUrl = 'http://192.168.1.45:5000'
```

Recommended for stable testing:

```text
primaryBaseUrl = 'https://your-subdomain.ngrok-free.app'
fallbackBaseUrls = ['http://192.168.1.45:5266']
```

## OTP request/verify format

Request OTP:

`POST /api/auth/request-otp` (or `/api/login.php`)

```json
{
  "email": "23bmii147@gmail.com",
  "password": "your-password"
}
```

Verify OTP:

`POST /api/auth/verify-otp`

```json
{
  "email": "23bmii147@gmail.com",
  "otp": "123456"
}
```

Successful verify response:

```json
{
  "success": true,
  "message": "OTP verified. Login successful.",
  "data": {
    "id": 101,
    "name": "Student 23BMII147",
    "email": "23bmii147@gmail.com",
    "role": "Student",
    "canteenId": null,
    "canteenName": null
  }
}
```

## Admin credentials source

Admin and canteen-admin credentials are currently configured in:

- `backend/UniversityCanteen.Api/appsettings.json`

You can replace these values with your production credentials or move them to secure secrets.

## Render deployment checklist (Docker)

If your Render logs show `Unable to connect to any of the specified MySQL hosts`, the app is usually still pointing to a local host such as `127.0.0.1`.

Use this checklist for reliable production deployment:

1. Deploy from the repository root so Render can use the root `Dockerfile`.
2. Ensure the service is using the latest commit that includes dynamic `PORT` binding.
3. In Render Environment Variables, set:

- `ASPNETCORE_ENVIRONMENT=Production`
- `ConnectionStrings__DefaultConnection=Server=<cloud-mysql-host>;Port=3306;Database=<db-name>;User ID=<user>;Password=<password>;SslMode=Required;TreatTinyAsBoolean=true;`
- `Startup__FailOnSchemaInitError=false`
- `Notifications__Scheduler__Enabled=false` (optional temporary setting while DB connectivity is being fixed)

As an alternative, the API can also resolve common MySQL env variables if `ConnectionStrings__DefaultConnection` is not set, including:

- `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, `MYSQLPASSWORD`
- `DATABASE_URL` / `MYSQL_URL` style MySQL URLs

4. Set your health check path to:

- `/api/health`

5. Verify database reachability after deploy:

- `GET /api/health` should return API running.
- `GET /api/health/db` should return database connection successful.

### CORS for production clients

Set allowed frontend domains as environment variables in Render:

- `Cors__AllowedOrigins__0=https://<your-frontend-domain>`
- `Cors__AllowedOrigins__1=https://<your-other-domain>`

Avoid broad wildcard origins in production.

### Common MySQL connectivity causes on Render

1. Connection string still uses `localhost` or `127.0.0.1`.
2. Cloud MySQL firewall or network policy blocks Render egress.
3. SSL is required by provider but missing in connection string.
4. Wrong host, user, password, or database name.
