import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// "Base de datos" local en un archivo JSON:
/// %APPDATA%\NaySport\naysport_db.json  (imágenes en %APPDATA%\NaySport\imagenes)
/// Más adelante se puede reemplazar por un servidor (Firebase, Supabase, PostgreSQL...).
class LocalDb {
  static Directory? testDir;

  static Directory get dir {
    if (testDir != null) return testDir!;
    final base = Platform.environment['APPDATA'] ?? Directory.current.path;
    return Directory('$base${Platform.pathSeparator}NaySport');
  }

  static File get file => File('${dir.path}${Platform.pathSeparator}naysport_db.json');
  static Directory get imagesDir => Directory('${dir.path}${Platform.pathSeparator}imagenes');

  static Future<Map<String, dynamic>?> read() async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Map<String, dynamic> data) async {
    await dir.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(file.path);
  }

  /// Copia una imagen elegida por el admin a la carpeta de la app y devuelve la nueva ruta.
  static Future<String> importImage(String sourcePath) async {
    await imagesDir.create(recursive: true);
    final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.png';
    final dest = '${imagesDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  static String hash(String password) =>
      sha256.convert(utf8.encode('naysport::$password')).toString();
}
