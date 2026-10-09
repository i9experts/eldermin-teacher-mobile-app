import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/calendar/calendar_models.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7c: school EVENTS, read only (eldermin-backend `src/events/events.controller.ts` = EC, `events.service.ts` = ES). No attendees, orders,
/// tickets, fees or admin routes are ever called.
class EventsRepository {
  final BaseClient _client;
  EventsRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /events` (EC:17-21 -> ES:147-152): bare array of EVERY event of the school (drafts included), newest created first, no paging. The app keeps
  /// [SchoolEvent.isListedForStaff] rows only.
  Future<List<SchoolEvent>> fetchEvents() => _guard(() async {
        final res = await _client.get(ApiConstants.events);
        return parseSchoolEvents(expectRows(res.data, what: 'events')).where((e) => e.isListedForStaff).toList();
      });

  /// `GET /events/:id` (EC:28-32 -> ES:154-162): the event plus `ticketTypes` and `promoCodes` (never read). 404 'Event not found' (ES:156).
  Future<SchoolEvent> fetchEvent(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.eventById(id));
        final e = SchoolEvent.tryParse(expectMap(res.data, what: 'the event'));
        if (e == null) throw UnexpectedResponseShape('the event', '_id or title missing');
        return e;
      });
}
