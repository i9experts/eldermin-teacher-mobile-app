# Changelog

Eldermin Teacher (`version: 1.0.0+2`). One branch per phase; reports in `../eldermin-teacher-app-docs/phase*/`.

## 1.0.0+2 (1.0.0+1 was already uploaded to Google Play; adds the full logo in pull-to-refresh) / 1.0.0+1 (first store release; branch `release/teacher-v1` = design/auth-motion + feat/behaviour-tarbiyah)
- Android release signing never falls back to the debug key: the build fails with a clear message without `android/key.properties`. Unused Firebase (plugin, `firebase_core`, `firebase.json`, iOS plist references) removed; there is no push in v1.
- Student 360 "Recent results" reads the marks collection (`GET /assessments/marks/list?studentId=`) instead of the legacy results the 360 returns.
- Create / edit / approve controls are hidden from view-only custom roles (homework, lesson plans, PTM, syllabus ticks, marks, remarks, quiz grading, student-leave decisions, attendance marking, quick actions) and their screens are refused by the route guard. My leave and My attendance are always visible.
- Suspended school (403 SCHOOL_SUSPENDED): the server message on a full-screen state with Log out. Deactivated staff (401 "no longer active"): signed out with "Your account is no longer active. Please contact your school."
- The in-app account-deletion request is removed (as in the parent app); Help: "To have your data deleted, please contact your school."
- Release hygiene: one logger behind `kDebugMode`, privacy manifest declares Name, no TODO / local URL / test credential in `lib/` (enforced by `test/core/release_hygiene_test.dart`).
- Write actions that the server refuses (403) say "You can't <action>." and never show the server's raw or role-key text. Behaviour: both tab counts show with the screen ("50+" while more pages exist). SCHOOL_SUSPENDED is recognised by the error code first (wording only as a fallback).
- Tarbiyah: create and edit an assessment for a student of my own classes (traits and scale from the school's programme; author edits only; no share switch yet). "My entries" is asked of the server (`mine=true`).

## Hotfix: subject-wise attendance (branch `hotfix/attendance-subject`)
- Attendance now follows the school's mode (`GET /teaching/attendance-settings`, set by an admin on the web). **Daily schools: unchanged** (no subject is requested, read or sent). **Subject-wise schools:** a subject picker (first subject selected, as on the web), the day is read for the chosen subject, and every saved record carries `subject: <name>`, exactly what the web sends. A school with no subjects set up cannot save; a mode or subject-list failure is an error with Retry (the app never guesses the mode). 404/501 on the settings call = daily.
- Known server limits found while verifying (backend, not in this branch): the mode does not persist on the server yet (model-name clash), the `{studentId,date}` unique index blocks a second subject on the same day, and saving the same student+day twice returns 500. See `../eldermin-teacher-app-docs/phase9/ATTENDANCE_SUBJECT_HOTFIX.md`.

## Phase 8 follow-up batch (branch `phase-8-release`)
- Route guards: every route (except splash, login, intro, forgot / reset password) runs `RouteGuard`, which applies the same permission + class-teacher rule as the Classes / More lists; a blocked route (tap, notification target, deep link) shows "Not available for your account" with a way back home.
- Help: 8 bundled teacher FAQs at the top; knowledge-base articles below only when teacher-appropriate ones exist.
- Calendar, circulars and events show the server's specific 403 message (for example "No campus assigned — contact your administrator") instead of "You don't have access".
- iOS: `ITSAppUsesNonExemptEncryption = false`.

## Phase 8 (branch `phase-8-release`): hardening and release readiness
- Tests: permission matrix (7 personas + non-teacher role gate), error-state matrix (every list / read screen x offline, timeouts, 403, 404, 501, 500; writes; sign-in; 401 -> sign-out).
- Fixed: 403 on profile load now says "You don't have access"; lesson-plan detail and report-card remarks no longer misreport a server without the endpoint (404 / 501).
- Removed unused code that requested camera / photo permissions (`app_image_picker`) and the unused `fl_chart` dependency; permission audit documented.
- Android release signing via `android/key.properties` (template committed, real file git-ignored; debug-key fallback with a warning). Firebase / push: none.
- README, CHANGELOG, RELEASE_CHECKLIST; App Store review notes draft (docs repo).

## Phase 7 follow-ups (branch `phase-7-communication`)
- A failed refresh keeps the last data on screen under "Refresh failed - Retry" (all list screens, Home sections, calendar, My leave).
- Calendar rows show one "Grade" ("Grade Grade 5 A" from the backend exam template is collapsed).
- Help hides Staff & HR administration articles (explicit allow / deny rule) and shows a Contact support card when `SUPPORT_EMAIL` / `SUPPORT_URL` are set.
- Student 360 shows the blood group with the allergies when the server sends it (the teacher projection currently removes it).

## Phase 7: communication and self-service
Messages (inbox, chat, new thread, polling), notifications inbox + deep links, student leave review, parent meetings, substitutions, My leave, school calendar + circulars,
events, safeguarding concern (write-only), profile with photo upload, help, about, account-deletion request.

## Phase 6: academic
Lesson plans (create, upload + parse, submit), syllabus coverage and weekly planner, assessments, marks entry, quiz grading, report-card remarks, curriculum, library.

## Phase 5: classroom
Timetable, attendance (hub, mark, history), My students and read-only Student 360, homework (create, submissions, grading, attachments), behaviour and Tarbiyah.

## Phase 4: home
Home dashboard with independent sections (timetable, class card, homework to grade, lesson plans, parent meetings, substitutions, messages), badges, pull-to-refresh deadline.

## Phase 3: onboarding and auth
Intro, login, forgot / reset password, deep links, role gate, session restore, sign-out.

## Phases 0-2: audit, backend identity and shell
Audit of the web and backend, staff-portal backend (identity in the JWT, `/staff-portal/*`), project scaffold, theme, permission service (port of the web role matrix), shell with tabs.
