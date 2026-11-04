import 'dart:convert';

class JwtHelper {
  /// Decodifica o payload do token JWT
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      var output = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (output.length % 4) {
        case 0:
          break;
        case 2:
          output += '==';
          break;
        case 3:
          output += '=';
          break;
        default:
          return null;
      }

      final payloadString = utf8.decode(base64Decode(output));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Verifica se o token expirou ou expira dentro da margem de tolerância (em segundos)
  static bool isExpired(String token, {int thresholdSeconds = 30}) {
    final payload = decodePayload(token);
    if (payload == null || !payload.containsKey('exp')) return true;

    final exp = (payload['exp'] as num).toInt();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= (exp - thresholdSeconds);
  }

  /// Extrai o e-mail do usuário caso contido no token
  static String? getEmail(String token) {
    final payload = decodePayload(token);
    return payload?['email']?.toString();
  }
}
