import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/services/events_repository.dart';
import '../../../../core/utils/home_time.dart' show Clock;
import '../../home/models/section_state.dart';

/// Events (`/events`, read only): `GET /events` returns the whole school's events (ES:147-152); the repository keeps the staff-listable ones. Grouped
/// Upcoming (not yet over, soonest first) / Past (most recent first); an event with no session is "Date to be confirmed" and sorts into Upcoming.
class EventsController extends GetxController {
  final EventsRepository? _repo;
  final Clock _clock;
  EventsController({EventsRepository? repository, Clock? clock})
      : _repo = repository,
        _clock = clock ?? DateTime.now;

  EventsRepository get repo => _repo ?? Get.find<EventsRepository>();

  final state = Rx<SectionState<List<SchoolEvent>>>(const SectionState.loading());
  int _token = 0;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_token;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    try {
      final list = await repo.fetchEvents();
      if (token != _token) return;
      state.value = list.isEmpty ? const SectionState.empty() : SectionState.data(list);
    } catch (e) {
      if (token != _token) return;
      final failed = SectionState<List<SchoolEvent>>.fromError(e);
      state.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }

  bool isPast(SchoolEvent e) {
    final end = e.lastEnd;
    return end != null && end.isBefore(_clock().toUtc());
  }

  List<SchoolEvent> get upcoming {
    final l = [for (final e in state.value.data ?? const <SchoolEvent>[]) if (!isPast(e)) e];
    final far = DateTime.utc(9999);
    l.sort((a, b) => (a.firstStart ?? far).compareTo(b.firstStart ?? far));
    return l;
  }

  List<SchoolEvent> get past {
    final l = [for (final e in state.value.data ?? const <SchoolEvent>[]) if (isPast(e)) e];
    l.sort((a, b) => b.lastEnd!.compareTo(a.lastEnd!));
    return l;
  }
}

/// `/events/:id`: starts from the list row passed as argument (if any), then reads `GET /events/:id` for the fresh copy (ticketTypes / promoCodes are
/// part of that answer and are never read).
class EventDetailController extends GetxController {
  final EventsRepository? _repo;
  final String eventId;
  final SchoolEvent? initial;
  EventDetailController({EventsRepository? repository, required this.eventId, this.initial}) : _repo = repository;

  EventsRepository get repo => _repo ?? Get.find<EventsRepository>();

  late final state = Rx<SectionState<SchoolEvent>>(initial == null ? const SectionState.loading() : SectionState.data(initial!));
  int _token = 0;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load({bool userInitiated = false}) async {
    final token = ++_token;
    final previous = state.value;
    if (!previous.hasData) state.value = const SectionState.loading();
    try {
      final e = await repo.fetchEvent(eventId);
      if (token != _token) return;
      // the by-id route also returns drafts / private events (ES:154-162): not for a teacher
      state.value = e.isListedForStaff ? SectionState.data(e) : const SectionState.error('This event is not available.');
    } catch (err) {
      if (token != _token) return;
      final failed = SectionState<SchoolEvent>.fromError(err);
      // a vanished event (404) replaces the stale copy; a transient failure keeps what is on screen
      state.value = previous.hasData && failed.status == SectionStatus.error && !userInitiated ? previous : failed;
    }
  }
}
