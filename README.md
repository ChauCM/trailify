# trailify

Offline-first audit trail for Flutter apps with Firestore sync. Capture API calls, push notifications, user actions, auth events, and errors locally, then sync to Cloud Firestore for remote investigation.

**Primary use case**: When a user reports "my message disappeared" or "I didn't receive a notification," query Firestore by their user ID and see exactly what happened, step by step.

## Features

- **Local-first** -- events are stored in Sembast and survive app restarts, offline periods, and crashes
- **Firestore sync** -- batched, idempotent uploads with App Check security
- **Auto HTTP capture** -- Dio interceptor logs every request/response with configurable body capture and scrubbing
- **Push notification tracking** -- received, tapped, subscribed, unsubscribed
- **Auth lifecycle** -- login, logout, token refresh events
- **User action logging** -- explicit events at key points (send message, upload file, etc.)
- **Debug overlay** -- in-app console with filtering, search, and sync status
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
  context: {
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
```

## License

MIT License
