import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/calendar/calendar_models.dart';
import '../models/json_helpers.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7c: school calendar + circulars (read, and acknowledge). Backend: eldermin-backend `src/school-calendar/school-calendar.controller.ts` = SCC,
/// `school-calendar.service.ts` = SCS (branch feat/staff-portal 265fcfa). No @Roles / @RequirePermission on these routes (SCC:30-34, 59-63, 105-109): any
/// authenticated user is let in.
class SchoolCalendarRepository {
  final BaseClient _client;
  SchoolCalendarRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /school-calendar/events?from&to` (SCC:30-34 -> SCS:74-161): a bare array merged from manual entries, fee-due rows, exams and
  /// terms. Overlap filter `startDate <= to && endDate >= from` (SCS:78). [from] / [to] are sent as UTC ISO instants built from the y/m/d
  /// of the window (`new Date(query.from)`, SCS:75-76). Fee rows are DROPPED by [parseCalendarEntries].
  Future<List<CalendarEntry>> fetchEvents({required DateTime fromDay, required DateTime toDay}) => _guard(() async {
        final res = await _client.get(ApiConstants.calendarEvents, queryParameters: {
          'from': '${wireDay(fromDay)}T00:00:00.000Z',
          'to': '${wireDay(toDay)}T23:59:59.999Z',
        });
        return parseCalendarEntries(expectRows(res.data, what: 'the school calendar'));
      });

  /// `GET /school-calendar/circulars?status=published` (SCC:59-63 -> SCS:190-195): bare array, newest first, limit default 100. Returns every
  /// audience (the app filters with [Circular.isForStaff]); the status param is sent AND re-checked locally.
  Future<List<Circular>> fetchCirculars() => _guard(() async {
        final res = await _client.get(ApiConstants.circulars, queryParameters: {'status': 'published'});
        return parseCirculars(expectRows(res.data, what: 'circulars'));
      });

  /// `POST /school-calendar/circulars/:id/acknowledge` (SCC:105-109 -> SCS:283-291): no body; an idempotent upsert keyed (circular, me); answers the
  /// acknowledgment document. 404 'Circular not found' (SCS:285). No role restriction, so a teacher may call it.
  Future<CircularAck> acknowledge(String id) => _guard(() async {
        final res = await _client.post(ApiConstants.circularAcknowledge(id));
        return CircularAck.fromJson(expectMap(res.data, what: 'the acknowledgment'));
      });
}
