import 'package:eldermin_teacher_app/core/utils/deep_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _hex = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnLW5hdHVyZS1fLQ';

DeepLink? p(String s) => DeepLinkParser.parseString(s);

void main() {
  group('reset-password', () {
    test('custom scheme with a valid token', () {
      final l = p('eldermin-teacher://reset-password?token=$_hex');
      expect(l, isA<ResetPasswordLink>());
      expect((l as ResetPasswordLink).token, _hex);
    });

    test('https web link (future verified app links) with the right host', () {
      final l = p('https://app.eldermin.com/reset-password?token=$_hex');
      expect((l as ResetPasswordLink).token, _hex);
      expect(p('https://app.eldermin.com/reset-password/?token=$_hex'), isA<ResetPasswordLink>());
    });

    test('scheme/host are case-insensitive, trailing slash tolerated', () {
      expect(p('ELDERMIN-TEACHER://Reset-Password/?token=$_hex'), isA<ResetPasswordLink>());
    });

    test('extra params are ignored', () {
      final l = p('eldermin-teacher://reset-password?utm=x&token=$_hex&foo=bar');
      expect((l as ResetPasswordLink).token, _hex);
    });

    test('missing / empty token is rejected', () {
      expect(p('eldermin-teacher://reset-password'), isNull);
      expect(p('eldermin-teacher://reset-password?token='), isNull);
      expect(p('eldermin-teacher://reset-password?tok=$_hex'), isNull);
    });

    test('duplicate token params are ambiguous and rejected', () {
      expect(p('eldermin-teacher://reset-password?token=$_hex&token=$_hex'), isNull);
    });

    test('very long token is rejected', () {
      expect(p('eldermin-teacher://reset-password?token=${'a' * 100000}'), isNull);
      expect(p('eldermin-teacher://reset-password?token=${'a' * 513}'), isNull);
      expect(p('eldermin-teacher://reset-password?token=${'a' * 512}'), isA<ResetPasswordLink>());
    });

    test('too-short and illegal-character tokens are rejected', () {
      expect(p('eldermin-teacher://reset-password?token=abc'), isNull);
      expect(p('eldermin-teacher://reset-password?token=${Uri.encodeQueryComponent('<script>alert(1)</script>')}'), isNull);
      expect(p('eldermin-teacher://reset-password?token=${Uri.encodeQueryComponent('abcdefgh ijkl')}'), isNull);
    });

    test('wrong host / path is rejected', () {
      expect(p('eldermin-teacher://evil.com?token=$_hex'), isNull);
      expect(p('eldermin-teacher://reset-password.evil.com?token=$_hex'), isNull);
      expect(p('eldermin-teacher://reset-password/extra/path?token=$_hex'), isNull);
      expect(p('eldermin-teacher://home?token=$_hex'), isNull);
      expect(p('https://evil.com/reset-password?token=$_hex'), isNull);
      expect(p('https://app.eldermin.com.evil.com/reset-password?token=$_hex'), isNull);
      expect(p('https://app.eldermin.com/other?token=$_hex'), isNull);
      expect(p('https://user:pw@app.eldermin.com/reset-password?token=$_hex'), isNull);
    });
  });

  group('token login', () {
    test('valid token + slug', () {
      final l = p('eldermin-teacher://login?token=$_jwt&slug=Demo-School');
      expect(l, isA<TokenLoginLink>());
      expect((l as TokenLoginLink).token, _jwt);
      expect(l.slug, 'demo-school');
    });

    test('https web parity /login?token=&slug=', () {
      expect(p('https://app.eldermin.com/login?token=$_jwt&slug=demo'), isA<TokenLoginLink>());
    });

    test('both token and slug are required', () {
      expect(p('eldermin-teacher://login?token=$_jwt'), isNull);
      expect(p('eldermin-teacher://login?slug=demo'), isNull);
      expect(p('eldermin-teacher://login'), isNull);
      expect(p('eldermin-teacher://login?token=&slug=demo'), isNull);
    });

    test('non-JWT tokens and hostile slugs are rejected', () {
      expect(p('eldermin-teacher://login?token=notajwt&slug=demo'), isNull);
      expect(p('eldermin-teacher://login?token=$_jwt&slug=${Uri.encodeQueryComponent('../../etc')}'), isNull);
      expect(p('eldermin-teacher://login?token=$_jwt&slug=${Uri.encodeQueryComponent('a b')}'), isNull);
      expect(p('eldermin-teacher://login?token=$_jwt&slug=${'a' * 80}'), isNull);
    });

    test('very long token is rejected', () {
      final long = 'a.${'b' * 5000}.c';
      expect(p('eldermin-teacher://login?token=$long&slug=demo'), isNull);
    });

    test('extra params are ignored', () {
      expect(p('eldermin-teacher://login?x=1&token=$_jwt&slug=demo&y=2'), isA<TokenLoginLink>());
    });
  });

  group('malicious / unsupported input', () {
    test('javascript:, http:, file:, data:, content: schemes are rejected', () {
      for (final s in [
        'javascript:alert(1)',
        'javascript://reset-password?token=$_hex',
        'http://app.eldermin.com/reset-password?token=$_hex',
        'file:///etc/passwd',
        'data:text/html,<script>1</script>',
        'content://reset-password?token=$_hex',
        'eldermin://reset-password?token=$_hex',
        'eldermin-teacher-evil://reset-password?token=$_hex',
      ]) {
        expect(p(s), isNull, reason: s);
      }
    });

    test('garbage / empty / oversized strings', () {
      expect(p(''), isNull);
      expect(p('   '), isNull);
      expect(p('not a url at all'), isNull);
      expect(p('%%%'), isNull);
      expect(p('eldermin-teacher://${'a' * 100000}'), isNull);
    });

    test('userinfo or port on the custom scheme is rejected', () {
      expect(p('eldermin-teacher://user@reset-password?token=$_hex'), isNull);
      expect(p('eldermin-teacher://reset-password:8080?token=$_hex'), isNull);
    });
  });

  group('extractResetToken (paste fallback)', () {
    test('bare token', () {
      expect(DeepLinkParser.extractResetToken(_hex), _hex);
      expect(DeepLinkParser.extractResetToken('  $_hex \n'), _hex);
    });

    test('full https link from the email', () {
      expect(DeepLinkParser.extractResetToken('https://app.eldermin.com/reset-password?token=$_hex'), _hex);
    });

    test('custom-scheme link', () {
      expect(DeepLinkParser.extractResetToken('eldermin-teacher://reset-password?token=$_hex'), _hex);
    });

    test('rejects unrelated links, wrong hosts and junk', () {
      expect(DeepLinkParser.extractResetToken('https://evil.com/reset-password?token=$_hex'), isNull);
      expect(DeepLinkParser.extractResetToken('javascript:alert(1)'), isNull);
      expect(DeepLinkParser.extractResetToken('https://app.eldermin.com/login'), isNull);
      expect(DeepLinkParser.extractResetToken(''), isNull);
      expect(DeepLinkParser.extractResetToken('short'), isNull);
      expect(DeepLinkParser.extractResetToken('has spaces in it here'), isNull);
      expect(DeepLinkParser.extractResetToken('a' * 600), isNull);
    });
  });
}
