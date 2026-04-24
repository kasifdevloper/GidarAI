import '../models/app_models.dart';

class ProviderHealthStore {
  final Map<AiProviderType, ProviderCheckStatus> _checks = {};

  ProviderCheckStatus statusFor(AiProviderType provider) {
    return _checks[provider] ?? const ProviderCheckStatus();
  }

  void markFailure(
    AiProviderType provider, {
    required String message,
  }) {
    _checks[provider] = ProviderCheckStatus(
      state: ProviderCheckState.failure,
      message: message,
    );
  }

  void markTesting(AiProviderType provider) {
    _checks[provider] = const ProviderCheckStatus(
      state: ProviderCheckState.testing,
      message: 'Testing key...',
    );
  }

  void markSuccess(AiProviderType provider) {
    _checks[provider] = const ProviderCheckStatus(
      state: ProviderCheckState.success,
      message: 'Key working',
    );
  }

  void clear() {
    _checks.clear();
  }
}
