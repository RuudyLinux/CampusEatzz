# Update Render Environment Variables - Manual Method

## ✅ SAFE & SIMPLE - 2 MINUTES

### Step 1: Open Render Dashboard
Go to: https://dashboard.render.com

### Step 2: Find Your Service
- Look for: **campuseatzz-backend**
- Click on it

### Step 3: Go to Environment
- Click the **Environment** button (top menu bar)

### Step 4: Clear Old Values
- Look for any existing variable named: `ConnectionStrings__DefaultConnection`
- If it exists, **DELETE it** (click the X or delete button)

### Step 5: Add New Variable
Click **"Add Environment Variable"** button

**First variable:**
```
Key:   ConnectionStrings__DefaultConnection

Value: Server=roundhouse.proxy.rlwy.net;Port=47842;Database=universitycanteendb;User ID=root;Password=ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf;SslMode=Required;TreatTinyAsBoolean=true;
```

**Copy the entire value above exactly as shown**

### Step 6: Add Remaining Variables (Optional but Recommended)

Click **"Add Environment Variable"** again for each:

**Variable 2:**
```
Key:   ASPNETCORE_ENVIRONMENT
Value: Production
```

**Variable 3:**
```
Key:   Startup__FailOnSchemaInitError
Value: false
```

**Variable 4:**
```
Key:   Notifications__Scheduler__Enabled
Value: false
```

### Step 7: Save Changes
- Look for a **"Save"** or **"Apply"** button
- Click it
- ⏱️ Render will auto-start redeploy (takes 2-3 minutes)

### Step 8: Watch Deployment
- Go to **Deployments** tab
- Watch the logs scroll by
- ✅ Look for: `Available at your primary URL https://campuseatzz.onrender.com`

### Step 9: Test the Connection
Open a terminal and run:

```bash
curl https://campuseatzz.onrender.com/api/health/db
```

✅ **Success response:**
```
Database connection successful
```

❌ **If you get an error:**
- Double-check the connection string has no typos
- Verify the password: `ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf`
- Check that `SslMode=Required` is included

### Step 10: Test Wallet API
Once the health check passes, test in your Flutter app:

1. Sign in with valid credentials
2. Go to Wallet screen
3. ✅ Should show wallet balance (no error)

---

## 📝 Connection String Reference

If you need to copy it again:

```
Server=roundhouse.proxy.rlwy.net;Port=47842;Database=universitycanteendb;User ID=root;Password=ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf;SslMode=Required;TreatTinyAsBoolean=true;
```

**This is YOUR connection string. Keep it safe!**

---

## 🆘 Troubleshooting

### "Unable to connect" after deployment
- Wait 30 seconds and try again
- Check Render logs for MySQL connection errors
- Verify password is exactly: `ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf`

### Password has special characters?
The password `ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf` has no special characters, so no URL encoding needed.

### Still getting error after health check passes?
- In Flutter app: sign out and sign in again
- Close and reopen Flutter app
- Try again

---

**Once both tests pass, you're done!** ✅
