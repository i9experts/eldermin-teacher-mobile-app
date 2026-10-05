/// Teacher-app endpoints only (staff routes, never `parent-portal`).
///
/// Paths verified against eldermin-backend controllers - see
/// eldermin-teacher-app-docs/parts/B1_endpoints_1_11.md, B2_..., and
/// phase1/PHASE1_REPORT.md. Override the host with
/// `--dart-define=API_BASE_URL=...` for local backend testing.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.eldermin.com',
  );

  static const String apiPrefix = '$baseUrl/api/v1';

  // Timeouts (ms)
  static const int connectTimeout = 20000;
  static const int receiveTimeout = 20000;
  static const int sendTimeout = 30000;

  // ── Auth ─────────────────────────────────────────────────────
  static const String login = '$apiPrefix/auth/login';
  static const String forgotPassword = '$apiPrefix/auth/forgot-password';
  static const String resetPassword = '$apiPrefix/auth/reset-password';
  static const String authMe = '$apiPrefix/auth/me';
  static const String authMeAvatar = '$apiPrefix/auth/me/avatar'; // multipart `avatar`
  static const String logout = '$apiPrefix/auth/logout';

  /// Used by the network layer to recognise "invalid credentials" 401s.
  static bool isLoginUrl(String url) => url.contains('/auth/login');

  /// Unauthenticated auth endpoints. A 401 from any of these (bad
  /// credentials, invalid/expired reset token) is NEVER a session expiry.
  static bool isPublicAuthUrl(String url) =>
      url.contains('/auth/login') ||
      url.contains('/auth/forgot-password') ||
      url.contains('/auth/reset-password');

  // ── Staff portal (Phase 1) ───────────────────────────────────
  static const String staffPortal = '$apiPrefix/staff-portal';
  static const String staffMe = '$staffPortal/me';

  static const String notifications = '$staffPortal/notifications'; // ?limit&before&unread
  static const String notificationsUnreadCount = '$staffPortal/notifications/unread-count';
  static String notificationRead(String id) => '$staffPortal/notifications/$id/read';
  static const String notificationsReadAll = '$staffPortal/notifications/read-all';

  static const String threads = '$staffPortal/threads'; // GET ?status, POST start
  static String threadMessages(String id) => '$staffPortal/threads/$id/messages';
  static String threadRead(String id) => '$staffPortal/threads/$id/read';
  static String threadClose(String id) => '$staffPortal/threads/$id/close'; // PATCH
  static String studentGuardians(String studentId) => '$staffPortal/students/$studentId/guardians';

  static const String studentLeaves = '$staffPortal/student-leaves'; // ?status&limit
  static String studentLeave(String id) => '$staffPortal/student-leaves/$id'; // PATCH

  static const String deviceToken = '$staffPortal/device-token'; // POST/DELETE (stored only, no push in v1)
  static const String accountDeleteRequest = '$staffPortal/account/delete-request';

  // ── Teaching: timetable / dashboard ──────────────────────────
  static const String teachingDashboard = '$apiPrefix/teaching/dashboard';
  static String timetableForTeacher(String staffId) => '$apiPrefix/teaching/timetable/teacher/$staffId';
  static const String timetable = '$apiPrefix/teaching/timetable';
  static const String periodTemplates = '$apiPrefix/teaching/period-templates';

  // ── Student attendance (class teacher) ───────────────────────
  static const String attendanceList = '$apiPrefix/students/attendance/list'; // use from/to (not `date`)
  static const String attendanceMark = '$apiPrefix/students/attendance';
  static const String attendanceBulk = '$apiPrefix/students/attendance/bulk';
  static String attendanceSummary(String studentId) => '$apiPrefix/students/$studentId/attendance/summary';

  // ── Homework (assignments) ───────────────────────────────────
  static const String assignments = '$apiPrefix/teaching/assignments';
  static String assignment(String id) => '$apiPrefix/teaching/assignments/$id';
  static String assignmentSubmissions(String id) => '$apiPrefix/teaching/assignments/$id/submissions';
  static String assignmentSubmission(String id, String submissionId) =>
      '$apiPrefix/teaching/assignments/$id/submissions/$submissionId'; // PATCH grade

  // ── Lesson plans ─────────────────────────────────────────────
  static const String lessonPlans = '$apiPrefix/teaching/lesson-plans';
  static String lessonPlan(String id) => '$apiPrefix/teaching/lesson-plans/$id';
  static const String lessonPlanParseUpload = '$apiPrefix/teaching/lesson-plans/parse-upload';

  // ── Syllabus ─────────────────────────────────────────────────
  static const String syllabus = '$apiPrefix/syllabus';
  static String syllabusById(String id) => '$apiPrefix/syllabus/$id';
  static const String syllabusWeeklyPlanner = '$apiPrefix/syllabus/weekly-planner'; // ?teacherId=<staffId>
  static String syllabusMarkTopic(String id) => '$apiPrefix/syllabus/$id/mark-topic';
  static String syllabusMarkSubTopic(String id) => '$apiPrefix/syllabus/$id/mark-sub-topic';

  // ── Assessments & marks ──────────────────────────────────────
  static const String assessments = '$apiPrefix/assessments';
  static String assessment(String id) => '$apiPrefix/assessments/$id';
  static const String marksList = '$apiPrefix/assessments/marks/list';
  static const String marksSummary = '$apiPrefix/assessments/marks/summary';
  static const String marksBulk = '$apiPrefix/assessments/marks/bulk';
  static const String reportCards = '$apiPrefix/assessments/report-cards';
  static String reportCardRemarks(String id) => '$apiPrefix/assessments/report-cards/$id/remarks';
  static const String quizAttempts = '$apiPrefix/assessments/quiz-attempts';
  static String quizAttempt(String id) => '$apiPrefix/assessments/quiz-attempts/$id';
  static String quizAttemptGrade(String id) => '$apiPrefix/assessments/quiz-attempts/$id/grade';

  // ── Behaviour (canonical store: BehaviourRecord, per Phase 1) ─
  static const String behaviourRecords = '$apiPrefix/behaviour/records';
  static String behaviourRecord(String id) => '$apiPrefix/behaviour/records/$id';
  static const String behaviourTarbiyah = '$apiPrefix/behaviour/tarbiyah';
  static String behaviourStudentProfile(String studentId) => '$apiPrefix/behaviour/students/$studentId/profile';

  // ── Students ─────────────────────────────────────────────────
  static const String students = '$apiPrefix/students';
  static String student(String id) => '$apiPrefix/students/$id';
  static String student360(String id) => '$apiPrefix/students/$id/360';
  static const String studentGradesSections = '$apiPrefix/students/filters/grades-sections';

  // ── PTM ──────────────────────────────────────────────────────
  static const String ptm = '$apiPrefix/teaching/ptm';
  static const String ptmUpcomingMine = '$apiPrefix/teaching/ptm/upcoming/mine'; // ?teacherId=<staffId>
  static String ptmById(String id) => '$apiPrefix/teaching/ptm/$id';
  static String ptmConfirm(String id) => '$apiPrefix/teaching/ptm/$id/confirm';
  static String ptmReschedule(String id) => '$apiPrefix/teaching/ptm/$id/reschedule';
  static String ptmOutcome(String id) => '$apiPrefix/teaching/ptm/$id/outcome';
  static String ptmCancel(String id) => '$apiPrefix/teaching/ptm/$id/cancel';
  static String ptmActionItem(String id, String itemId) => '$apiPrefix/teaching/ptm/$id/action-items/$itemId';

  // ── Fixtures / substitutions ─────────────────────────────────
  static const String fixtures = '$apiPrefix/teaching/fixtures'; // ?teacherId&status&from&to
  static String fixtureComplete(String id) => '$apiPrefix/teaching/fixtures/$id/complete'; // PATCH

  // ── My Leave (staff self-service) ────────────────────────────
  static const String leaveSelfBalance = '$apiPrefix/hr/leave/self/balance';
  static const String leaveSelfHistory = '$apiPrefix/hr/leave/self/history';
  static const String leaveSelfApply = '$apiPrefix/hr/leave/self'; // POST

  // ── Calendar / events / circulars ────────────────────────────
  static const String calendarEvents = '$apiPrefix/school-calendar/events'; // ?from&to
  static const String circulars = '$apiPrefix/school-calendar/circulars'; // pass status=published
  static String circular(String id) => '$apiPrefix/school-calendar/circulars/$id';
  static String circularAcknowledge(String id) => '$apiPrefix/school-calendar/circulars/$id/acknowledge';

  // ── Academics (curriculum / library) ─────────────────────────
  static const String curriculum = '$apiPrefix/academics/curriculum';
  static const String subjects = '$apiPrefix/academics/subjects';
  static const String libraryBooks = '$apiPrefix/academics/library/books';
  static const String librarySearch = '$apiPrefix/academics/library/search';

  // ── Early Years (hidden in v1, constants kept for later) ─────
  static const String eceChildren = '$apiPrefix/ece/children';
  static const String eceDashboard = '$apiPrefix/ece/dashboard';
  static const String eceObservations = '$apiPrefix/ece/observations';

  // ── Safeguarding / uploads / knowledge base ──────────────────
  static const String safeguarding = '$apiPrefix/compliance/safeguarding';
  static String uploadSingle(String folder) => '$apiPrefix/upload/single/$folder'; // multipart `file`
  static const String uploadSignedUrl = '$apiPrefix/upload/signed-url';
  static const String kbArticles = '$apiPrefix/kb/articles';
  static const String kbSearch = '$apiPrefix/kb/search';
}
