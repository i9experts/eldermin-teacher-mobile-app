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

## On-device walkthrough (dev only)
`integration_test/phase3_demo_test.dart` drives the auth flows on a simulator against the stub and prints
`SHOT:`/`STUB:` markers for an external script (screenshots, stub control). Deep links are injected via
`DeepLinkService.handleUri` because iOS shows a system "Open in app?" prompt for `simctl openurl` that cannot be
tapped without Accessibility access.

`tool/dev/capture_walkthrough.sh <sim-udid> <out-dir> [test-file]` starts the stub, resets the simulator (uninstall + keychain), runs the
walkthrough and takes a `simctl` screenshot on every `SHOT:` marker. Walkthroughs sign out through the real More-screen UI.

## Home dashboard (Phase 4)
The stub also serves the Home endpoints (timetable, class roster/attendance, assignments + submissions, lesson plans,
PTM, fixtures, threads, unread-count); every response builder in `tool/dev/stub_server.py` cites the backend file:line.
Force a section into a state: `curl -X POST "localhost:3999/__stub/mode?feature=ptm&value=500"` (ok|empty|403|404|500|slow;
features: timetable roster attendance homework lessonplans ptm fixtures threads unread) and
`curl -X POST "localhost:3999/__stub/attendance?count=12"`. `tool/dev/dump_home_fixtures.py` regenerates `test/fixtures/home/`.
Screenshots: `tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase4_home_test.dart`.

Follow-ups: the stub also serves `GET /staff-portal/homework/pending-grading`, `GET /staff-portal/timetable?date=|from&to`
and the PTM list `GET /teaching/ptm?teacherId&from&to` (today's meetings). Extra features for the mode switch: `ptmlist`,
`pendinggrading`, `mytimetable`; `feature=new&value=404` makes both new staff-portal endpoints answer 404 to test the app's
fallbacks (old N+1 homework path, old class-timetable path). `threads` honours `?status=open`.
Walkthrough: `integration_test/phase4_followups_test.dart`.

## Classroom (Phase 5a): Timetable, Attendance, My students / Student 360
The stub serves `GET /students` (30 active Grade 5 A students, two stored as "5"/"a"; every row carries `monthlyTuitionFee` and full
guardian contact data ON PURPOSE to prove the app ignores them), `GET /students/filters/grades-sections`, `GET /students/:id/360`,
`GET /students/:id/attendance/summary`, an in-memory `GET /students/attendance/list` (exact grade/section match, `from`/`to`, class-teacher
scoping) and `POST /students/attendance/bulk` (DTO validation, 403/400 shapes, upsert). Mode features: `students studentsgrades student360
attsummary attendance attbulk`; extra values `409` and `drop` (closes the connection = offline path). Run the stub with
`TZ=Asia/Karachi` (or any zone) to emulate a non-UTC server clock: attendance dates are stored as server-local midnight.
Fixtures: `TZ=UTC python3 tool/dev/dump_classroom_fixtures.py` -> `test/fixtures/classroom/`. Stub tests:
`python3 tool/dev/test_stub_attendance.py`. Walkthrough: `integration_test/phase5a_classroom_test.dart`.

## Homework and Behaviour (Phase 5b)
Routes `/homework[/new|/:id|/:id/submissions|/:id/submissions/:sid/grade]` and `/behaviour[/new|/student/:id]`. The stub serves assignments CRUD,
submissions + grading, `POST /upload/single/:folder` (real multipart parse), `GET /upload/signed-url`, `GET/POST /behaviour/records`,
`PATCH records/:id/resolve` and `GET /behaviour/tarbiyah`; logic and backend file:line citations in `tool/dev/stub_5b.py`. Mode features:
`homework hwwrite hwgrade upload signedurl behaviour behaviourcreate behaviourresolve tarbiyah` with values `400 403 404 413 422 500 drop slow empty`.
Fixtures: `TZ=UTC python3 tool/dev/dump_5b_fixtures.py` -> `test/fixtures/phase5b/`. Tests: `python3 tool/dev/test_stub_5b.py`.
Walkthroughs: `integration_test/phase5b_homework_test.dart`, `phase5b_behaviour_test.dart` (a test `AttachmentPicker` stands in for the native pickers).
Report: `../eldermin-teacher-app-docs/phase5/PHASE5B_REPORT.md`.

## Staging verification (read-only)
`python3 tool/dev/verify_staging.py` (credentials in git-ignored `tool/dev/.env.staging`, see `.env.staging.example`) checks the
keys/types Home parses against a staging server and prints only statuses/types/counts; it hard-blocks the production host and
only sends the login POSTs. Unit tests: `python3 -m unittest discover -s tool/dev -p 'test_*.py'`. Steps and checklist:
`../eldermin-teacher-app-docs/phase4/STAGING_VERIFICATION.md`.

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

## Lesson plans and Syllabus (Phase 6a)
Routes `/lesson-plans[/new|/upload|/:id]`, `/syllabus[/weekly-planner|/:id]`. Stub: `tool/dev/stub_6a.py` (backend file:line citations, UNVERIFIED marks) plus the
`/__stub/mode` features `lessonplans lpcreate lpupdate lpparse syllabus sylone sylmark planner` (special values `aioff badjson googledenied notfound`,
see the docstring). Fixtures: `TZ=UTC python3 tool/dev/dump_6a_fixtures.py` -> `test/fixtures/phase6a/`. Tests: `python3 tool/dev/test_stub_6a.py`.
Walkthrough: `integration_test/phase6a_academic_test.dart` (a test `LessonPlanSourcePicker` stands in for the native document picker). Report:
`eldermin-teacher-app-docs/phase6/PHASE6A_REPORT.md`.

