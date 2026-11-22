import 'dart:convert';
import 'dart:io';

/// Utilidades de Windows sin plugins nativos (diálogos de archivo vía PowerShell).
class WinUtils {
  static Future<String?> _ps(String script) async {
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script],
          stdoutEncoding: utf8);
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Abre el diálogo "Abrir" de Windows para elegir una imagen.
  static Future<String?> pickImage() => _ps(r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Title = 'Elegir imagen del producto'
$f.Filter = 'Imágenes|*.png;*.jpg;*.jpeg;*.webp;*.bmp'
if ($f.ShowDialog() -eq 'OK') { $f.FileName }
''');

  /// Abre el diálogo "Guardar como" de Windows.
  static Future<String?> saveFile(String defaultName, String filter) => _ps('''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$f = New-Object System.Windows.Forms.SaveFileDialog
\$f.FileName = '$defaultName'
\$f.Filter = '$filter'
\$f.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
if (\$f.ShowDialog() -eq 'OK') { \$f.FileName }
''');

  /// Abre un archivo con el programa predeterminado (ej. el visor de PDF para imprimir).
  static Future<void> open(String path) async {
    await Process.run('cmd', ['/c', 'start', '', path]);
  }
}
