# Render + Railway MySQL Diagnostic Checklist

## Issue
Wallet API returns: "Internal server error while fetching wallet"  
Render logs show: `Table 'universitycanteendb.website_maintenance' doesn't exist` (partially fixed)  
App can't connect to backend

## Root Cause
Railway provides both **internal** and **public** connection values.  
- ❌ **Internal values** (private IP) = not reachable from Render  
- ✅ **Public values** = reachable from Render

## What to Check (Use Railway Extension)

### 1. Get Your Railway MySQL Connection Details
In VS Code Railway Extension:
1. Open Railway project
2. Find your MySQL database service
3. Get these **PUBLIC** values:
   - `MYSQL_PUBLIC_HOST` (not internal host)
   - `MYSQL_PUBLIC_PORT`
   - `MYSQLDATABASE`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`

**DO NOT use** `MYSQLHOST` (internal) - this is the common mistake!

### 2. Check Render Environment Variables
Go to https://dashboard.render.com → Your Backend Service → Environment:

Should have:
```
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=Server=<MYSQL_PUBLIC_HOST>;Port=<MYSQL_PUBLIC_PORT>;Database=<MYSQLDATABASE>;User ID=<MYSQLUSER>;Password=<MYSQLPASSWORD>;SslMode=Required;TreatTinyAsBoolean=true;
Startup__FailOnSchemaInitError=false
```

### 3. Test Database Reachability
Once env vars are set, test these endpoints:

```bash
# API health
curl https://campuseatzz.onrender.com/api/health

# Database health  
curl https://campuseatzz.onrender.com/api/health/db
```

### 4. Verify Table Creation
The `website_maintenance` table should be auto-created on first request.  
Check Render logs for:
```
Verified startup schema for auth/login support tables and columns.
```

## Next Steps

1. **Confirm connection values**: Use Railway extension to verify MYSQL_PUBLIC_* values
2. **Update Render env vars**: Set `ConnectionStrings__DefaultConnection` with correct PUBLIC host
3. **Trigger redeploy**: Push code or manually trigger deploy
4. **Check logs**: Verify no MySQL connection errors
5. **Test endpoints**: Call /api/health/db to confirm connection works

## If Still Failing

Run in Railway extension:
```sql
SHOW TABLES;
DESCRIBE website_maintenance;
DESCRIBE wallets;
DESCRIBE wallet_transactions;
```

Verify all 3 tables exist (created by startup schema).
