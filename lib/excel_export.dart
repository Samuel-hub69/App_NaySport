import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'app_state.dart';
import 'format.dart';
import 'win_utils.dart';

/// Exportador nativo a Microsoft Excel (.xlsx) con 2 hojas:
/// 1) Inventario Detallado (SKU, variante, producto, categoría, color, tallas, stock, costo, precio USD/Bs)
/// 2) Kardex Movimientos (entradas, salidas, ajustes y motivos)
class ExcelExporter {
  static Future<String?> saveXlsx(Uint8List bytes, String defaultName) async {
    final path = await WinUtils.saveFile(defaultName, 'Libro de Excel (*.xlsx)|*.xlsx');
    if (path == null) return null;
    final finalPath = path.toLowerCase().endsWith('.xlsx') ? path : '$path.xlsx';
    await File(finalPath).writeAsBytes(bytes);
    return finalPath;
  }

  static Uint8List buildInventoryAndKardexXlsx(AppState state) {
    final rate = state.settings.exchangeRate;

    // Hoja 1: Inventario Detallado (una fila por variante de color para control exacto)
    final invRows = <List<dynamic>>[
      [
        'Código (SKU)',
        'Código Variante',
        'Producto',
        'Categoría',
        'Color',
        'Tallas Disponibles',
        'Stock Color',
        'Stock Total',
        'Costo (USD)',
        'Precio (USD)',
        'Precio (Bs)',
        'Valor Inventario (USD)',
        'Estado',
      ],
    ];

    var grandUnits = 0;
    var grandValueUsd = 0.0;
    var grandCostUsd = 0.0;

    for (final p in state.products) {
      final catName = state.categoryName(p.categoryId);
      final sizesText = p.sizes.isEmpty ? 'Única' : p.sizes.join(', ');
      final priceBs = double.parse((p.price * rate).toStringAsFixed(2));

      if (p.colors.isEmpty) {
        final valUsd = double.parse((p.stock * p.price).toStringAsFixed(2));
        grandUnits += p.stock;
        grandValueUsd += valUsd;
        grandCostUsd += p.stock * p.costPrice;
        final status = !p.active
            ? 'Oculto'
            : (p.stock == 0 ? 'Agotado' : (p.stock <= 5 ? 'Stock bajo' : 'Disponible'));
        invRows.add([
          p.sku,
          p.sku,
          p.name,
          catName,
          'General',
          sizesText,
          p.stock,
          p.stock,
          p.costPrice,
          p.price,
          priceBs,
          valUsd,
          status,
        ]);
      } else {
        for (final color in p.colors) {
          final qty = p.stockForColor(color);
          final valUsd = double.parse((qty * p.price).toStringAsFixed(2));
          grandUnits += qty;
          grandValueUsd += valUsd;
          grandCostUsd += qty * p.costPrice;
          final status = !p.active
              ? 'Oculto'
              : (qty == 0 ? 'Agotado' : (qty <= 5 ? 'Stock bajo' : 'Disponible'));
          invRows.add([
            p.sku,
            p.variantCode(color: color),
            p.name,
            catName,
            color,
            sizesText,
            qty,
            p.stock,
            p.costPrice,
            p.price,
            priceBs,
            valUsd,
            status,
          ]);
        }
      }
    }

    invRows.add([
      'TOTALES',
      '',
      '${state.products.length} productos',
      'Tasa: ${rate.toStringAsFixed(2)} Bs/\$',
      '',
      '',
      grandUnits,
      grandUnits,
      double.parse(grandCostUsd.toStringAsFixed(2)),
      '',
      double.parse((grandValueUsd * rate).toStringAsFixed(2)),
      double.parse(grandValueUsd.toStringAsFixed(2)),
      'Generado ${fmtDate(DateTime.now())}',
    ]);

    // Hoja 2: Kardex Movimientos
    final kardexRows = <List<dynamic>>[
      [
        'ID',
        'Fecha y Hora',
        'Código (SKU)',
        'Producto',
        'Tipo',
        'Cantidad (+/-)',
        'Stock Resultante',
        'Motivo / Detalle',
      ],
    ];

    final skuById = {for (final p in state.products) p.id: p.sku};
    for (final m in state.movements) {
      final tipo = switch (m.type) {
        'entrada' => 'Entrada',
        'salida' => 'Salida',
        _ => 'Ajuste',
      };
      kardexRows.add([
        m.id,
        fmtDate(m.date),
        skuById[m.productId] ?? '-',
        m.productName,
        tipo,
        m.delta,
        m.stockAfter,
        m.reason,
      ]);
    }

    final sheet1Xml = _buildSheetXml(invRows, colWidths: const [14, 20, 34, 15, 15, 22, 13, 13, 14, 14, 16, 20, 14]);
    final sheet2Xml = _buildSheetXml(kardexRows, colWidths: const [14, 19, 14, 34, 12, 15, 16, 44]);

    return _buildZip({
      '[Content_Types].xml': utf8.encode(_contentTypesXml),
      '_rels/.rels': utf8.encode(_rootRelsXml),
      'xl/workbook.xml': utf8.encode(_workbookXml),
      'xl/_rels/workbook.xml.rels': utf8.encode(_workbookRelsXml),
      'xl/styles.xml': utf8.encode(_stylesXml),
      'xl/worksheets/sheet1.xml': utf8.encode(sheet1Xml),
      'xl/worksheets/sheet2.xml': utf8.encode(sheet2Xml),
    });
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _colLetter(int index) {
    var n = index + 1;
    final sb = StringBuffer();
    while (n > 0) {
      final rem = (n - 1) % 26;
      sb.writeCharCode(65 + rem);
      n = (n - 1) ~/ 26;
    }
    return sb.toString().split('').reversed.join();
  }

  static String _buildSheetXml(List<List<dynamic>> rows, {required List<int> colWidths}) {
    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<cols>');
    for (var i = 0; i < colWidths.length; i++) {
      sb.write('<col min="${i + 1}" max="${i + 1}" width="${colWidths[i]}" customWidth="1"/>');
    }
    sb.write('</cols><sheetData>');

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final rowNum = r + 1;
      final isHeader = r == 0;
      final isTotal = r == rows.length - 1 && row.isNotEmpty && row.first == 'TOTALES';
      final styleId = isHeader ? 1 : (isTotal ? 2 : 0);
      sb.write('<row r="$rowNum">');
      for (var c = 0; c < row.length; c++) {
        final ref = '${_colLetter(c)}$rowNum';
        final val = row[c];
        if (val is num) {
          sb.write('<c r="$ref" s="$styleId"><v>$val</v></c>');
        } else {
          final text = _escapeXml(val?.toString() ?? '');
          sb.write('<c r="$ref" t="inlineStr" s="$styleId"><is><t>$text</t></is></c>');
        }
      }
      sb.write('</row>');
    }
    sb.write('</sheetData></worksheet>');
    return sb.toString();
  }

