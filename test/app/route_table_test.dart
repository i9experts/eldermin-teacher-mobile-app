import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final names = AppPages.pages.map((p) => p.name).toList();

  test('every route name is registered exactly once', () {
    expect(names.toSet().length, names.length, reason: 'duplicate GetPage names');
    for (final r in [
      Routes.splash,
      Routes.login,
      Routes.unsupportedRole,
      Routes.home,
      Routes.homeClasses,
      Routes.homeAttendance,
      Routes.homeMessages,
      Routes.homeMore,
      ...Routes.all,
    ]) {
      expect(names, contains(r), reason: 'missing GetPage for $r');
    }
  });

  test('Part D.3 route list is covered', () {
    const expected = [
      '/intro', '/forgot-password', '/reset-password', '/notifications', '/timetable',
      '/attendance', '/attendance/mark', '/attendance/history',
      '/students', '/students/:id',
      '/homework', '/homework/new', '/homework/:id', '/homework/:id/submissions',
      '/homework/:id/submissions/:sid/grade',
      '/lesson-plans', '/lesson-plans/new', '/lesson-plans/:id', '/lesson-plans/upload',
      '/syllabus', '/syllabus/:id', '/syllabus/weekly-planner',
      '/assessments', '/assessments/:id/marks', '/assessments/report-remarks',
      '/assessments/quiz-attempts', '/assessments/quiz-attempts/:id',
      '/behaviour', '/behaviour/new', '/behaviour/student/:id',
      '/ptm', '/ptm/new', '/ptm/:id', '/fixtures', '/fixtures/:id', '/leave', '/leave/apply',
      '/student-leaves', '/student-leaves/:id', '/messages', '/messages/new', '/messages/:threadId',
      '/calendar', '/events', '/events/:id', '/curriculum', '/library',
      '/early-years', '/safeguarding',
      '/profile', '/help', '/help/:module/:tabKey', '/about', '/delete-account',
      '/home', '/home/classes', '/home/attendance', '/home/messages', '/home/more',
      '/splash', '/login', '/unsupported-role',
    ];
    for (final path in expected) {
      expect(names, contains(path), reason: path);
    }
  });

  test('static paths are registered before parameterised siblings', () {
    int idx(String n) => names.indexOf(n);
    expect(idx('/homework/new'), lessThan(idx('/homework/:id')));
    expect(idx('/ptm/new'), lessThan(idx('/ptm/:id')));
    expect(idx('/lesson-plans/new'), lessThan(idx('/lesson-plans/:id')));
    expect(idx('/lesson-plans/upload'), lessThan(idx('/lesson-plans/:id')));
    expect(idx('/syllabus/weekly-planner'), lessThan(idx('/syllabus/:id')));
    expect(idx('/assessments/report-remarks'), lessThan(idx('/assessments/:id/marks')));
    expect(idx('/assessments/quiz-attempts'), lessThan(idx('/assessments/:id/marks')));
  });

  test('parameter helpers build concrete locations', () {
    expect(Routes.homeworkGradeOf('h1', 's2'), '/homework/h1/submissions/s2/grade');
    expect(Routes.studentDetailOf('42'), '/students/42');
  });

  group('module catalog visibility', () {
    final active = ['teaching', 'students', 'syllabus', 'assessment', 'behaviour', 'hr', 'timetable', 'library', 'curriculum', 'early-years'];
    final teacher = PermissionService(role: 'teacher', activeModules: active);

    List<String> ids(ModulePlacement p, PermissionService s, {required bool classTeacher}) =>
        ModuleCatalog.visible(p, s, isClassTeacher: classTeacher).map((e) => e.id).toList();

    test('Early Years slot exists but is hidden in v1', () {
      expect(ModuleCatalog.all.any((e) => e.id == 'early_years'), isTrue);
      expect(ids(ModulePlacement.more, teacher, classTeacher: true), isNot(contains('early_years')));
    });

    test('class-teacher-only entries need the class-teacher flag', () {
      expect(ids(ModulePlacement.more, teacher, classTeacher: false), isNot(contains('student_leaves')));
      expect(ids(ModulePlacement.more, teacher, classTeacher: true), contains('student_leaves'));
    });

    test('activeModules does not hide permitted entries (web parity)', () {
      final p = PermissionService(role: 'teacher', activeModules: ['teaching']);
      final classes = ids(ModulePlacement.classes, p, classTeacher: false);
      expect(classes, containsAll(['students', 'homework', 'lesson_plans', 'assessments']));
      final more = ids(ModulePlacement.more, p, classTeacher: false);
      expect(more, containsAll(['calendar', 'events', 'safeguarding', 'library', 'leave']));
    });

    test('custom permissions can hide entries a teacher normally has', () {
      final p = PermissionService(role: 'teacher', customPermissions: ['teaching:view'], activeModules: active);
      final classes = ids(ModulePlacement.classes, p, classTeacher: false);
      expect(classes, containsAll(['homework', 'lesson_plans', 'syllabus']));
      expect(classes, isNot(contains('behaviour')));
      expect(classes, isNot(contains('students')));
    });

    test('unsupported/unknown role sees nothing permission-gated', () {
      final p = PermissionService(role: 'parent', activeModules: active);
      expect(ids(ModulePlacement.classes, p, classTeacher: false), isEmpty);
      expect(ids(ModulePlacement.more, p, classTeacher: false), ['safeguarding']);
    });
  });
}
