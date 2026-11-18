# Cardio Quest

Cardio Quest is a Flutter/Flame endless runner controlled by a real
gym treadmill, indoor bike, cross trainer, or rower over Bluetooth FTMS.
Machine speed drives world speed, incline shapes the trail, and cadence,
distance, and heart rate feed the live HUD.

The BLE integration is intentionally read-only. Cardio Quest never requests
control of the machine and never writes speed, resistance, or incline.

The app turns machine telemetry into game movement without taking over the
equipment. A touch simulator makes the game usable without Bluetooth hardware.
An optional React dashboard presents workout history and player progress.

## Architecture

- `lib/services/machine_service.dart` isolates FTMS plugin types and converts
  machine data into immutable metrics. Health-data merging and heart-rate zones
  sit alongside it. The current `WearableService` is a no-op adapter that reports
  unavailable, not a working HealthKit or Health Connect integration.
- `lib/game/` contains the Flame game loop, procedural scene components, and
  multiplayer race rendering. Flutter screens own menus, settings, and summaries.
- `lib/services/` also owns progression, achievements, challenges, cosmetics,
  synthesized sound, voice coaching, and queued fitness exports.
- `lib/server/` is a standalone Dart WebSocket relay for room state and races.
- `web/` is a separate React dashboard. It uses generated sample data unless
  `VITE_CARDIO_API_URL` points to an endpoint returning its documented JSON shape.

## Notable engineering decisions

1. BLE access is read-only and confined to `MachineService`, so gameplay and
   tests use normalized metrics without native device objects.
2. The game exponentially smooths speed and integrates session distance itself,
   rather than scoring from a machine's cumulative odometer.
3. The health-data merger keeps motion freshness separate from wearable updates,
   so a new heart-rate sample cannot make stale machine motion look current.
4. Multiplayer separates relay state from Flame rendering, with reconnect
   backoff in the client and temporary retention of disconnected racers.
5. Fitness export persists a retry queue and asynchronous upload identifiers,
   stores OAuth tokens through secure storage, and checks OAuth callback state.
6. The dashboard's seeded sample-data generator allows local development without
   a configured endpoint or private workout dataset.

## Stack

Flutter and Dart, Flame, `flutter_ftms`, SoLoud audio, platform text-to-speech,
secure storage, HTTP, Shelf, and WebSocket channels power the app and relay.
The dashboard uses React 18, TypeScript, Vite, Tailwind CSS 3, React Router,
Recharts, and Lucide icons. Dependency versions are recorded in the lockfiles.

## Highlights

- FTMS scan, connect, reconnect-safe state, and merged data notifications
- Treadmill and indoor-bike field mapping through `flutter_ftms`
- Touch simulator with live speed and incline sliders
- Walk, jog, and sprint animation states at 0–3, 3–8, and 8+ km/h
- Five visual depth layers: sky, far mountains, near mountains, trees, terrain,
  plus fast foreground foliage
- Speed-reactive palette, procedural hills, runner animation, dust, landing
  bursts, speed lines, coin sparkles, glows, and impact flashes
- Coins, obstacles, magnet, shield, and 2× coin power-ups
- Stability combo that rewards holding a consistent real-world pace
- Speed gauge, pace, distance, heart-rate zone, coins, combo, and active
  power-up HUD
- Pause, safe disconnect behavior, completion state, and workout summary
- Live races for 2–8 players with private rooms, quick matchmaking,
  interpolated opponent ghosts, standings, preset chat, and spectator mode
- Procedural vector rendering with no external art or network-loaded assets

## Requirements

- Flutter with Dart 3.8 or newer. Local validation used Flutter 3.38.5
  and Dart 3.10.4 on Linux
- Dart 3.8 or newer
- Android 8.0+ or iOS 14+ as configured in the native projects
- Android SDK for Android builds, or macOS with Xcode and CocoaPods for iOS builds
- A BLE cardio machine exposing Fitness Machine Service `0x1826`
- Treadmills typically publish Treadmill Data on `0x2ACD`; `flutter_ftms`
  automatically selects the appropriate data characteristic for other machine
  types, including Indoor Bike Data

## Run

```bash
flutter pub get
flutter run
```

For a no-hardware demo, choose **Play with touch controls**. In the game,
adjust the speed and incline sliders in the lower-right corner.

On a physical machine:

