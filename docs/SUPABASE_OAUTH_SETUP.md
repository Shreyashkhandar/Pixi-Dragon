# Supabase OAuth Configuration Guide

## ⚠️ CRITICAL: Why You're Redirecting to localhost:3000

If your app redirects to `http://localhost:3000` instead of `com.pixi.dragon://login-callback`, it means **Supabase is not configured with the correct redirect URLs**.

---

## Step 1: Log Into Supabase Dashboard

1. Go to [https://supabase.com](https://supabase.com)
2. Open your PixiDragon project
3. Navigate to **Authentication** → **Providers** → **Google**

---

## Step 2: Configure Google OAuth Provider

### Location
```
Dashboard → Authentication → Providers → Google (Edit)
```

### Required Settings

#### ✅ OAuth Credentials
- **Client ID**: [Your Google OAuth Client ID from Google Console]
- **Client Secret**: [Your Google OAuth Client Secret]

> You should have already created these in Google Cloud Console with:
> - Authorized JavaScript origins: `https://your-supabase-url.supabase.co`
> - Authorized redirect URIs: `https://your-supabase-url.supabase.co/auth/v1/callback`

---

## Step 3: Configure Site URL & Redirect URLs

### ⚠️ MOST IMPORTANT PART

Navigate to **Project Settings** → **Authentication** (left sidebar)

### A. Site URL
```
For mobile apps using deep links:
com.pixi.dragon://login-callback
```

OR (alternative, safer):
```
https://your-supabase-url.supabase.co
```

**Recommendation**: Set to your Supabase project URL for consistency, but Redirect URLs are what matter for mobile.

### B. Redirect URLs
```
MUST include all of these:

1. com.pixi.dragon://login-callback
2. https://your-supabase-url.supabase.co/auth/v1/callback
3. http://localhost:3000
```

**Note**: List each URL on a new line or comma-separated depending on Supabase UI.

### ✅ CRITICAL: Add Deep Link
Make sure you add this exact URL:
```
com.pixi.dragon://login-callback
```

---

## Step 4: Verify Android Configuration

### Android Deep Link (AndroidManifest.xml)

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>
    <!-- Standard launcher intent filter -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- Deep linking for Supabase OAuth redirect -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="com.pixi.dragon"
            android:host="login-callback" />
    </intent-filter>
</activity>
```

**Key Points:**
- `android:scheme="com.pixi.dragon"` - Must match app scheme
- `android:host="login-callback"` - Must match Supabase redirect
- `android:autoVerify="true"` - Enables direct launch without chooser

---

## Step 5: Verify iOS Configuration

### iOS Deep Link (Info.plist)

```xml
<dict>
    ...
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>com.pixi.dragon</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.pixi.dragon</string>
            </array>
        </dict>
    </array>
    ...
</dict>
```

**Key Points:**
- `com.pixi.dragon` - Must match Android scheme
- This allows iOS to intercept deep links

---

## Step 6: Flutter Code Verification

### ✅ Correct Implementation

```dart
// lib/services/auth_service.dart
static Future<bool> signInWithGoogle() async {
  final redirectUrl = _getRedirectUrl();
  debugPrint('🔵 [OAuth] Initiating with redirect: $redirectUrl');

  return await _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: redirectUrl,  // ✅ MUST match Supabase redirect URLs
    scopes: ['email', 'profile'],
  );
}

static String _getRedirectUrl() {
  return 'com.pixi.dragon://login-callback';  // ✅ Must match deep link
}
```

---

## Step 7: Test & Debug

### Run App with Logging
```bash
flutter run --verbose
```

### Look for These Logs

```
🔵 [OAuth] Initiating Google Sign-In with redirect: com.pixi.dragon://login-callback
✅ [OAuth] OAuth flow initiated successfully: true
🔵 [Auth Event] Event: signedIn | User: user@gmail.com | Session: YES
✅ [SignIn Success] User authenticated: user@gmail.com
⏳ [Leaderboard] Syncing user data to leaderboard...
✅ [Leaderboard] Successfully synced
```

### If You See These Logs, There's a Problem

```
❌ Error: redirects to http://localhost:3000
  → Supabase redirect URLs not configured correctly

❌ [OAuth] Error initiating OAuth: MissingPluginException
  → Deep linking not properly configured on Android/iOS

❌ [Leaderboard:Error] Exception: PostgreSQL error
  → Permissions issue with leaderboard table
```

---

## Troubleshooting

### Problem: "Redirect to localhost:3000"
**Solution:**
1. Open Supabase Dashboard
2. Go to Authentication → Redirect URLs
3. Add: `com.pixi.dragon://login-callback`
4. Save and wait 30 seconds
5. Run app again

### Problem: "App doesn't resume after login"
**Solution:**
1. Verify AndroidManifest.xml has correct intent-filter
2. Verify iOS Info.plist has CFBundleURLSchemes
3. Check that scheme matches exactly: `com.pixi.dragon`

### Problem: "User logs in but leaderboard not created"
**Solution:**
1. Check `leaderboard` table RLS policies allow inserts
2. Check logs for `[Leaderboard:Error]`
3. Verify user_id is correct in Google auth

---

## Final Checklist

- [ ] Supabase Google OAuth credentials configured
- [ ] Site URL set to Supabase project URL
- [ ] Redirect URLs include `com.pixi.dragon://login-callback`
- [ ] AndroidManifest.xml has deep link intent filter
- [ ] iOS Info.plist has CFBundleURLSchemes
- [ ] Flutter code uses correct `redirectTo` parameter
- [ ] `leaderboard` table has correct RLS policies
- [ ] Tested on Android device
- [ ] Tested on iOS device (if available)

---

## Reference URLs

- Supabase OAuth Docs: https://supabase.com/docs/guides/auth/oauth-flow
- Deep Linking (Android): https://developer.android.com/training/app-links
- URL Schemes (iOS): https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
