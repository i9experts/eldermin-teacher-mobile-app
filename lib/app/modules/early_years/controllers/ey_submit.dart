import '../../../common/action_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/early_years_repository.dart';

/// Outcome of a create form's submit.
sealed class EySubmit<T> {
  const EySubmit();
}

class EySaved<T> extends EySubmit<T> {
  final T value;
  const EySaved(this.value);
}

class EyInvalid<T> extends EySubmit<T> {
  final Map<String, String> errors;
  const EyInvalid(this.errors);
}

class EyFailed<T> extends EySubmit<T> {
  final ActionFailure failure;
  const EyFailed(this.failure);
}

/// Another submit is already running (double tap).
class EyIgnored<T> extends EySubmit<T> {
  const EyIgnored();
}

/// Teacher-readable failure of a write. The unknown-academic-year case has its own text: nothing was sent.
ActionFailure eyFailure(Object e, {required String what, bool upload = false}) {
  if (e is AcademicYearUnknown) return const ActionFailure(ActionFailureKind.other, AcademicYearUnknown.message);
  return ActionFailure.from(e, what: what, upload: upload);
}

bool isUploadUnavailable(Object e) => e is ApiException && e.statusCode == 503;
