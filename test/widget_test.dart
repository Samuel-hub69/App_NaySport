import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:naysport/app_state.dart';
import 'package:naysport/db.dart';
import 'package:naysport/format.dart';
import 'package:naysport/main.dart';
import 'package:naysport/models.dart';
import 'package:naysport/pdf_export.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('naysport_test_');
    LocalDb.testDir = tmpDir;
  });

  tearDown(() {
    LocalDb.testDir = null;
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  testWidgets('La app arranca con el splash', (tester) async {
    await tester.pumpWidget(NaySportApp(state: AppState()));
    expect(find.text('Iniciando...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
  });

  test('Lógica completa: stock por color, costo -5, caja física, cajero, BD local y PDFs', () async {
    final state = AppState();
    await state.load();

    // Verificar rol Cajero predeterminado
    expect(state.loginWithEmail(kDefaultCashierEmail, kDefaultCashierPassword), isNull);
    expect(state.isCashier, isTrue);
    expect(state.isAdmin, isFalse);

    // Venta en tienda física de 3 pares distintos -> aplica descuento 3+ (-5%) y descuenta stock por color
    final nikeBlack = state.products.firstWhere((p) => p.id == 'r1'); // $45, cost $40, Negro:9, Blanco:6
    final nikeWhite = state.products.firstWhere((p) => p.id == 'r3'); // $48, cost $43
    final adidas = state.products.firstWhere((p) => p.id == 'r4');    // $50, cost $45
    expect(nikeBlack.costPrice, 40.0);
    expect(nikeBlack.stockForColor('Negro'), 9);
    expect(nikeBlack.stockForColor('Blanco'), 6);

    final posOrder = await state.placePhysicalSale(
      saleItems: [
        CartItem(product: nikeBlack, color: 'Negro', size: '39', quantity: 1),
        CartItem(product: nikeWhite, color: 'Blanco', size: '40', quantity: 1),
        CartItem(product: adidas, color: 'Gris', size: '41', quantity: 1),
      ],
      customerName: 'Carlos Ruiz',
      customerDocument: '20123456',
      paymentMethod: PhysicalPaymentMethod.pos.label,
      paymentDetails: 'Lote 0042',
    );
    expect(posOrder.channel, 'Tienda física');
    expect(posOrder.discount, closeTo((45 + 48 + 50) * 0.05, 0.01));
    expect(nikeBlack.stockForColor('Negro'), 8);
    expect(nikeBlack.stockForColor('Blanco'), 6); // no tocó el stock blanco
    expect(posOrder.estimatedProfit, greaterThan(0));

    // Cambiar a Admin y probar proveedor, online, Kardex y PDFs
    expect(state.loginWithEmail(kDefaultAdminEmail, kDefaultAdminPassword), isNull);
    expect(state.isAdmin, isTrue);

    final shirt = state.products.firstWhere((p) => p.id == 'r2');
    final initialNegro = shirt.stockForColor('Negro');
    final initialBlanco = shirt.stockForColor('Blanco');

    await state.addCustomColor('Turquesa', 0xFF009688);
    expect(state.allColorNames, contains('Turquesa'));

    final sup = Supplier(id: 'sup1', name: 'Textiles Caracas', phone: '04141234567');
    state.suppliers.add(sup);
    await state.recordSupplierPurchase(
      supplier: sup,
      invoiceRef: 'F-001',
      paid: true,
      notes: 'Lote nuevo',
      lines: [PurchaseLine(productId: shirt.id, productName: shirt.name, color: 'Negro', qty: 10, unitCost: 19.00)],
    );
    expect(shirt.stockForColor('Negro'), initialNegro + 10);
    expect(shirt.stockForColor('Blanco'), initialBlanco);

    // No dejar agregar más de lo disponible en un color específico
    expect(state.add(shirt, size: 'M', color: 'Blanco', qty: initialBlanco + 1), isFalse);
    expect(state.add(shirt, size: 'M', color: 'Negro', qty: 2), isTrue);
    expect(state.add(shirt, size: 'L', color: 'Blanco', qty: 3), isTrue);
    expect(state.discountTotal, closeTo(shirt.price * 5 * 0.10, 0.01));

    expect(usd(10), '\$10.00');
    expect(bs(10, 40), 'Bs 400,00');
    expect(validateFullName('María Pérez'), isNull);
    expect(validateFullName('María 123'), isNotNull);
    expect(validatePhone('+584141234567'), isNull);
    expect(validatePhone('0414-abc'), isNotNull);

    final onlineOrder = await state.placeOrder(
      customerPhone: '+584149998877',
      country: 'Venezuela',
      city: 'Caracas',
      address: 'Av. Principal',
      postalCode: '1010',
      paymentMethod: 'Pago Móvil',
      paymentDetails: 'Mercantil • Ref: 123456',
    );
    expect(shirt.stockForColor('Negro'), initialNegro + 10 - 2);
    expect(shirt.stockForColor('Blanco'), initialBlanco - 3);
    expect(state.orders.length, 2);

    // Recargar BD y generar los 5 PDFs (incluyendo Cierre del Día)
    final reloaded = AppState();
    await reloaded.load();
    expect(reloaded.orders.length, 2);
    expect(reloaded.ordersForDay(DateTime.now()).length, 2);

    final salesPdf = await PdfExporter.buildSalesPdf(reloaded.orders, reloaded.settings.exchangeRate);
    final stockPdf = await PdfExporter.buildStockPdf(reloaded);
    final purchasesPdf = await PdfExporter.buildPurchasesPdf(reloaded.purchases, reloaded.settings.exchangeRate);
    final receiptPdf = await PdfExporter.buildReceiptPdf(onlineOrder);
    final closingPdf = await PdfExporter.buildDailyClosingPdf(
        reloaded.ordersForDay(DateTime.now()), DateTime.now(), reloaded.settings.exchangeRate);
    expect(String.fromCharCodes(salesPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(stockPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(purchasesPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(receiptPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(closingPdf.take(5)), '%PDF-');
  });
}
