import 'package:get/get.dart';
import '../modules/about/bindings/about_binding.dart';
import '../modules/about/views/about_screen.dart';
import '../modules/assessments/bindings/assessments_binding.dart';
import '../modules/assessments/views/assessment_marks_screen.dart';
import '../modules/assessments/views/assessment_report_remarks_screen.dart';
import '../modules/assessments/views/assessment_detail_screen.dart';
import '../modules/assessments/views/assessments_screen.dart';
import '../modules/assessments/views/quiz_attempt_detail_screen.dart';
import '../modules/assessments/views/quiz_attempts_screen.dart';
import '../modules/attendance/bindings/attendance_binding.dart';
import '../modules/attendance/views/attendance_history_screen.dart';
import '../modules/attendance/views/attendance_mark_screen.dart';
import '../modules/attendance/views/attendance_screen.dart';
import '../modules/behaviour/bindings/behaviour_binding.dart';
import '../modules/behaviour/views/behaviour_new_screen.dart';
import '../modules/behaviour/views/behaviour_screen.dart';
import '../modules/behaviour/views/behaviour_student_screen.dart';
import '../modules/calendar/bindings/calendar_binding.dart';
import '../modules/calendar/views/calendar_screen.dart';
import '../modules/curriculum/bindings/curriculum_binding.dart';
import '../modules/curriculum/views/curriculum_detail_screen.dart';
import '../modules/curriculum/views/curriculum_screen.dart';
import '../modules/delete_account/bindings/delete_account_binding.dart';
import '../modules/delete_account/views/delete_account_screen.dart';
import '../modules/early_years/bindings/early_years_binding.dart';
import '../modules/early_years/views/early_years_screen.dart';
import '../modules/events/bindings/events_binding.dart';
import '../modules/events/views/event_detail_screen.dart';
import '../modules/events/views/events_screen.dart';
import '../modules/fixtures/bindings/fixtures_binding.dart';
import '../modules/fixtures/views/fixtures_screen.dart';
import '../modules/forgot_password/bindings/forgot_password_binding.dart';
import '../modules/forgot_password/views/forgot_password_screen.dart';
import '../modules/help/bindings/help_binding.dart';
import '../modules/help/views/help_screen.dart';
import '../modules/homework/bindings/homework_binding.dart';
import '../modules/homework/views/homework_detail_screen.dart';
import '../modules/homework/views/homework_grade_screen.dart';
import '../modules/homework/views/homework_new_screen.dart';
import '../modules/homework/views/homework_screen.dart';
import '../modules/homework/views/homework_submissions_screen.dart';
import '../modules/intro/bindings/intro_binding.dart';
import '../modules/intro/views/intro_screen.dart';
import '../modules/leave/bindings/leave_binding.dart';
import '../modules/leave/views/leave_apply_screen.dart';
import '../modules/leave/views/leave_screen.dart';
import '../modules/lesson_plans/bindings/lesson_plans_binding.dart';
import '../modules/lesson_plans/views/lesson_plan_detail_screen.dart';
import '../modules/lesson_plans/views/lesson_plan_new_screen.dart';
import '../modules/lesson_plans/views/lesson_plan_upload_screen.dart';
import '../modules/lesson_plans/views/lesson_plans_screen.dart';
import '../modules/library/bindings/library_binding.dart';
import '../modules/library/views/library_screen.dart';
import '../modules/messages/bindings/messages_binding.dart';
import '../modules/messages/views/message_new_screen.dart';
import '../modules/messages/views/message_thread_screen.dart';
import '../modules/notifications/bindings/notifications_binding.dart';
import '../modules/notifications/views/notifications_screen.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_edit_screen.dart';
import '../modules/profile/views/profile_screen.dart';
import '../modules/ptm/bindings/ptm_binding.dart';
import '../modules/ptm/views/ptm_detail_screen.dart';
import '../modules/ptm/views/ptm_screen.dart';
import '../modules/reset_password/bindings/reset_password_binding.dart';
import '../modules/reset_password/views/reset_password_screen.dart';
import '../modules/safeguarding/bindings/safeguarding_binding.dart';
import '../modules/safeguarding/views/safeguarding_new_screen.dart';
import '../modules/student_leaves/bindings/student_leaves_binding.dart';
import '../modules/student_leaves/views/student_leave_detail_screen.dart';
import '../modules/student_leaves/views/student_leaves_screen.dart';
import '../modules/students/bindings/students_binding.dart';
import '../modules/students/views/student_detail_screen.dart';
import '../modules/students/views/students_screen.dart';
import '../modules/syllabus/bindings/syllabus_binding.dart';
import '../modules/syllabus/views/syllabus_detail_screen.dart';
import '../modules/syllabus/views/syllabus_screen.dart';
import '../modules/syllabus/views/syllabus_weekly_planner_screen.dart';
import '../modules/timetable/bindings/timetable_binding.dart';
import '../modules/timetable/views/timetable_screen.dart';
import '../modules/auth/views/login_screen.dart';
import '../modules/auth/views/unsupported_role_screen.dart';
import '../modules/home/views/home_shell.dart';
import '../modules/splash/views/splash_screen.dart';
import 'app_routes.dart';

