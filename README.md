# trailify

Offline-first audit trail for Flutter apps with Firestore sync. Capture API calls, push notifications, user actions, auth events, and errors locally, then sync to Cloud Firestore for remote investigation.

**Primary use case**: When a user reports "my message disappeared" or "I didn't receive a notification," query Firestore by their user ID and see exactly what happened, step by step.

## What You'll See in Firestore

A user reports "I sent a message but it disappeared." You query `event_logs` where `userId == "USR_100042"` ordered by `timestamp DESC`:

| Time | Event | Key Detail |
|------|-------|------------|
| 14:35:22 | `notification_received` | Push arrived 3 minutes late |
| 14:32:01 | `api_error` | POST /conversation/message -- 504 gateway timeout, 30s |
| 14:32:01 | `user_action` | Tapped send (message length: 156) |

**Verdict**: The message POST timed out at the gateway (504). The server eventually processed it (notification came through), but the client never got a success response. The "disappeared" message was actually sent.

<details>
<summary>Full Firestore documents for this timeline</summary>

**Document: `event_logs/3f7a91c2-...`** -- user tapped send

```json
{
  "eventId": "3f7a91c2-8b4e-4d1f-a9c3-2e5f8d1b7a04",
  "eventType": "user_action",
  "userId": "USR_100042",
  "userEmail": "jane@example.com",
  "appId": "app_one",
  "deviceId": "d4e5f6a7-...",
  "sessionId": "s9a8b7c6-...",
  "appFlavor": "prod",
  "platform": "ios",
  "appVersion": "1.22.9",
  "firebaseProject": "my-project-prod",
  "timestamp": "2026-04-27T14:32:01.000Z",
  "expiresAt": "2026-07-26T14:32:01.000Z",
  "payload": {
    "action": "send_message",
    "conversationId": 42,
    "textLength": 156
  }
}
```

**Document: `event_logs/8c2d4e6f-...`** -- the API call that followed

```json
{
  "eventId": "8c2d4e6f-1a3b-5c7d-9e0f-2a4b6c8d0e1f",
  "eventType": "api_error",
  "userId": "USR_100042",
  "userEmail": "jane@example.com",
  "appId": "app_one",
  "deviceId": "d4e5f6a7-...",
  "sessionId": "s9a8b7c6-...",
  "appFlavor": "prod",
  "platform": "ios",
  "appVersion": "1.22.9",
  "firebaseProject": "my-project-prod",
  "timestamp": "2026-04-27T14:32:01.450Z",
  "expiresAt": "2026-07-26T14:32:01.450Z",
  "payload": {
    "method": "POST",
    "url": "/api/v1/conversation/message",
    "baseUrl": "https://api.example.com",
    "requestHeaders": {
      "Authorization": "[REDACTED]",
      "Content-Type": "application/json"
    },
    "requestBody": { "text": "Hey, are we still on for Friday?", "conversationId": 42 },
    "statusCode": 504,
    "responseBody": "{\"error\":\"gateway_timeout\"}",
    "durationMs": 30012,
    "error": "DioException [connection timeout]: The request connection took longer than 30000ms",
    "errorType": "connectionTimeout"
  }
}
```

**Document: `event_logs/a1b2c3d4-...`** -- notification that arrived later

```json
{
  "eventId": "a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
  "eventType": "notification_received",
  "userId": "USR_100042",
  "userEmail": "jane@example.com",
  "appId": "app_one",
  "deviceId": "d4e5f6a7-...",
  "sessionId": "s9a8b7c6-...",
  "appFlavor": "prod",
  "platform": "ios",
  "appVersion": "1.22.9",
  "firebaseProject": "my-project-prod",
  "timestamp": "2026-04-27T14:35:22.000Z",
  "expiresAt": "2026-07-26T14:35:22.000Z",
  "payload": {
    "messageId": "0:1682602522%a1b2c3d4f5e6",
    "title": "New message from Tom",
    "body": "Hey, are we still on for Friday?",
    "topic": "/topics/conversation_42",
    "source": "foreground"
  }
}
```

</details>

Documents auto-expire after 90 days via the `expiresAt` TTL field.

### Querying Tips