1. Wake the machine console and close any other app connected to it.
2. Tap **Scan for machines** and allow the Bluetooth permission prompt.
3. Select the FTMS machine.
4. Start walking or pedaling. Tap anywhere in the scenery to jump.

Android BLE permissions are declared for both Android 12+ and legacy Android.
iOS Bluetooth usage descriptions are included in `Info.plist`.

## Multiplayer relay

Start the lightweight relay as a separate Dart process:

```bash
dart run lib/server/main.dart --host 127.0.0.1 --port 8080
```

The WebSocket endpoint is `/ws`; `/health` provides an HTTP health check.
The host and port can also be set with `CARDIO_QUEST_RELAY_HOST` and `PORT`.
The server's built-in host default is all interfaces, so the local example
explicitly binds loopback. The relay has no account authentication and trusts
client-reported telemetry. Do not expose it as a hardened public service without
your own access controls and abuse protection. Request logs go to the process
console, not an external logging destination.

The app defaults to `ws://localhost:8080/ws`. Point physical devices or release
builds at the deployed relay at compile time:

```bash
flutter run \
  --dart-define=MULTIPLAYER_SERVER_URL=wss://race.example.com/ws
```

Use TLS (`wss://`) for production. In the app, choose **Multiplayer Race**,
create a private four-character room, join by code, or use Quick Match. The
host selects the distance and can start once at least two connected racers are
ready. If the relay cannot be reached, the lobby reports that multiplayer is
offline without affecting the single-player game.

## Strava and Garmin workout export

Cardio Quest can automatically upload completed workouts to every connected
fitness account. Tokens are kept in iOS Keychain or encrypted Android storage.
Upload files and retry history are stored in the app-support directory. Failed
uploads retry when the app starts or resumes, every five minutes while open,
after another workout, and from **Settings → Sync now**.

Copy the example build configuration, keep the local copy out of version
control, and fill in credentials:

```bash
cp config/fitness.example.json config/fitness.local.json
flutter run --dart-define-from-file=config/fitness.local.json
```

Register these exact mobile redirect URIs with each provider:

```text
cardioquest://cardioquest.app/oauth/strava
cardioquest://cardioquest.app/oauth/garmin
```

They are registered in `AndroidManifest.xml` and `Info.plist`. If you change
the scheme, update both native files and `FitnessApiConfig`.

For Strava:

