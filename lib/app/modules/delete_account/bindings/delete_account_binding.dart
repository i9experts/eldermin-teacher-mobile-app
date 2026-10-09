import 'package:get/get.dart';
import '../../../../core/services/account_repository.dart';
import '../controllers/delete_account_controller.dart';

class DeleteAccountBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AccountRepository>()) Get.lazyPut<AccountRepository>(() => AccountRepository(), fenix: true);
    Get.lazyPut<DeleteAccountController>(() => DeleteAccountController());
  }
}
