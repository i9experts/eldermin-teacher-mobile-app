/// Named routes. Parameterised routes use `:name` placeholders; build a
/// concrete location with the `*Of` helpers and read the values with
/// `Get.parameters['id']` in the screen/controller.
///
/// Root screens (splash / login / unsupported-role / home shell) are
/// chosen by `_AuthGate` in main.dart based on `AuthController.status`;
/// the entries here for them exist so every route in the Part D.3 list
/// has a stable name.
abstract class Routes {
  Routes._();

  // Auth / bootstrap
  static const splash = '/splash';
  static const login = '/login';
  static const unsupportedRole = '/unsupported-role';

  // Home shell + its tabs
  static const home = '/home';
  static const homeClasses = '/home/classes';
  static const homeAttendance = '/home/attendance';
  static const homeMessages = '/home/messages';
  static const homeMore = '/home/more';

  static const intro = '/intro';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const messages = '/messages';
  static const messageNew = '/messages/new';
  static const messageThread = '/messages/:threadId';
  static const notifications = '/notifications';
  static const timetable = '/timetable';
  static const attendance = '/attendance';
  static const attendanceMark = '/attendance/mark';
  static const attendanceHistory = '/attendance/history';
  static const students = '/students';
  static const studentDetail = '/students/:id';
  static const homework = '/homework';
  static const homeworkNew = '/homework/new';
  static const homeworkDetail = '/homework/:id';
  static const homeworkSubmissions = '/homework/:id/submissions';
  static const homeworkGrade = '/homework/:id/submissions/:sid/grade';
  static const lessonPlans = '/lesson-plans';
  static const lessonPlanNew = '/lesson-plans/new';
  static const lessonPlanUpload = '/lesson-plans/upload';
  static const lessonPlanDetail = '/lesson-plans/:id';
  static const syllabus = '/syllabus';
  static const syllabusWeeklyPlanner = '/syllabus/weekly-planner';
  static const syllabusDetail = '/syllabus/:id';
  static const assessments = '/assessments';
  static const assessmentReportRemarks = '/assessments/report-remarks';
  static const quizAttempts = '/assessments/quiz-attempts';
  static const quizAttemptDetail = '/assessments/quiz-attempts/:id';
  static const assessmentMarks = '/assessments/:id/marks';
  static const assessmentDetail = '/assessments/:id';
  static const behaviour = '/behaviour';
  static const behaviourNew = '/behaviour/new';
  static const behaviourStudent = '/behaviour/student/:id';
  static const ptm = '/ptm';
  static const ptmNew = '/ptm/new';
  static const ptmDetail = '/ptm/:id';
  static const fixtures = '/fixtures';
  static const fixtureDetail = '/fixtures/:id';
  static const leave = '/leave';
  static const leaveApply = '/leave/apply';
  static const studentLeaves = '/student-leaves';
  static const studentLeaveDetail = '/student-leaves/:id';
  static const calendar = '/calendar';
  static const events = '/events';
  static const eventDetail = '/events/:id';
  static const curriculum = '/curriculum';
  static const curriculumDetail = '/curriculum/:id';
  static const library = '/library';
  static const earlyYears = '/early-years';
  static const safeguarding = '/safeguarding';
  static const profile = '/profile';
  static const help = '/help';
  static const about = '/about';
  static const deleteAccount = '/delete-account';

  // Helpers for parameterised routes
  static String messageThreadOf(String threadId) => '/messages/$threadId';
  static String studentDetailOf(String id) => '/students/$id';
  static String homeworkDetailOf(String id) => '/homework/$id';
  static String homeworkSubmissionsOf(String id) => '/homework/$id/submissions';
  static String homeworkGradeOf(String id, String sid) => '/homework/$id/submissions/$sid/grade';
  static String lessonPlanDetailOf(String id) => '/lesson-plans/$id';
  static String syllabusDetailOf(String id) => '/syllabus/$id';
  static String quizAttemptDetailOf(String id) => '/assessments/quiz-attempts/$id';
  static String assessmentMarksOf(String id, {String? subject, String? section}) {
    final q = {if (subject != null) 'subject': subject, if (section != null && section.isNotEmpty) 'section': section};
    return '/assessments/$id/marks${q.isEmpty ? '' : '?${q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}'}';
  }

  static String assessmentDetailOf(String id) => '/assessments/$id';
  static String assessmentReportRemarksOf(String assessmentId) => '/assessments/report-remarks?assessmentId=$assessmentId';
  static String curriculumDetailOf(String id) => '/curriculum/$id';
  static String behaviourStudentOf(String id) => '/behaviour/student/$id';
  static String ptmDetailOf(String id) => '/ptm/$id';
  static String fixtureDetailOf(String id) => '/fixtures/$id';
  static String studentLeaveDetailOf(String id) => '/student-leaves/$id';
  static String eventDetailOf(String id) => '/events/$id';

  /// Every module route pattern (excludes root/shell routes) - used by the route-table test.
  static const all = <String>[
    intro,
    forgotPassword,
    resetPassword,
    messages,
    messageNew,
    messageThread,
    notifications,
    timetable,
    attendance,
    attendanceMark,
    attendanceHistory,
    students,
    studentDetail,
    homework,
    homeworkNew,
    homeworkDetail,
    homeworkSubmissions,
    homeworkGrade,
    lessonPlans,
    lessonPlanNew,
    lessonPlanUpload,
    lessonPlanDetail,
    syllabus,
    syllabusWeeklyPlanner,
    syllabusDetail,
    assessments,
    assessmentReportRemarks,
    quizAttempts,
    quizAttemptDetail,
    assessmentMarks,
    assessmentDetail,
    behaviour,
    behaviourNew,
    behaviourStudent,
    ptm,
    ptmNew,
    ptmDetail,
    fixtures,
    fixtureDetail,
    leave,
    leaveApply,
    studentLeaves,
    studentLeaveDetail,
    calendar,
    events,
    eventDetail,
    curriculum,
    curriculumDetail,
    library,
    earlyYears,
    safeguarding,
    profile,
    help,
    about,
    deleteAccount,
  ];
}
