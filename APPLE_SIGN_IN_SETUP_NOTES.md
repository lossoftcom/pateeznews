# Apple Sign in Setup for Pateez

## Created in Apple Developer

- Team ID: `5XK3L8AWCQ`
- Primary App ID: `com.pateez.app`
- Web Services ID: `com.pateez.pateezcom.web`
- Key ID: `LGHLL4A3V6`

## Web configuration

- Domain: `pateez.com`
- Return URL: `https://pateez.com/auth/apple/callback`

## Downloaded private key

- File: `/Users/nasip/Downloads/AuthKey_LGHLL4A3V6.p8`

## Important note

- Apple does not give a permanent API token from the console for Sign in with Apple.
- The `.p8` private key is used to generate the client secret JWT on your server.
- If you need `www`, add `www.pateez.com` separately in the Services ID website URLs list.

## What was enabled

- `Sign in with Apple` was enabled on the primary App ID `com.pateez.app`
- `Sign in with Apple` was configured on the Services ID `com.pateez.pateezcom.web`
- The Services ID was linked to the primary App ID and saved with the website URLs above
