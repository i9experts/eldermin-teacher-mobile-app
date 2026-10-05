# Eldermin Teacher

Flutter + GetX app for school teachers (Phase 2: scaffold). Same architecture and
design system as the Eldermin Parent app; talks to the staff routes of the Eldermin
backend (`/api/v1/auth/*`, `/api/v1/staff-portal/*`, teaching/academic endpoints).

## Run
```
flutter pub get
flutter run                                              # production API
flutter run --dart-define=API_BASE_URL=http://localhost:3000   # local backend
```
`API_BASE_URL` defaults to `https://api.eldermin.com` (the `/api/v1` prefix is added in code).

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
