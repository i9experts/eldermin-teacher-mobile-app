import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../core/services/account_repository.dart';
import '../../../common/action_failure.dart';

/// Delete-account REQUEST (`/delete-account`). This asks the school administration to delete the staff app account; it does NOT delete anything
/// and NEVER signs the user out: the account stays fully active until an admin acts (service :408 "never hard-deletes").
/// Confirmation is type-to-confirm ([confirmWord]); submit is ignored while a request is in flight.
class DeleteAccountController extends GetxController {
  final AccountRepository? _repo;
  DeleteAccountController({AccountRepository? repository}) : _repo = repository;
  AccountRepository get repo => _repo ?? Get.find<AccountRepository>();

  static const confirmWord = 'DELETE';

  final reasonC = TextEditingController();
  final confirmC = TextEditingController();
  final typed = ''.obs;
  final sending = false.obs;
  final failure = Rxn<ActionFailure>();
  final result = Rxn<DeletionRequestResult>();

  bool get confirmed => typed.value.trim().toUpperCase() == confirmWord;
  bool get canSubmit => confirmed && !sending.value && result.value == null && reasonC.text.length <= kDeleteReasonMax;

  void onConfirmChanged(String v) => typed.value = v;

  Future<bool> submit() async {
    if (!canSubmit) return false;
    sending.value = true;
    failure.value = null;
    try {
      result.value = await repo.request(reason: reasonC.text);
      return true;
    } catch (e) {
      failure.value = ActionFailure.from(e, what: 'send this request', keep: 'Nothing was sent.');
      return false;
    } finally {
      sending.value = false;
    }
  }

  @override
  void onClose() {
    reasonC.dispose();
    confirmC.dispose();
    super.onClose();
  }
}
