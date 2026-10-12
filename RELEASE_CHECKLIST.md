# Release checklist (Eldermin Teacher)

Nothing has been submitted anywhere. Work happens on `phase-8-release`; `main` is untouched until the owner approves.

## 0. MANDATORY gate: staging verification (not done yet)
Before ANY store submission or merge to `main`:
1. `python3 tool/dev/verify_staging.py` (read-only; needs git-ignored `tool/dev/.env.staging`) - see `../eldermin-teacher-app-docs/phase4/STAGING_VERIFICATION.md` and the staging checklist in `phase7/PHASE7_SUMMARY.md` section 8.
2. Walk the app on a phone against staging with: a plain teacher, a class teacher, a custom-role teacher, a guardian login and an HR / admin login.
3. Check the data typing question (`STAGING_DATA_TYPE_CHECK.md`) and that the backend branch carrying the privacy / guard fixes is deployed to staging.
Phase 8 verified locally only (unit / widget tests, local stub, local database `eldermin_teacher_verify`); the error handling against real servers, real push-less polling behaviour and real S3 uploads are unverified.

## 1. Build the release candidate
- [ ] Bump `version:` in `pubspec.yaml` (`name+build`).
- [ ] `flutter analyze` clean; `flutter test` green in the default zone and under `TZ=UTC`, `Pacific/Auckland`, `America/Los_Angeles`, `Asia/Karachi`.
- [ ] Decide `--dart-define` values: `API_BASE_URL` (leave the default for production), `SUPPORT_EMAIL`, `SUPPORT_URL`.

## 2. Google Play (closed testing)
- [ ] Create the upload key once (see `android/key.properties.example`), store the keystore and passwords OUTSIDE the repo, copy the example to `android/key.properties`.
- [ ] `flutter build appbundle --release --dart-define=...`; confirm Gradle did NOT print the "signed with the DEBUG key" warning.
- [ ] Play Console: app `com.eldermin.eldermin_teacher_app`, enrol in Play App Signing, upload the bundle to a CLOSED testing track, add tester emails.
- [ ] Data safety form: account info (name, email, user id), user content (messages, homework, safeguarding text, profile photo), data in transit encrypted, deletion by request to the school; no ads, no location, no contacts, no analytics SDK. Declared permissions: INTERNET only (+ ACCESS_NETWORK_STATE from a plugin): `../eldermin-teacher-app-docs/phase8/PERMISSIONS_AUDIT.md`.
- [ ] Provide a demo teacher account for reviewers (see the App Store notes; never commit credentials).
- [ ] Privacy policy URL (required by Play and Apple): OWNER to provide.

## 3. App Store (TestFlight, then review)
- [ ] Apple Developer team: set `DEVELOPMENT_TEAM` in Xcode (Signing & Capabilities); bundle id `com.eldermin.elderminTeacherApp`; automatic signing or a distribution profile.
- [ ] `flutter build ipa --release --dart-define=...` (or Archive in Xcode); upload with Transporter / Xcode.
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` is set in `ios/Runner/Info.plist` (HTTPS + OS keychain only; basis in `../eldermin-teacher-app-docs/phase8/APP_PRIVACY_ANSWERS.md` section 6). OWNER to confirm before submission.
- [ ] App Privacy answers and a Privacy Report on the archive (Xcode > Organizer > Generate Privacy Report).
- [ ] Review notes: `../eldermin-teacher-app-docs/phase8/APP_STORE_REVIEW_NOTES.md` (account creation by the school, deletion REQUEST flow, demo account, permissions).
- [ ] Screenshots, description, age rating, support URL (store assets: owner).

## 4. Pending owner decisions / items
1. Staging verification (section 0).
2. Apple team ID and App Store Connect app record; Play Console app; upload keystore.
3. Support contact (email / page) and privacy policy URL.
4. Account deletion: confirm the turnaround the school will honour and whether Apple accepts the request-based flow for school-provisioned accounts (else the backend must deactivate the account in-app).
5. Backend items from earlier reports still open (circular / event audience filtering, fee-data leaks in calendar and event payloads, safeguarding mass assignment, KB without teacher articles, B5 open questions incl. blood group visibility).
6. Teacher-oriented Help articles (the knowledge base only holds Staff & HR guides; the app hides them).
7. App Privacy / Data safety answers: draft in `../eldermin-teacher-app-docs/phase8/APP_PRIVACY_ANSWERS.md` (UNCERTAIN: safeguarding free text, profile photo, server-side logs and retention).
8. Push notifications (FCM) are NOT built; decide whether v1 ships without.
9. Real-device run (Android and iOS): only simulator runs exist.

### Pending owner decisions (record only, nothing acted on)
* Blood group and `emergencyAction` visibility for teachers (backend hides blood group; the app shows it if sent; `emergencyAction` is not shown).
* Account deletion: the 30-day timeframe (not enforced by the backend) and whether to build in-app deletion, Plan B (`../eldermin-teacher-app-docs/phase8/ACCOUNT_DELETION_PLAN_B.md`).
* Push notifications (FCM) for v1: not built; ship without?
* Support email / page (`SUPPORT_EMAIL`, `SUPPORT_URL`) and the privacy policy URL.
* Apple team ID (`DEVELOPMENT_TEAM`) and the App Store Connect app record.
* Android upload keystore (and Play Console app).
* Demo account (teacher + class teacher, dummy data) for App Review.
