# Trailify Dashboard

Web dashboard for investigating Trailify audit trail events stored in Firestore.

Search by userId, email, or deviceId and see exactly what happened -- API calls, notifications, user actions, auth events, errors -- step by step.

## Quick Start (Hosted at trailify.run)

No install required. Just configure your Firebase project:

### 1. Enable Email/Password auth

Firebase Console > Authentication > Sign-in method > Email/Password > Enable

### 2. Create dashboard user accounts

Firebase Console > Authentication > Users > Add User

Create accounts for team members who need dashboard access.

### 3. Add trailify.run as authorized domain

Firebase Console > Authentication > Settings > Authorized domains > Add domain > `trailify.run`

### 4. Deploy Firestore security rules

Copy the rules from [`firestore.rules`](firestore.rules) in this directory and deploy them:

```bash
# Option A: Firebase CLI
firebase deploy --only firestore:rules

# Option B: Paste directly into Firebase Console > Firestore > Rules
```

### 5. Deploy composite indexes

```bash
firebase deploy --only firestore:indexes
```

Or let Firestore auto-create them when the dashboard makes its first queries (you'll see error links in the browser console).

### 6. Open the dashboard

Visit **trailify.run**, paste your Firebase config JSON, and sign in.

Your Firebase config is available at: Firebase Console > Project Settings > General > Your apps > Web app.

```json
{
  "apiKey": "AIzaSy...",
  "authDomain": "your-project.firebaseapp.com",
  "projectId": "your-project-id",
  "storageBucket": "your-project.appspot.com",
  "messagingSenderId": "123456789",
  "appId": "1:123456789:web:abc123"
}
```

The config is stored in your browser's localStorage. Your data is read directly from your Firestore by your browser -- trailify.run never sees your data.

---

## Self-Deploy (Your Own Domain)

For teams that want the dashboard on their own infrastructure.

### Prerequisites

- Flutter SDK
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Trailify event data

### Setup

```bash
cd dashboard

# 1. Configure Firebase
cp lib/firebase_options.example.dart lib/firebase_options.dart
# Edit firebase_options.dart with your Firebase config values

# 2. Build and deploy
flutter build web
firebase deploy
```

This deploys Firestore rules, indexes, and the web app in one command.

### Firebase Console Setup

Same as the hosted path (steps 1-2 above), except you don't need to add an external domain -- your own Firebase Hosting domain is already authorized.

---

## Firestore Security Rules

The dashboard requires read access to `event_logs` and `device_profiles`. The provided [`firestore.rules`](firestore.rules) allows:

- **Mobile clients**: create events (with App Check)
- **Dashboard users**: read events (with Firebase Auth)
- **Nobody**: update or delete events

Only users with accounts created by your admin can authenticate, so the invitation itself is the access control.

Optional: add an email domain restriction for extra security (see comments in `firestore.rules`).

## Screens

- **Investigate** -- Search by userId, email, or deviceId. Filter by event type, time range, HTTP status. Click events to see full payload.
- **Session Timeline** -- Visual timeline of all events in a single session.
- **Device Profile** -- Device info, recent sessions, link to events.
- **Errors** -- Aggregate view of recent errors across all users, grouped by error message.
