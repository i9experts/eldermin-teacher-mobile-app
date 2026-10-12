# Changelog

Eldermin Teacher (`version: 0.1.0+1`, nothing released yet). One branch per phase; reports in `../eldermin-teacher-app-docs/phase*/`.

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
