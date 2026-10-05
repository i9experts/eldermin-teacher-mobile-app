# Eldermin Teacher

Flutter + GetX app for school teachers (Phase 3: onboarding & auth). Same architecture and
design system as the Eldermin Parent app; talks to the staff routes of the Eldermin
backend (`/api/v1/auth/*`, `/api/v1/staff-portal/*`, teaching/academic endpoints).

## Run
```
flutter pub get
flutter run                                              # production API
flutter run --dart-define=API_BASE_URL=http://localhost:3000   # local backend
```
`API_BASE_URL` defaults to `https://api.eldermin.com` (the `/api/v1` prefix is added in code).

## Run against the local stub server (no real backend / no production)
`tool/dev/stub_server.py` is a DUMMY Eldermin API (python3, stdlib only) that lives outside `lib/` and
`assets/`, so it can never ship in a release build. Never point a build at production for testing.
```
python3 tool/dev/stub_server.py --port 3999
flutter run --dart-define=API_BASE_URL=http://localhost:3999      # iOS simulator / desktop
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3999       # Android emulator
```
Dummy accounts (password `StubPass123`): `teacher@stub.test` (plain teacher), `classteacher@stub.test`
(class teacher), `principal@stub.test` (role principal -> "use the web portal" screen). A wrong password
gives 401 `Invalid credentials`. Reset token `a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90`
is valid once (re-arm: `curl -X POST localhost:3999/__stub/reset-state`); any other token gives 401
`This reset link is invalid or has expired`. Flip class-teacher live (to see the Attendance/Timetable tab change
on resume or Home pull-to-refresh):
`curl -X POST "localhost:3999/__stub/class-teacher?email=teacher@stub.test&value=true"`.
The header of `stub_server.py` lists everything. (Android debug builds allow cleartext http through
`android/app/src/debug/AndroidManifest.xml`, which is not part of release builds.)

## Deep links
`eldermin-teacher://reset-password?token=<t>` and `eldermin-teacher://login?token=<jwt>&slug=<slug>`.
```
xcrun simctl openurl booted "eldermin-teacher://reset-password?token=a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"
xcrun simctl openurl booted "eldermin-teacher://login?token=stub.classteacher.dummy&slug=demo-school"
adb shell am start -a android.intent.action.VIEW -d "eldermin-teacher://reset-password?token=<t>" com.eldermin.eldermin_teacher_app
```
Verified https app links are not enabled yet; see `../eldermin-teacher-app-docs/DEEP_LINKS.md`.

## Checks
```
flutter analyze
flutter test
```

## Build
```
flutter build apk --debug
flutter build ios --no-codesign --debug
```

## Identity / placeholders (owner must supply before Phase 8)
- Android applicationId `com.eldermin.eldermin_teacher_app`, iOS bundle id `com.eldermin.elderminTeacherApp`.
- **Apple team ID: PLACEHOLDER** - `DEVELOPMENT_TEAM` is intentionally unset in `ios/Runner.xcodeproj`; set it in Xcode (Signing & Capabilities).
- **Firebase: none.** v1 has no push/FCM in the client; no Firebase config or dependencies are present.
- Android release signing: debug-signed placeholder in `android/app/build.gradle.kts` (replace before release).
- Launcher icon / splash are placeholder variants of the Eldermin logomark (`assets/launcher_icon`); regenerate with
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

## Structure
`lib/app/{modules,components,config,common,routes,utils}` and `lib/core/{constants,network,services,theme,models,widgets}`.
Unbuilt screens show `ComingSoonScreen` - never fabricated data.