/// Every screen the app can push on top of the auth-gated root (login or
/// home shell). The root screens themselves are swapped by `_AuthGate`
/// in main.dart; they are registered here too so the named routes exist.
/// Static paths are listed before parameterised ones so `/homework/new`
/// is never swallowed by `/homework/:id`.
class AppPages {
  AppPages._();

  static final pages = <GetPage>[
    GetPage(name: Routes.splash, page: () => const SplashScreen()),
    GetPage(name: Routes.login, page: () => const LoginScreen()),
    GetPage(name: Routes.unsupportedRole, page: () => const UnsupportedRoleScreen()),
    GetPage(name: Routes.home, page: () => const HomeShell(initialTab: 0)),
    GetPage(name: Routes.homeClasses, page: () => const HomeShell(initialTab: 1)),
    GetPage(name: Routes.homeAttendance, page: () => const HomeShell(initialTab: 2)),
    GetPage(name: Routes.homeMessages, page: () => const HomeShell(initialTab: 3)),
    GetPage(name: Routes.homeMore, page: () => const HomeShell(initialTab: 4)),
    GetPage(
        name: Routes.intro,
        page: () => const IntroScreen(),
        binding: IntroBinding()),
    GetPage(
        name: Routes.forgotPassword,
        page: () => const ForgotPasswordScreen(),
        binding: ForgotPasswordBinding()),
    GetPage(
        name: Routes.resetPassword,
        page: () => const ResetPasswordScreen(),
        binding: ResetPasswordBinding()),
    // Static paths before the parameterised one: `/messages/new` must never be read as a thread id.
    GetPage(name: Routes.messages, page: () => const HomeShell(initialTab: 3)),
    GetPage(
        name: Routes.messageNew,
        page: () => const MessageNewScreen(),
        binding: NewThreadBinding()),
    GetPage(
        name: Routes.messageThread,
        page: () => const MessageThreadScreen(),
        binding: MessageThreadBinding()),
    GetPage(
        name: Routes.notifications,
        page: () => const NotificationsScreen(),
        binding: NotificationsBinding()),
    GetPage(
        name: Routes.timetable,
        page: () => const TimetableScreen(),
        binding: TimetableBinding()),
    GetPage(
        name: Routes.attendance,
        page: () => const AttendanceScreen(),
        binding: AttendanceBinding()),
    GetPage(
        name: Routes.attendanceMark,
        page: () => const AttendanceMarkScreen(),
        binding: AttendanceBinding()),
    GetPage(
        name: Routes.attendanceHistory,
        page: () => const AttendanceHistoryScreen(),
        binding: AttendanceBinding()),
    GetPage(
        name: Routes.students,
        page: () => const StudentsScreen(),
        binding: StudentsBinding()),
    GetPage(
        name: Routes.studentDetail,
        page: () => const StudentDetailScreen(),
        binding: StudentsBinding()),
    GetPage(
        name: Routes.homework,
        page: () => const HomeworkScreen(),
        binding: HomeworkBinding()),
    GetPage(
        name: Routes.homeworkNew,
        page: () => const HomeworkNewScreen(),
        binding: HomeworkFormBinding()),
    GetPage(
        name: Routes.homeworkDetail,
        page: () => const HomeworkDetailScreen(),
        binding: HomeworkDetailBinding()),
    GetPage(
        name: Routes.homeworkSubmissions,
        page: () => const HomeworkSubmissionsScreen(),
        binding: SubmissionsBinding()),
    GetPage(
        name: Routes.homeworkGrade,
        page: () => const HomeworkGradeScreen(),
        binding: SubmissionsBinding()),
    GetPage(
        name: Routes.lessonPlans,
        page: () => const LessonPlansScreen(),
        binding: LessonPlansBinding()),
    GetPage(
        name: Routes.lessonPlanNew,
        page: () => const LessonPlanNewScreen(),
        binding: LessonPlanFormBinding()),
    GetPage(
        name: Routes.lessonPlanUpload,
        page: () => const LessonPlanUploadScreen(),
        binding: LessonPlanUploadBinding()),
    GetPage(
        name: Routes.lessonPlanDetail,
        page: () => const LessonPlanDetailScreen(),
        binding: LessonPlanDetailBinding()),
    GetPage(
        name: Routes.syllabus,
        page: () => const SyllabusScreen(),
        binding: SyllabusBinding()),
    GetPage(
        name: Routes.syllabusWeeklyPlanner,
        page: () => const SyllabusWeeklyPlannerScreen(),
        binding: WeeklyPlannerBinding()),
    GetPage(
        name: Routes.syllabusDetail,
        page: () => const SyllabusDetailScreen(),
        binding: SyllabusDetailBinding()),
    GetPage(
        name: Routes.assessments,
        page: () => const AssessmentsScreen(),
        binding: AssessmentsBinding()),
    GetPage(
        name: Routes.assessmentReportRemarks,
        page: () => const AssessmentReportRemarksScreen(),
        binding: ReportRemarksBinding()),
    GetPage(
        name: Routes.quizAttempts,
        page: () => const QuizAttemptsScreen(),
        binding: QuizAttemptsBinding()),
    GetPage(
        name: Routes.quizAttemptDetail,
        page: () => const QuizAttemptDetailScreen(),
        binding: QuizAttemptDetailBinding()),
    GetPage(
        name: Routes.assessmentMarks,
        page: () => const AssessmentMarksScreen(),
        binding: AssessmentMarksBinding()),
    GetPage(
        name: Routes.assessmentDetail,
        page: () => const AssessmentDetailScreen(),
        binding: AssessmentDetailBinding()),
    GetPage(
        name: Routes.behaviour,
        page: () => const BehaviourScreen(),
        binding: BehaviourBinding()),
    GetPage(
        name: Routes.behaviourNew,
        page: () => const BehaviourNewScreen(),
        binding: BehaviourLogBinding()),
    GetPage(
        name: Routes.behaviourStudent,
        page: () => const BehaviourStudentScreen(),
        binding: BehaviourStudentBinding()),
    GetPage(
        name: Routes.ptm,
        page: () => const PtmScreen(),
        binding: PtmBinding()),
    GetPage(
        name: Routes.ptmDetail,
        page: () => const PtmDetailScreen(),
        binding: PtmBinding()),
    GetPage(
        name: Routes.fixtures,
        page: () => const FixturesScreen(),
        binding: FixturesBinding()),
    GetPage(
        name: Routes.leave,
        page: () => const LeaveScreen(),
        binding: LeaveBinding()),
    GetPage(
        name: Routes.leaveApply,
        page: () => const LeaveApplyScreen(),
        binding: LeaveBinding()),
    GetPage(
        name: Routes.studentLeaves,
        page: () => const StudentLeavesScreen(),
        binding: StudentLeavesBinding()),
    GetPage(
        name: Routes.studentLeaveDetail,
        page: () => const StudentLeaveDetailScreen(),
        binding: StudentLeavesBinding()),
    GetPage(
        name: Routes.calendar,
        page: () => const CalendarScreen(),
        binding: CalendarBinding()),
    GetPage(
        name: Routes.events,
        page: () => const EventsScreen(),
        binding: EventsBinding()),
    GetPage(
        name: Routes.eventDetail,
        page: () => const EventDetailScreen(),
        binding: EventsBinding()),
    GetPage(
        name: Routes.curriculum,
        page: () => const CurriculumScreen(),
        binding: CurriculumBinding()),
    GetPage(
        name: Routes.curriculumDetail,
        page: () => const CurriculumDetailScreen(),
        binding: CurriculumDetailBinding()),
    GetPage(
        name: Routes.library,
        page: () => const LibraryScreen(),
        binding: LibraryBinding()),
    GetPage(
        name: Routes.earlyYears,
        page: () => const EarlyYearsScreen(),
        binding: EarlyYearsBinding()),
    GetPage(
        name: Routes.safeguardingNew,
        page: () => const SafeguardingNewScreen(),
        binding: SafeguardingBinding()),
    GetPage(
        name: Routes.profile,
        page: () => const ProfileScreen(),
        binding: ProfileBinding()),
    GetPage(
        name: Routes.profileEdit,
        page: () => const ProfileEditScreen(),
        binding: ProfileBinding()),
    GetPage(
        name: Routes.help,
        page: () => const HelpScreen(),
        binding: HelpBinding()),
    GetPage(
        name: Routes.about,
        page: () => const AboutScreen(),
        binding: AboutBinding()),
    GetPage(
        name: Routes.deleteAccount,
        page: () => const DeleteAccountScreen(),
        binding: DeleteAccountBinding()),
  ];
}
