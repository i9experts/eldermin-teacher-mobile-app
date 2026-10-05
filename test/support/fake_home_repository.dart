import 'package:eldermin_teacher_app/core/models/home/class_snapshot.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/pending_grading.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';

/// Scriptable [HomeRepository]: set a handler per endpoint, default = empty
/// data. Records the arguments of the calls the tests assert on.
class FakeHomeRepository extends HomeRepository {
  Future<List<TimetableDoc>> Function(String staffId) timetable = (_) async => [];
  Future<RosterCount> Function(String grade, String? section) roster =
      (_, __) async => const RosterCount(totalInClass: 30, activeCount: 30);
  Future<int> Function(String grade, String? section, DateTime from, DateTime to) attendance =
      (_, __, ___, ____) async => 0;
  Future<List<HomeworkAssignment>> Function(String staffId) assignments = (_) async => [];
  Future<List<HomeworkSubmission>> Function(String id) submissions = (_) async => [];
  Future<List<LessonPlan>> Function(String staffId, String status) lessonPlans = (_, __) async => [];
  Future<List<PtmMeeting>> Function(String staffId) ptms = (_) async => [];
  Future<List<Substitution>> Function(String staffId, DateTime from, DateTime to) fixtures =
      (_, __, ___) async => [];
  /// Default: endpoint "not deployed" (404) so the legacy paths run unless a test opts in.
  Future<MyTimetable> Function(DateTime from, DateTime to) myTimetable = (_, __) async => failWith(404);
  Future<PendingGrading> Function() pendingGrading = () async => failWith(404);
  Future<List<PtmMeeting>> Function(String staffId, DateTime from, DateTime to) ptmRange =
      (_, __, ___) async => [];
  Future<ThreadsResult> Function() threads = () async => const ThreadsResult();
  Future<int> Function() unread = () async => 0;

  final calls = <String>[];

  @override
  Future<List<TimetableDoc>> fetchTeacherTimetable(String staffId) {
    calls.add('timetable:$staffId');
    return timetable(staffId);
  }

  @override
  Future<MyTimetable> getMyTimetable(DateTime from, DateTime to) {
    calls.add('myTimetable');
    return myTimetable(from, to);
  }

  @override
  Future<PendingGrading> getPendingGrading({int? limit}) {
    calls.add('pendingGrading');
    return pendingGrading();
  }

  @override
  Future<List<PtmMeeting>> fetchPtmsInRange(String staffId, {required DateTime from, required DateTime to}) {
    calls.add('ptmRange:$staffId');
    return ptmRange(staffId, from, to);
  }

  @override
  Future<RosterCount> fetchRoster({required String grade, String? section}) {
    calls.add('roster:$grade:$section');
    return roster(grade, section);
  }

  @override
  Future<int> fetchAttendanceCount(
      {required String grade, String? section, required DateTime from, required DateTime to}) {
    calls.add('attendance:$grade:$section');
    return attendance(grade, section, from, to);
  }

  @override
  Future<List<HomeworkAssignment>> fetchAssignments(String staffId) {
    calls.add('assignments:$staffId');
    return assignments(staffId);
  }

  @override
  Future<List<HomeworkSubmission>> fetchSubmissions(String assignmentId) {
    calls.add('submissions:$assignmentId');
    return submissions(assignmentId);
  }

  @override
  Future<List<LessonPlan>> fetchLessonPlans(String staffId, String status) {
    calls.add('lessonPlans:$staffId:$status');
    return lessonPlans(staffId, status);
  }

  @override
  Future<List<PtmMeeting>> fetchUpcomingPtms(String staffId) {
    calls.add('ptms:$staffId');
    return ptms(staffId);
  }

  @override
  Future<List<Substitution>> fetchSubstitutions(String staffId,
      {required DateTime from, required DateTime to}) {
    calls.add('fixtures:$staffId');
    return fixtures(staffId, from, to);
  }

  @override
  Future<ThreadsResult> fetchOpenThreads() {
    calls.add('threads');
    return threads();
  }

  @override
  Future<int> fetchNotificationUnreadCount() {
    calls.add('unread');
    return unread();
  }
}

Never failWith(int? status, [String message = 'error']) => throw ApiException(message, statusCode: status);
