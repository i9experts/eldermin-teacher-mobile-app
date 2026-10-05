import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_360.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attendance_repository.dart';
import 'package:eldermin_teacher_app/core/services/students_repository.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';

StudentSummary student(int i, {String grade = 'Grade 5', String section = 'A', String status = 'active', String? year = '2026-27'}) =>
    StudentSummary(
      id: 'st${i.toString().padLeft(22, '0')}',
      studentId: 'STU-$i',
      firstName: 'First$i',
      lastName: 'Last$i',
      grade: grade,
      section: section,
      rollNumber: '$i',
      status: status,
      academicYear: year,
    );

/// Record as the server returns it (date = the stored instant).
AttendanceRecord record(StudentSummary s, DateTime storedInstant, Object? status) => AttendanceRecord(
    id: 'r${s.id}', studentId: s.id, studentName: s.fullName, grade: s.grade, section: s.section, date: storedInstant,
    status: AttendanceStatus.fromWire(status), rawStatus: status?.toString());

class FakeStudentsRepository extends StudentsRepository {
  Future<List<StudentSummary>> Function(ClassRef cls) roster = (_) async => [];
  Future<GradesSections> Function() grades = () async => const GradesSections();
  Future<Student360> Function(String id) detail = (_) async => throw ApiException('nope', statusCode: 404);
  Future<StatusCounts> Function(String id, int year, int month) summary = (_, __, ___) async => const StatusCounts();
  final calls = <String>[];

  @override
  Future<GradesSections> fetchGradesSections() {
    calls.add('grades');
    return grades();
  }

  @override
  Future<List<StudentSummary>> fetchClassRoster(ClassRef cls, {GradesSections? known}) {
    calls.add('roster:${cls.label}');
    return roster(cls);
  }

  @override
  Future<Student360> fetchStudent360(String id) {
    calls.add('360:$id');
    return detail(id);
  }

  @override
  Future<StatusCounts> fetchAttendanceSummary(String id, {required int year, required int month}) async {
    calls.add('summary:$id:$year-$month');
    return summary(id, year, month);
  }
}

class FakeAttendanceRepository extends AttendanceRepository {
  Future<List<AttendanceRecord>> Function(String grade, String? section, DateTime first, DateTime last) range =
      (_, __, ___, ____) async => [];
  Future<void> Function(List<AttendanceWrite> records, String? year) onSubmit = (_, __) async {};
  final rangeCalls = <({String grade, String? section, DateTime first, DateTime last})>[];
  final submitted = <List<AttendanceWrite>>[];
  final years = <String?>[];

  @override
  Future<List<AttendanceRecord>> fetchRange({
    required String grade,
    String? section,
    required DateTime firstDay,
    required DateTime lastDay,
  }) {
    rangeCalls.add((grade: grade, section: section, first: firstDay, last: lastDay));
    return range(grade, section, firstDay, lastDay);
  }

  @override
  Future<void> submit(List<AttendanceWrite> records, {String? academicYear}) {
    submitted.add(records);
    years.add(academicYear);
    return onSubmit(records, academicYear);
  }
}
