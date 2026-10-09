import 'package:get/get.dart';
import '../../../../core/models/calendar/calendar_models.dart';
import '../../../../core/services/events_repository.dart';
import '../controllers/events_controller.dart';

void ensureEventsRepository() {
  if (!Get.isRegistered<EventsRepository>()) Get.lazyPut<EventsRepository>(() => EventsRepository(), fenix: true);
}

/// `/events`.
class EventsBinding extends Bindings {
  @override
  void dependencies() {
    ensureEventsRepository();
    Get.lazyPut<EventsController>(() => EventsController());
  }
}

/// `/events/:id` (a [SchoolEvent] in `arguments` is shown at once, then refreshed from the server).
class EventDetailBinding extends Bindings {
  @override
  void dependencies() {
    ensureEventsRepository();
    final arg = Get.arguments;
    Get.lazyPut<EventDetailController>(() => EventDetailController(eventId: Get.parameters['id'] ?? '', initial: arg is SchoolEvent ? arg : null));
  }
}
