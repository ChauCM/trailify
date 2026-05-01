# Trailify Dashboard -- Remaining Plan

## Status

All coding is complete. The dashboard is in `dashboard/` and builds successfully.

### Completed

- [x] Scaffold Flutter Web project with deps (firebase_core, cloud_firestore, firebase_auth, go_router, google_fonts)
- [x] Runtime Firebase config: ConnectProjectScreen + localStorage persistence + Firebase.initializeApp at runtime
- [x] Auth: email/password sign-in screen + AuthGate redirect wrapper
- [x] FirestoreQueryService: event_logs + device_profiles reads with cursor pagination
- [x] User Investigation Screen: search bar, filter tabs (All/API/Notif/Actions/Auth/Errors), event list, detail panel
- [x] Session Timeline Screen: vertical timeline for a single session
- [x] Device Profile Screen: device info + link to events
- [x] Error Dashboard Screen: aggregate errors across users
- [x] Firestore rules + indexes: firestore.rules, firestore.indexes.json
- [x] README: hosted quick-start + self-deploy instructions

### Remaining

- [ ] **Infra: register trailify.run, create Firebase project for hosting, deploy, connect domain**

---

## Remaining Steps: Deploy to trailify.run

### 1. Register domain

Purchase `trailify.run` from a domain registrar (Namecheap, Cloudflare, Google Domains, etc.)

### 2. Create a Firebase project for hosting

This is a separate Firebase project used only for hosting the dashboard static files. It does NOT hold any Trailify event data -- each user's data stays in their own Firebase project.

```bash
# Create project in Firebase Console
# Name: trailify-dashboard (or similar)
# No need to enable Firestore or Auth on this project
```

### 3. Initialize Firebase Hosting locally

```bash
cd dashboard
firebase login
firebase init hosting
# Select the trailify-dashboard project
# Public directory: build/web
# Single-page app: Yes
# Don't overwrite index.html
```

### 4. Build and deploy

```bash
flutter build web
firebase deploy --only hosting
```

### 5. Connect custom domain

Firebase Console > Hosting > Add custom domain > `trailify.run`

Follow the DNS verification steps:
1. Add a TXT record to verify domain ownership
2. Add A records pointing to Firebase Hosting IPs
3. Wait for SSL certificate provisioning (usually minutes, can take up to 24h)

### 6. Verify

Visit `https://trailify.run` -- should show the "Connect Project" screen.

---

## Architecture Summary

```
User's browser at trailify.run
  │
  ├── Static files served from Firebase Hosting (our project)
  │
  ├── Firebase config entered at runtime (stored in localStorage)
  │
  └── Reads event_logs directly from USER'S Firestore (not ours)
      └── Authenticated via Firebase Auth on USER'S project
```

We host static files. We never see user data.
