import 'dart:convert';
import 'dart:io';

class BcvRates {
  final double? oficial;
  final double? paralelo;
  final DateTime fetchedAt;

  const BcvRates({this.oficial, this.paralelo, required this.fetchedAt});
}

/// Consulta en vivo la tasa del dólar en Venezuela (BCV Oficial y Paralelo)
/// usando la API pública ve.dolarapi.com sin bloquear la app si no hay internet.
class BcvService {
  static const _endpoint = 'https://ve.dolarapi.com/v1/dolares';

  static Future<BcvRates?> fetch({Duration timeout = const Duration(seconds: 5)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse(_endpoint)).timeout(timeout);
      req.headers.set('Accept', 'application/json');
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final list = jsonDecode(body) as List;
      double? oficial;
      double? paralelo;
      for (final item in list) {
        if (item is! Map) continue;
        final fuente = (item['fuente'] ?? '').toString().toLowerCase();
        final avg = (item['promedio'] as num?)?.toDouble();
        if (avg == null || avg <= 0) continue;
        if (fuente == 'oficial') oficial = double.parse(avg.toStringAsFixed(2));
        if (fuente == 'paralelo') paralelo = double.parse(avg.toStringAsFixed(2));
      }
      if (oficial == null && paralelo == null) return null;
      return BcvRates(oficial: oficial, paralelo: paralelo, fetchedAt: DateTime.now());
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
