import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/config/app_config.dart';

void main() {
  test(
    'isPublicBetaBuild defaults to false when CAN_PUBLIC_BETA is not passed',
    () {
      // `flutter test` never passes --dart-define=CAN_PUBLIC_BETA=true, so
      // this also proves the fail-safe direction of the real-device
      // startup-routing fix (docs/ANDROID_BETA_DEVICE_TEST.md): a release
      // build that forgets this flag is refused by
      // assertAuthRepositoryConfigIsSafe/assertBackendModeConfigIsSafe
      // exactly as before, not silently allowed through.
      expect(AppConfig.isPublicBetaBuild, isFalse);
    },
  );
}
