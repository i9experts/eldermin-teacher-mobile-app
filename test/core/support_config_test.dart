import 'package:eldermin_teacher_app/core/constants/support_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    SupportConfig.emailOverride = null;
    SupportConfig.urlOverride = null;
  });

  test('nothing configured by default: no email, no url, card hidden', () {
    expect(SupportConfig.email, isNull);
    expect(SupportConfig.url, isNull);
    expect(SupportConfig.isConfigured, isFalse);
  });

  test('a well-formed email and an https url are accepted; anything else is ignored', () {
    SupportConfig.emailOverride = ' help@school.example ';
    SupportConfig.urlOverride = 'https://school.example/help';
    expect(SupportConfig.email, 'help@school.example');
    expect(SupportConfig.url!.host, 'school.example');
    expect(SupportConfig.isConfigured, isTrue);
    for (final bad in ['help', 'a@b', 'a b@c.d', '<x>@y.z', '']) {
      SupportConfig.emailOverride = bad;
      expect(SupportConfig.email, isNull, reason: bad);
    }
    for (final bad in ['http://school.example', 'javascript:alert(1)', 'school.example/help', 'https://', '']) {
      SupportConfig.urlOverride = bad;
      expect(SupportConfig.url, isNull, reason: bad);
    }
  });
}
