import 'package:get/get.dart';
import '../../../../core/models/help/kb_models.dart';
import '../../../../core/services/kb_repository.dart';
import '../controllers/help_controller.dart';

void ensureKbRepository() {
  if (!Get.isRegistered<KbRepository>()) Get.lazyPut<KbRepository>(() => KbRepository(), fenix: true);
}

class HelpBinding extends Bindings {
  @override
  void dependencies() {
    ensureKbRepository();
    Get.lazyPut<HelpController>(() => HelpController());
  }
}

class HelpArticleBinding extends Bindings {
  @override
  void dependencies() {
    ensureKbRepository();
    final arg = Get.arguments;
    Get.lazyPut<HelpArticleController>(() => HelpArticleController(module: Get.parameters['module'] ?? '', tabKey: Get.parameters['tabKey'] ?? '', initial: arg is KbArticle ? arg : null));
  }
}
