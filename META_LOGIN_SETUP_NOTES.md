# Meta Login Setup Notes

Verified in Meta App Dashboard for:

- App name: `Pateez Social Login`
- App ID: `929495530098255`
- Dashboard: `https://developers.facebook.com/apps/929495530098255/dashboard/?business_id=3534281856900060`

## Facebook Login

Current saved settings:

- `Client OAuth login`: ON
- `Web OAuth login`: ON
- `Enforce HTTPS`: ON
- `Use Strict Mode for redirect URIs`: ON
- `Embedded browser OAuth login`: ON
- `Login with the JavaScript SDK`: ON
- `Force Web OAuth reauthentication`: OFF
- `Login from devices`: OFF

Valid OAuth redirect URIs:

- `https://pateez.com/auth/meta/callback`
- `https://www.pateez.com/auth/meta/callback`

Allowed Domains for the JavaScript SDK:

- `https://pateez.com/`
- `https://www.pateez.com/`

## Important Note For Mobile

I did not leave a guessed custom mobile callback in the dashboard.

Meta only kept the HTTPS web callback URIs in the saved settings card. If you want a native mobile redirect, it should be configured with the exact app-side scheme / platform setup used by the Flutter app, so it should not be guessed here.

## Instagram

Official Meta docs show Instagram login is for Instagram professional accounts:

- Businesses
- Creators

It is not a general consumer "Sign in with Instagram" flow like Facebook Login.

Useful docs:

- `https://developers.facebook.com/documentation/facebook-login/web`
- `https://developers.facebook.com/documentation/facebook-login/guides/advanced/manual-flow`
- `https://developers.facebook.com/docs/instagram-platform/`
- `https://developers.facebook.com/docs/instagram-platform/instagram-api-with-facebook-login/`

