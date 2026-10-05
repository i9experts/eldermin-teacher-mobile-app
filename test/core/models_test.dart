import 'package:eldermin_teacher_app/core/models/api_response.dart';
import 'package:eldermin_teacher_app/core/models/paginated.dart';
import 'package:eldermin_teacher_app/core/models/staff_me.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = {
  'user': {
    'id': 'u1',
    'name': 'Amina Khan',
    'email': 'amina@school.test',
    'role': 'teacher',
    'avatarUrl': null,
    'permissions': ['teaching:view'],
  },
  'staffId': 's1',
  'teacherProfileId': 'tp1',
  'teacherProfile': {
    'employeeId': 'E-1',
    'designation': 'Senior Teacher',
    'department': 'Science',
    'subjectsCanTeach': ['Physics'],
    'gradeLevelsCanTeach': ['Grade 8'],
    'currentAssignments': [
      {'sectionName': 'A', 'subjectName': 'Physics', 'gradeLevel': 'Grade 8', 'periodsPerWeek': 5}
    ],
    'status': 'active',
    'isClassTeacher': true,
    'classTeacherOf': {'gradeId': 'g1', 'gradeName': 'Grade 8', 'sectionName': 'A', 'label': 'Grade 8 - A'},
  },
  'department': 'Science',
  'campus': {'id': 'c1', 'name': 'Main Campus'},
  'institution': {'name': 'Test School', 'slug': 'test', 'plan': 'pro', 'activeModules': ['teaching']},
};

void main() {
  test('StaffMe parses GET /staff-portal/me and merges ids into the user', () {
    final me = StaffMe.fromJson(_me);
    expect(me.staffId, 's1');
    expect(me.user.staffId, 's1');
    expect(me.user.teacherProfileId, 'tp1');
    expect(me.user.permissions, ['teaching:view']);
    expect(me.isClassTeacher, isTrue);
    expect(me.teacherProfile!.classTeacherOf!.displayName, 'Grade 8 - A');
    expect(me.teacherProfile!.currentAssignments.single.periodsPerWeek, 5);
    expect(me.institution.activeModules, ['teaching']);
    expect(me.subtitle, 'Main Campus · Science');
    // round trip keeps shape
    expect(StaffMe.fromJson(me.toJson()).staffId, 's1');
  });

  test('TeacherUser ignores absent permissions and builds initials', () {
    final u = TeacherUser.fromJson({'id': 'x', 'name': 'Amina Khan', 'email': 'e', 'role': 'teacher'});
    expect(u.permissions, isNull);
    expect(u.initials, 'AK');
    expect(const TeacherUser(id: '', name: '', email: '', role: '').initials, '--');
  });

  test('Paginated understands offset and cursor shapes and bare lists', () {
    final offset = Paginated<String>.fromJson({
      'data': [
        {'n': 'a'}
      ],
      'meta': {'total': 5, 'page': 1, 'limit': 1, 'pages': 5}
    }, (j) => j['n'] as String);
    expect(offset.items, ['a']);
    expect(offset.hasMore, isTrue);

    final cursor = Paginated<String>.fromJson({
      'items': [
        {'n': 'b'}
      ],
      'nextCursor': '2026-01-01',
      'unreadCount': 3
    }, (j) => j['n'] as String);
    expect(cursor.hasMore, isTrue);
    expect(cursor.unreadCount, 3);

    final bare = Paginated<String>.fromJson([
      {'n': 'c'}
    ], (j) => j['n'] as String);
    expect(bare.items, ['c']);
    expect(bare.hasMore, isFalse);
  });

  test('ApiResponse accepts wrapped and bare bodies', () {
    final wrapped = ApiResponse<String>.fromBody({
      'data': {'v': 'x'},
      'message': 'ok'
    }, (j) => j['v'] as String);
    expect(wrapped.data, 'x');
    expect(wrapped.message, 'ok');
    final bare = ApiResponse<String>.fromBody({'v': 'y'}, (j) => j['v'] as String);
    expect(bare.data, 'y');
    expect(ApiResponse<String>.fromBody(null, (j) => '').hasData, isFalse);
  });
}
