import 'package:advise_digital/app_error.dart';
import 'package:advise_digital/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe validation stays readable', () {
    expect(AppError.message('En az bir dosya seçmelisin.'),
        'En az bir dosya seçmelisin.');
  });

  test('raw infrastructure and credential strings are never reflected', () {
    for (final value in [
      'SocketException: connection refused',
      '<html><body>500 failure</body></html>',
      '{"error":"internal server","access_token":"fixture"}',
      'JWT secret geçersiz: fixture',
      'API key fixture gizli',
      'TypeError: Cannot read properties of undefined',
    ]) {
      final message = AppError.message(value);
      expect(message, isNot(contains('fixture')));
      expect(message, isNot(contains('Exception')));
      expect(message, isNot(contains('<html>')));
      expect(message, isNot(contains('TypeError')));
    }
  });

  test('known auth, network, subscription and permission failures guide users',
      () {
    expect(
        AppError.message('Kullanıcı adı veya şifre hatalı.', statusCode: 401),
        contains('şifre hatalı'));
    expect(AppError.message('expired', statusCode: 401),
        contains('yeniden giriş'));
    expect(AppError.message('denied', statusCode: 403), contains('yetkiniz'));
    expect(AppError.message('Abonelik süresi doldu.', statusCode: 403),
        contains('Aboneliğinizin süresi'));
    expect(
        AppError.message('Meta token expired'), contains('yeniden bağlayın'));
    expect(AppError.message('TimeoutException'), contains('uzun sürdü'));
    expect(AppError.message('quota exhausted', statusCode: 429),
        contains('kullanım sınırına'));
  });

  test('ApiException does not expose HTTP codes or diagnostics', () {
    const error = ApiException('<html>upstream failure</html>',
        statusCode: 500, details: 'private diagnostics');
    expect(error.toString(), contains('Hizmet'));
    expect(error.toString(), isNot(contains('500')));
    expect(error.toString(), isNot(contains('diagnostics')));
  });
}
