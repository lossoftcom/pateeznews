# Pateez Google Login Setup

## Project
- Google Cloud project name: Pateezcom
- Google Cloud project ID: optimum-lodge-500113-t6

## Current Auth Status
- Google Auth Platform: configured
- App type: External
- Publishing status: Testing
- Test users: pateezcom@gmail.com

## Web Client
- OAuth client ID: 219689188237-jprruujk8knn7noafs2nbvdgnuc67mbe.apps.googleusercontent.com
- Authorized JavaScript origin: https://pateez.com
- Authorized domain: pateez.com
- App home page: https://pateez.com
- Redirect URI: not configured
- Note: For the normal Google Identity Services sign-in button, no API key is needed and no client secret is required on the frontend.

## Android Client
- OAuth client ID: 219689188237-bro0ndlr7s1t0m0c6erhfiag4dfguss7.apps.googleusercontent.com
- Android package name: com.pateez.app
- SHA-1 certificate fingerprint: 2A:99:44:9D:C0:51:C2:7B:CF:09:F9:DF:14:DB:29:B8:6D:CD:CE:DF
- Note: This SHA-1 is from the current debug keystore, which is also the current release signing config in the app.

## iOS Client
- OAuth client ID: 219689188237-nujlogsppna6kq2g3m3vjdlp0gfgvgmj.apps.googleusercontent.com
- Bundle ID: com.pateez.app
- App Store ID: not set
- Team ID: not set

## Flutter Use
- Flutter web: use the Web client ID
- Flutter Android: use the Android client ID
- Flutter iOS: use the iOS client ID

## Copy/Paste Values
```env
GOOGLE_WEB_CLIENT_ID=219689188237-jprruujk8knn7noafs2nbvdgnuc67mbe.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=219689188237-bro0ndlr7s1t0m0c6erhfiag4dfguss7.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=219689188237-nujlogsppna6kq2g3m3vjdlp0gfgvgmj.apps.googleusercontent.com
GOOGLE_ANDROID_PACKAGE_NAME=com.pateez.app
GOOGLE_ANDROID_SHA1=2A:99:44:9D:C0:51:C2:7B:CF:09:F9:DF:14:DB:29:B8:6D:CD:CE:DF
GOOGLE_AUTHORIZED_ORIGIN=https://pateez.com
GOOGLE_AUTHORIZED_DOMAIN=pateez.com
```

## Important Notes
- While the app stays in Testing, only test users can sign in.
- If you later switch to server-side OAuth code flow, add your own callback URL and keep the client secret on the server only.
- If you later change Android signing keys, you must add the new SHA-1 in Google Cloud.