Use the [Trailify Dashboard](https://trailify.run) to search and filter events visually, or query Firestore directly:

```
userId == "USR_100042"                              → all events for a user
userEmail == "jane@example.com"                     → across apps
deviceId == "d4e5f6a7-..."                          → pre-auth issues
userId == "USR_100042" AND eventType == "api_error" → just API failures
```

## Features

- **Local-first** -- events are stored in Sembast and survive app restarts, offline periods, and crashes
- **Firestore sync** -- batched, idempotent uploads with App Check security
- **Auto HTTP capture** -- Dio interceptor logs every request/response with configurable body capture and scrubbing
- **Push notification tracking** -- received, tapped, subscribed, unsubscribed
- **Auth lifecycle** -- login, logout, token refresh events
- **User action logging** -- explicit events at key points (send message, upload file, etc.)
- **Debug overlay** -- in-app console with filtering, search, and sync status
- **Web dashboard** -- investigate events at [trailify.run](https://trailify.run) or self-deploy (see [dashboard/](dashboard/))
- **Device profiles** -- capture device model, OS, screen size, and track sessions per device
- **Identity backfill** -- pre-auth events are retroactively tagged with the user's identity after login
- **Privacy controls** -- header/body redaction, URL exclusions, configurable body capture

## Getting Started

### Install

```yaml
dependencies:
  trailify:
    git:
      url: https://github.com/ChauCM/trailify.git
```

### Initialize

```dart
await Trailify.instance.init(
  appFlavor: 'parent_prod',
  appVersion: '1.22.9',
  platform: 'ios',
  enableSync: true,
  localOnlyEventTypes: {'screen_viewed'},
);
```

### Set user identity (after login)

```dart
Trailify.instance.setUser(
  userId: 'USR_100042',
  email: 'user@example.com',
  appId: 'my_app',
);
```

### Clear on logout

```dart
Trailify.instance.clearUser();
```

## Logging

### HTTP requests (automatic via Dio)

```dart
dio.interceptors.add(TrailifyDioInterceptor(
  Trailify.instance,
  alwaysCaptureBodyPatterns: [
    RegExp(r'/conversation/message'),
  ],
  excludePatterns: [
    RegExp(r'/health'),
  ],
));
```

### Push notifications

```dart
Trailify.instance.notification(
  eventType: 'notification_received',
  messageId: message.messageId,
  title: message.notification?.title,
  body: message.notification?.body,
  topic: message.from,
  data: message.data,
  source: 'foreground',
);
```

### Auth events

```dart
Trailify.instance.auth(
  eventType: 'auth_login',
  details: {'method': 'keycloak', 'success': true},
);
```

### User actions

```dart
Trailify.instance.userAction(
  action: 'send_message',
  details: {
    'conversationId': 42,
    'textLength': 156,
  },
);
```

### Screen views

```dart
Trailify.instance.screenView(screenName: 'ConversationChatPage');
```

### Errors

```dart
Trailify.instance.error(
  error: e,
  stackTrace: stackTrace,
  context: 'MessageComposerCubit.uploadImages',
);
```

## Debug Overlay

```dart
Trailify.instance.openConsole(context);
```

## Configuration

| Parameter | Type | Default | Description |
|---|---|---|---|
| `appFlavor` | `String` | required | App flavor identifier |
| `appVersion` | `String` | required | App version string |
| `platform` | `String` | required | `'ios'` or `'android'` |
| `enableSync` | `bool` | `true` | Enable Firestore sync |
| `syncInterval` | `Duration` | 2 minutes | How often to push to Firestore |
| `localOnlyEventTypes` | `Set<String>?` | `null` | Event types that stay on device |
| `memoryLimit` | `int` | `500` | Max events in memory for overlay |
| `localRetentionDays` | `int` | `7` | Days to keep events locally |
| `password` | `String?` | `null` | Password to protect the debug overlay |
| `ignorePassword` | `bool` | `true` | Skip password prompt for the overlay |
| `onShare` | `Function(String)?` | `null` | Custom share handler for exported events |
| `deviceInfo` | `Map<String, dynamic>?` | `null` | Device info to store as a device profile |

## Device Profiles

Pass `deviceInfo` during init to capture device details and track sessions:

```dart
import 'package:device_info_plus/device_info_plus.dart';

final deviceInfoPlugin = DeviceInfoPlugin();
final info = await deviceInfoPlugin.iosInfo;

await Trailify.instance.init(
  // ...other params
  deviceInfo: {
    'model': info.model,
    'brand': 'Apple',
    'osVersion': info.systemVersion,
    'isPhysicalDevice': info.isPhysicalDevice,
    'screenWidth': MediaQuery.of(context).size.width,
    'screenHeight': MediaQuery.of(context).size.height,
  },
);
```

Device profiles are stored locally and synced to the `device_profiles` Firestore collection. Each session is appended to a session history on the device profile (up to 20 recent sessions).

## Web Dashboard

Investigate events visually at **[trailify.run](https://trailify.run)** -- no install required.

1. Enable Email/Password auth in your Firebase project
2. Create accounts for team members (Firebase Console > Authentication > Add User)
3. Add `trailify.run` as an authorized domain
4. Deploy the Firestore security rules from [`dashboard/firestore.rules`](dashboard/firestore.rules)
5. Visit [trailify.run](https://trailify.run), paste your Firebase config, sign in

**Dashboard features:**
- **Investigate** -- search by userId, email, or deviceId with filter tabs and full payload detail
- **Session Timeline** -- visual chronological timeline for a single session
- **Device Profiles** -- device info and recent session history
- **Error Dashboard** -- aggregate errors across all users

For self-hosting, see [`dashboard/README.md`](dashboard/README.md).

## Architecture

```
App Code
  │  Trailify.instance.notification(...)
  │  Trailify.instance.userAction(...)
  │  TrailifyDioInterceptor (auto-captures HTTP)
  ▼
Trailify Core
  ├── In-Memory (overlay display)
  └── Sembast DB (persistent)
        │
        ▼
      Sync Engine ──▶ Cloud Firestore
                       ├── event_logs (TTL auto-delete after 90 days)
                       └── device_profiles
                                │
                       ┌────────▼────────┐
                       │ Web Dashboard   │
                       │ trailify.run    │
                       └─────────────────┘
```

## License

MIT License
