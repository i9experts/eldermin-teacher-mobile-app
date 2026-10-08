import '../../app/routes/app_routes.dart';
import '../models/messaging/notification_models.dart';

/// Where tapping a notification goes, decided ONLY from `type` + `relatedEntityId` (+ whether the user is a class teacher). Pure and total:
/// an unknown type, a missing id or an id that is not a 24-hex ObjectId never throws, it routes to the module's LIST (or nowhere).
///
/// `relatedEntityId` per emitter (eldermin-backend feat/staff-portal 0b81e55, all read from code; the notification writer is free-form text,
/// notification-and-message.schema.ts:25):
///  * `message`        thread id           staff-portal.service.ts:254-255 (to guardian) / parent-portal.service.ts:910-911 (to staff)
///  * `ptm`            PtmMeeting id       modules/teaching/ptm.service.ts:61-66 (to the meeting's teacher)
///  * `substitution`   fixture id          modules/teaching/substitution.service.ts:185-189 (-> /fixtures/:id, resolved from the list: no get-one endpoint)
///  * `lesson_plan`    lesson plan id      modules/teaching/teaching.service.ts:394-396
///  * `homework`       ASSIGNMENT id       parent-portal.service.ts:246-250 (submission received) -> the submissions screen
///  * `leave_status`   TWO meanings: (a) parent-portal.service.ts:825-827 'New leave request' = STUDENT leave id, written to the class teacher;
///                     (b) modules/hr/hr.service.ts:1335-1340 'Leave request approved/rejected' = the teacher's OWN staff leave id.
///                     The `type` alone cannot tell them apart; the title does (UNVERIFIED heuristic, see the report).
///  * `leave_decision` student leave id, but it is written to GUARDIANS (staff-portal.service.ts:360-364): a staff inbox should never hold
///                     one; if it does, a class teacher goes to the student-leave list.
///  * circular, consent, fee_due, result, behaviour, other, anything else: no destination (stay in the inbox).
class NotificationTarget {
  final String route;

  /// True when [route] is the module's list because the id was missing/invalid or the module has no detail screen.
  final bool listFallback;
  const NotificationTarget(this.route, {this.listFallback = false});

  @override
  bool operator ==(Object other) => other is NotificationTarget && other.route == route && other.listFallback == listFallback;
  @override
  int get hashCode => Object.hash(route, listFallback);
  @override
  String toString() => 'NotificationTarget($route${listFallback ? ', list' : ''})';
}

final _objectId = RegExp(r'^[0-9a-fA-F]{24}$');
bool isObjectId(String? s) => s != null && _objectId.hasMatch(s);

/// The title the backend writes for a guardian's leave application (parent-portal.service.ts:825).
const String newStudentLeaveTitle = 'New leave request';

NotificationTarget? notificationTargetFor(AppNotification n, {required bool isClassTeacher}) {
  final id = n.relatedEntityId.trim();
  final ok = isObjectId(id);
  NotificationTarget withId(String Function(String) detail, String list) =>
      ok ? NotificationTarget(detail(id)) : NotificationTarget(list, listFallback: true);
  switch (n.type) {
    case 'message':
      return withId(Routes.messageThreadOf, Routes.homeMessages);
    case 'ptm':
      return withId(Routes.ptmDetailOf, Routes.ptm);
    case 'substitution':
      return withId(Routes.fixtureDetailOf, Routes.fixtures);
    case 'lesson_plan':
      return withId(Routes.lessonPlanDetailOf, Routes.lessonPlans);
    case 'homework':
      return withId(Routes.homeworkSubmissionsOf, Routes.homework);
    case 'leave_status':
      if (isClassTeacher && n.title.trim().toLowerCase() == newStudentLeaveTitle.toLowerCase()) {
        return withId(Routes.studentLeaveDetailOf, Routes.studentLeaves);
      }
      return const NotificationTarget(Routes.leave, listFallback: true);
    case 'leave_decision':
      return isClassTeacher ? withId(Routes.studentLeaveDetailOf, Routes.studentLeaves) : null;
    default:
      return null;
  }
}
