# Railway + Render MySQL Setup Checklist

## ✅ Prerequisites
- [ ] Railway extension installed in VS Code
- [ ] Access to https://dashboard.render.com
- [ ] Git pushed with latest code (includes website_maintenance table fix)

---

## 🔴 CRITICAL: Get Railway PUBLIC Values Only

Do NOT use these (internal only):
- ❌ `MYSQLHOST`
- ❌ `MYSQL_HOST`  
- ❌ `MYSQL_INTERNAL_HOST`

DO use these (public/accessible):
- ✅ `MYSQL_PUBLIC_HOST`
- ✅ `MYSQL_PUBLIC_PORT`
- ✅ `MYSQLDATABASE`
- ✅ `MYSQLUSER`
- ✅ `MYSQLPASSWORD`

---

## Step-by-Step Setup

### 1️⃣ Get Railway Connection Values
```
VS Code → Railway Extension → MySQL Service → Variables Tab
Copy these 5 values:
```

| Variable | Value | Example |
|----------|-------|---------|
| MYSQL_PUBLIC_HOST | _____ | `mysql.railway.app` |
| MYSQL_PUBLIC_PORT | _____ | `3306` |
| MYSQLDATABASE | _____ | `universitycanteendb` |
| MYSQLUSER | _____ | `root` |
| MYSQLPASSWORD | _____ | `Xy9#mK2$` |

**Save these somewhere safe before proceeding!**

---

### 2️⃣ Build Connection String
Format:
```
Server=<PUBLIC_HOST>;Port=<PORT>;Database=<DB>;User ID=<USER>;Password=<PASSWORD>;SslMode=Required;TreatTinyAsBoolean=true;
```

Example with real values:
```
Server=mysql.railway.app;Port=3306;Database=universitycanteendb;User ID=root;Password=Xy9%23mK2%24;SslMode=Required;TreatTinyAsBoolean=true;
```

**Note:** If password has special chars, URL-encode them:
- `#` → `%23`
- `$` → `%24`
- `@` → `%40`
- `;` → `%3B`

---

### 3️⃣ Update Render Environment Variables

1. Go to: https://dashboard.render.com
2. Find service: `campuseatzz-backend`
3. Click: **Environment**
4. **Delete** any old `ConnectionStrings__DefaultConnection` value if it exists
5. **Add/Update** these variables:

| Key | Value |
|-----|-------|
| `ConnectionStrings__DefaultConnection` | *Your connection string from Step 2* |
| `ASPNETCORE_ENVIRONMENT` | `Production` |
| `Startup__FailOnSchemaInitError` | `false` |
| `Notifications__Scheduler__Enabled` | `false` |

6. Click **Save Changes**
7. ✅ Render will auto-trigger redeploy

---

### 4️⃣ Wait for Deployment
- ⏱️ Takes 2-3 minutes
- 📊 Watch Render logs in dashboard
- ✅ Look for: `Available at your primary URL`

---

### 5️⃣ Test the Setup

Open terminal and run:

```bash
# Test 1: API is running
curl https://campuseatzz.onrender.com/api/health

# Should return:
# CampusEatzz API is running 🚀

# Test 2: Database connection works
curl https://campuseatzz.onrender.com/api/health/db

# Should return:
# Database connection successful
```

✅ **Both return success?** → Database connection is working!  
❌ **Getting errors?** → Check connection string and special char encoding

---

### 6️⃣ Verify Tables Exist

Using Railway Extension:

1. Connect to your MySQL database
2. Run these queries:

```sql
SHOW TABLES;

-- Should see: wallets, wallet_transactions, website_maintenance, users, etc.

DESCRIBE website_maintenance;
DESCRIBE wallets;
DESCRIBE wallet_transactions;

-- All 3 tables should have their columns displayed
```

---

### 7️⃣ Test in Flutter App

1. Make sure backend is deployed ✅
2. Open Flutter app on device/emulator
3. Go to login screen
4. Sign in with valid credentials
5. **Navigate to Wallet screen**

Expected result: Wallet balance displays (no error)

---

## 🚨 If Something Goes Wrong

### ❌ Test 5 failed: "Connection refused"
- Verify `MYSQL_PUBLIC_HOST` not `MYSQLHOST`
- Check password special char encoding
- Verify SslMode=Required is set

### ❌ Wallet still shows error after DB connects
- Check Render logs for schema creation errors
- Verify all 3 tables exist (Step 6)
- Restart Flutter app and try again

### ❌ Tables don't exist in MySQL
- Check Render logs for `Verified startup schema...` message
- If missing, schema initialization failed
- Check database user has CREATE TABLE privilege

---

## ✅ Success Indicators

- [ ] Step 5 Test 1 returns: "CampusEatzz API is running 🚀"
- [ ] Step 5 Test 2 returns: "Database connection successful"
- [ ] Step 6 shows all 3 tables exist
- [ ] Step 7 wallet shows balance (no error)

When all 4 are checked: **✅ YOU'RE DONE!**

---

## 📝 Notes

- Connection string expires if not used for 30+ days on free tier
- Store connection string safely (it contains password)
- SslMode=Required is mandatory for Railway
- Render auto-redeploys when env vars change