1. Create an API application in the
   [Strava API settings](https://www.strava.com/settings/api).
2. Set the authorization callback domain to `cardioquest.app`, then put the
   client ID and secret in `fitness.local.json`.
3. Request `read` and `activity:write`; Cardio Quest verifies upload access.
4. For more than the development athlete capacity, complete Strava's app
   review and follow its current brand guidelines.

Strava upload processing is asynchronous. Cardio Quest saves the returned
upload ID and polls it, so an interrupted status check never causes a duplicate
activity. It also observes Strava rate-limit headers and keeps rate-limited
workouts queued until the next reset. See Strava's
[authentication](https://developers.strava.com/docs/authentication/),
[upload](https://developers.strava.com/docs/uploads/), and
[rate-limit](https://developers.strava.com/docs/rate-limits/) documentation.

Garmin's public [Health API](https://developer.garmin.com/gc-developer-program/health-api/)
and [Activity API](https://developer.garmin.com/gc-developer-program/activity-api/)
deliver data synced *from Garmin devices* to approved partner systems; they do
not provide a public consumer endpoint for uploading a workout generated by a
phone. Connect IQ similarly records FIT activities on Garmin hardware. To
avoid relying on unofficial Garmin Connect endpoints, Cardio Quest's Garmin
adapter accepts the OAuth 2.0, profile, upload, and optional upload-status URLs
supplied to approved Garmin Connect Developer Program partners. Add those
issued URLs to `fitness.local.json`; until then Garmin is shown as **Setup
required**. Set `GARMIN_UPLOAD_FORMAT` to `fit` (default) or `tcx` according to
the partner contract, and adjust `GARMIN_UPLOAD_FILE_FIELD` if Garmin assigns a
different multipart field name. Use `{id}` in `GARMIN_UPLOAD_STATUS_URL` where
the returned upload ID belongs.

Embedding a client secret in a distributed mobile binary cannot make it truly
secret. For a public production app, proxy OAuth token exchange and refresh
through a backend that owns the provider secrets. Direct exchange in this
project is intended for development, evaluation, and single-user builds.

## Gameplay

| Real speed | Runner state | Presentation |
| --- | --- | --- |
| 0–3 km/h | Walk | relaxed stride, calm blue-green palette |
| 3–8 km/h | Jog | faster stride, denser trail motion |
| 8+ km/h | Sprint | forward lean, aura, speed lines, intense palette |

Incline is smoothed into the procedural terrain slope so noisy machine packets
do not cause visible snapping. A machine-data timeout eases the runner to a
safe stop instead of continuing with stale speed.

Coins are worth 1, or 2 while the 2× power-up is active. The score shown in the
summary follows:

```text
score = distance in meters × current combo × coins
```

The combo grows in 0.5× steps while pace stays within a narrow stability band.
An unshielded obstacle hit breaks the combo and briefly slows the scene.

## State model

The app uses the requested session states:

```text
DISCONNECTED → CONNECTING → CONNECTED/IDLE → RUNNING
                                            ↕
                                          PAUSED
                                            ↓
                                         COMPLETE
```

They are represented by `WorkoutState` in
`lib/models/machine_models.dart`.

## Project structure

```text
lib/
├── main.dart
├── core/
│   ├── constants.dart
│   ├── palette.dart
│   └── theme.dart
├── models/
│   ├── machine_models.dart
│   └── multiplayer_models.dart
├── services/
│   ├── machine_service.dart
│   └── multiplayer_service.dart
├── server/
│   ├── main.dart
│   └── relay_server.dart
├── game/
│   ├── cardio_quest_game.dart
│   ├── multiplayer_race_game.dart
│   └── components/
│       ├── coins.dart
│       ├── hud.dart
│       ├── obstacles.dart
│       ├── parallax_background.dart
│       ├── particles.dart
│       ├── player.dart
│       └── terrain.dart
└── screens/
    ├── game_screen.dart
    ├── menu_screen.dart
    ├── multiplayer_lobby.dart
    ├── multiplayer_race_screen.dart
    └── summary_screen.dart
```

`MachineService` owns all plugin types, BLE subscriptions, device handles, and
unit conversion. The rest of the app only consumes immutable
`MachineMetrics`, keeping the game testable and independent of BLE details.

## FTMS data conversion

`flutter_ftms` supplies raw integer values and a factor for each parameter.
Cardio Quest converts and normalizes:

- instantaneous speed → km/h
- inclination → percent
- instantaneous cadence or step rate → rpm / steps per minute
- total distance → meters
- heart rate → bpm

If total distance is absent, the service estimates it by integrating speed.
Game-session distance is independently integrated from the smoothed live pace,
so a machine's lifetime odometer never leaks into the score.

## Production notes

- Replace Android's debug signing configuration before Play Store release.
- Set an Apple development team and final bundle identifier in Xcode.
- Test with the target machine model: FTMS implementations vary, and some
  machines omit optional incline, cadence, distance, or heart-rate fields.
- The bundled [research notes](01-master-research.md) remain available for
  protocol and product background.

## Web dashboard

Use Node.js 20.19+ or 22.12+ for the locked Vite dependencies.

```bash
cd web
npm ci
npm run dev
```

The dashboard is not the Flutter game's web target. See
[`web/README.md`](web/README.md) for routes and endpoint configuration.
No dashboard endpoint is contacted when `VITE_CARDIO_API_URL` is unset.

## Tests and validation limits

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test --no-pub --reporter expanded
```

For the separate dashboard:

```bash
cd web
npm ci --ignore-scripts --no-audit --no-fund
npm run typecheck
npm run build
```

On Linux with Flutter 3.38.5, all 28 existing Flutter tests passed and the
analyzer reported no issues. These include loopback multiplayer relay/client
tests, Flame/widget smoke tests, model and progression checks, health-data
merging, and mocked export/retry tests. Dashboard typechecking and the production
build passed with Node.js 22.22.1 and npm 10.9.4.

No physical BLE equipment, provider account, mobile release build, hosted build
runner, or signing/upload flow was exercised. The wearable adapter remains
unavailable in this source snapshot. Research notes are retained as background,
not a current compatibility or pricing guarantee.

`codemagic.yaml` retains the unsigned iOS release build and artifact checks with
no notification recipient or publishing step. It does not sign or upload the app.
Use your own Apple team, provisioning, and signing tools for installation or
distribution, and keep signing credentials out of version control. The Android
release configuration currently uses debug signing and must be replaced before
store distribution.