  static const _contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbookXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>'
      '<sheet name="Inventario Detallado" sheetId="1" r:id="rId1"/>'
      '<sheet name="Kardex Movimientos" sheetId="2" r:id="rId2"/>'
      '</sheets></workbook>';

  static const _workbookRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const _stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="3">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF4A2338"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF4A2338"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFFE4EE"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="3">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '</cellXfs>'
      '</styleSheet>';

  // ------------------------------------------------------------------ ZIP (Store)
  static final List<int> _crcTable = _makeCrcTable();

  static List<int> _makeCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _buildZip(Map<String, List<int>> files) {
    final out = BytesBuilder();
    final central = BytesBuilder();
    var offset = 0;
    var count = 0;

    void write16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    void write32(BytesBuilder b, int v) =>
        b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

    for (final entry in files.entries) {
      final nameBytes = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);

      // Local file header
      write32(out, 0x04034B50);
      write16(out, 20); // version
      write16(out, 0x0800); // UTF-8 flag
      write16(out, 0); // method: store
      write16(out, 0); // mod time
      write16(out, 0); // mod date
      write32(out, crc);
      write32(out, data.length);
      write32(out, data.length);
      write16(out, nameBytes.length);
      write16(out, 0); // extra length
      out.add(nameBytes);
      out.add(data);

      // Central directory header
      write32(central, 0x02014B50);
      write16(central, 20);
      write16(central, 20);
      write16(central, 0x0800);
      write16(central, 0);
      write16(central, 0);
      write16(central, 0);
      write32(central, crc);
      write32(central, data.length);
      write32(central, data.length);
      write16(central, nameBytes.length);
      write16(central, 0);
      write16(central, 0);
      write16(central, 0);
      write16(central, 0);
      write32(central, 0);
      write32(central, offset);
      central.add(nameBytes);

      offset += 30 + nameBytes.length + data.length;
      count++;
    }

    final centralBytes = central.toBytes();
    out.add(centralBytes);

    // End of central directory record
    write32(out, 0x06054B50);
    write16(out, 0);
    write16(out, 0);
    write16(out, count);
    write16(out, count);
    write32(out, centralBytes.length);
    write32(out, offset);
    write16(out, 0);

    return out.toBytes();
  }
}
