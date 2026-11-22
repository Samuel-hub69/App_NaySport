import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naysport/admin/admin_screen.dart';
import 'package:naysport/app_state.dart';
import 'package:naysport/db.dart';
import 'package:naysport/format.dart';
import 'package:naysport/main.dart';
import 'package:naysport/models.dart';
import 'package:naysport/pdf_export.dart';
import 'package:naysport/screens/cashier_screen.dart';
import 'package:naysport/screens/home_screen.dart';

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

    // Verificar rol Cajero predeterminado y métodos de pago físicos permitidos
    expect(state.loginWithEmail(kDefaultCashierEmail, kDefaultCashierPassword), isNull);
    expect(state.isCashier, isTrue);
    expect(state.isAdmin, isFalse);
    expect(
      PhysicalPaymentMethod.values.map((m) => m.label).toList(),
      ['Punto de Venta', 'Pago Móvil', 'Zelle', 'Efectivo Dólares (\$)', 'Efectivo Bolívares (Bs)'],
    );

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
      customerPhone: '+584141234567',
      customerAddress: 'Av. Bolívar, Edif. Sol, Piso 2',
      paymentMethod: PhysicalPaymentMethod.pagoMovil.label,
      paymentDetails: 'Ref: 849201',
    );
    expect(posOrder.channel, 'Tienda física');
    expect(posOrder.customerPhone, '+584141234567');
    expect(posOrder.address, 'Av. Bolívar, Edif. Sol, Piso 2');
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
    expect(validateCedula('123456'), isNull);
    expect(validateCedula('20123456'), isNull);
    expect(validateCedula('1234567890'), isNull);
    expect(validateCedula('12345'), isNotNull);
    expect(validateCedula('12345678901'), isNotNull);

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

  testWidgets('Caja física exige datos del cliente y muestra solo los 4 métodos físicos', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.runAsync(() => state.load());
    state.loginWithEmail(kDefaultCashierEmail, kDefaultCashierPassword);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: CashierPosView())),
      ),
    );
    await tester.pump();

    expect(find.text('Cliente de mostrador'), findsNothing);
    expect(find.text('Transferencia bancaria'), findsNothing);
    expect(find.text('Punto de Venta'), findsOneWidget);

    expect(find.text('Datos del cliente'), findsOneWidget);
    expect(find.text('Nombre completo y apellido'), findsOneWidget);
    expect(find.text('Cédula'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Cédula'), '123456789012');
    await tester.pump();
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.text('123456789012'), findsNothing);
    expect(find.text('Pago Móvil'), findsOneWidget);
    expect(find.text('Zelle'), findsOneWidget);
    expect(find.text('Efectivo Dólares (\$)'), findsOneWidget);
    expect(find.text('Efectivo Bolívares (Bs)'), findsOneWidget);

    await tester.ensureVisible(find.text('Punto de Venta'));
    await tester.tap(find.text('Punto de Venta'));
    await tester.pump();
    expect(find.textContaining('lote'), findsNothing);
    expect(find.textContaining('por punto de venta en tienda'), findsOneWidget);
  });

  testWidgets('Categorías laterales se resaltan en rosado al pasar el mouse', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.runAsync(() => state.load());

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.chevron_right), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text('Casual').first));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('Cierre del Día muestra los métodos de pago uno debajo del otro', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.runAsync(() => state.load());
    state.loginWithEmail(kDefaultAdminEmail, kDefaultAdminPassword);

    final p1 = state.products.first;
    await tester.runAsync(() async {
      await state.placePhysicalSale(
        saleItems: [CartItem(product: p1, color: p1.colors.firstOrNull, size: p1.sizes.firstOrNull, quantity: 1)],
        customerName: 'Ana Pérez',
        customerDocument: '20123456',
        customerPhone: '+584141112233',
        customerAddress: 'Centro',
        paymentMethod: PhysicalPaymentMethod.pagoMovil.label,
        paymentDetails: 'Ref: 1111',
      );
      await state.placePhysicalSale(
        saleItems: [CartItem(product: p1, color: p1.colors.firstOrNull, size: p1.sizes.firstOrNull, quantity: 1)],
        customerName: 'Luis Gómez',
        customerDocument: '19123456',
        customerPhone: '+584142223344',
        customerAddress: 'Norte',
        paymentMethod: PhysicalPaymentMethod.pos.label,
        paymentDetails: 'Cobrado por punto de venta',
      );
    });

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pump();

    final posPos = tester.getTopLeft(find.text('Punto de Venta').first);
    final pmPos = tester.getTopLeft(find.text('Pago Móvil').first);
    expect(pmPos.dx, equals(posPos.dx));
    expect(pmPos.dy, greaterThan(posPos.dy));
  });
}
