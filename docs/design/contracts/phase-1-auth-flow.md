# Phase 1 — Authentication Flow Contract

## Overview

HealthOS uses **Supabase Auth** as the identity provider. The primary auth method is **Sign In with Apple**. During development (before the Apple Developer account is configured), **email/password** is used as a fallback.

---

## Auth Flow: Sign In with Apple (Production)

```
1. User taps "Sign In with Apple" in the iOS app
2. iOS presents ASAuthorizationController
3. Apple returns an identity token (JWT) + authorization code
4. iOS sends the identity token to Supabase Auth:
     supabase.auth.signInWithIdToken(
         provider: .apple,
         idToken: identityToken
     )
5. Supabase validates the token with Apple, creates/finds the user
6. Supabase returns a session (access_token + refresh_token)
7. iOS stores the session via Supabase Swift SDK (automatic)
8. The database trigger `on_auth_user_created` auto-creates a profiles row
9. All subsequent API calls include the JWT → RLS enforces row-level access
```

## Auth Flow: Email/Password (Dev Fallback)

```
1. User enters email + password on a dev-only login screen
2. iOS calls supabase.auth.signUp(email:, password:) or signIn(email:, password:)
3. Supabase returns a session
4. Same profile trigger + RLS behavior as above
```

The dev fallback screen is **only shown in DEBUG builds**. It is gated behind:
```swift
#if DEBUG
DevLoginView()
#endif
```

---

## Session Management

| Concern | Implementation |
|---|---|
| Session persistence | Supabase Swift SDK stores session in Keychain automatically |
| Token refresh | Supabase Swift SDK handles refresh automatically |
| Session expiry | Default 1-hour access token, 1-week refresh token (Supabase defaults) |
| Logout | `supabase.auth.signOut()` — clears Keychain, returns to login screen |
| Auth state observation | Use `supabase.auth.onAuthStateChange` to reactively update UI |

---

## Supabase Configuration Required

The iOS app needs two values to connect to Supabase:

| Key | Source | Storage |
|---|---|---|
| `SUPABASE_URL` | Supabase dashboard → Project Settings → API | iOS `.xcconfig` file (not committed) |
| `SUPABASE_ANON_KEY` | Supabase dashboard → Project Settings → API | iOS `.xcconfig` file (not committed) |

These are injected via an `.xcconfig` file and read from `Info.plist` at runtime:

```swift
// Config.swift
enum Config {
    static let supabaseURL = URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as! String)!
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as! String
}
```

A template file `HealthOS/Config.xcconfig.template` is committed with placeholder values.

---

## RLS Contract

All tables use `auth.uid()` for row-level security. The JWT from Supabase Auth carries the user's UUID, which PostgreSQL extracts via `auth.uid()`. This means:

- Every query automatically filters to the current user's data
- No server-side middleware needed for access control
- The iOS app never needs to pass `user_id` in queries — RLS handles it

---

## Dependencies

| What | Needed By |
|---|---|
| Supabase project created on supabase.com | iOS workstream (for URL + anon key) |
| Apple Developer account + App ID configured | Production Sign In with Apple |
| Supabase Auth → Apple provider enabled | Production Sign In with Apple |
