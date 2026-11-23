import 'package:flutter/material.dart';

/// Íconos disponibles para categorías (se guardan por clave para que funcione en release).
const Map<String, IconData> kCategoryIcons = {
  'casual': Icons.checkroom,
  'deportiva': Icons.sports_gymnastics,
  'calzado': Icons.ice_skating,
  'prendas': Icons.dry_cleaning,
  'perfumes': Icons.spa,
  'accesorios': Icons.diamond_outlined,
  'bolsos': Icons.shopping_bag_outlined,
  'lenceria': Icons.favorite_border,
  'nina': Icons.child_care,
  'playa': Icons.beach_access,
  'invierno': Icons.ac_unit,
  'fiesta': Icons.celebration,
  'maquillaje': Icons.brush,
  'relojes': Icons.watch,
  'estrella': Icons.star_border,
  'etiqueta': Icons.sell_outlined,
};

IconData iconFor(String key) => kCategoryIcons[key] ?? Icons.sell_outlined;

/// Paleta de colores base que el admin puede asignar a los productos.
const Map<String, int> kColorPalette = {
  'Negro': 0xFF212121,
  'Blanco': 0xFFFFFFFF,
  'Rosado': 0xFFF48FB1,
  'Fucsia': 0xFFE91E63,
  'Rojo': 0xFFE53935,
  'Vino': 0xFF7B1F3A,
  'Naranja': 0xFFFB8C00,
  'Amarillo': 0xFFFDD835,
  'Verde': 0xFF43A047,
  'Verde oliva': 0xFF6B7F3A,
  'Celeste': 0xFF81D4FA,
  'Azul': 0xFF1E88E5,
  'Azul marino': 0xFF1A237E,
  'Morado': 0xFF8E24AA,
  'Lila': 0xFFCE93D8,
  'Beige': 0xFFE8D5B7,
  'Marrón': 0xFF6D4C41,
  'Gris': 0xFF9E9E9E,
  'Dorado': 0xFFD4AF37,
  'Plateado': 0xFFC0C0C0,
  'Nude': 0xFFE3BC9A,
  'Estampado': 0xFFFFB6C1,
};

class CategoryModel {
  final String id;
  String name;
  String iconKey;

  CategoryModel({required this.id, required this.name, required this.iconKey});

  IconData get icon => iconFor(iconKey);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': iconKey};
  factory CategoryModel.fromJson(Map<String, dynamic> j) =>
      CategoryModel(id: j['id'], name: j['name'], iconKey: j['icon'] ?? 'etiqueta');
}

class Product {
  final String id;
  String name;
  String description;
  double price; // precio de venta en USD
  double costPrice; // precio de costo en USD (solo visible para admin)
  String categoryId;
  String image; // URL, ruta de archivo local o asset
  List<String> sizes;
  List<String> colors;
  Map<String, int> colorStock; // stock separado por color
  int _generalStock; // usado solo si el producto no tiene colores
  bool active;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    double? costPrice,
    required this.categoryId,
    required this.image,
    this.sizes = const [],
    this.colors = const [],
    Map<String, int>? colorStock,
    int stock = 20,
    this.active = true,
  })  : costPrice = costPrice ?? (price > 5 ? double.parse((price - 5).toStringAsFixed(2)) : 0),
        colorStock = _buildColorStock(colors, colorStock, stock),
        _generalStock = stock;

  static Map<String, int> _buildColorStock(
      List<String> colors, Map<String, int>? explicit, int fallbackTotal) {
    if (colors.isEmpty) return {};
    if (explicit != null && explicit.isNotEmpty) {
      return {for (final c in colors) c: (explicit[c] ?? 0).clamp(0, 1 << 30)};
    }
    // Reparte el stock total equitativamente entre los colores si no venía desglosado.
    final base = fallbackTotal ~/ colors.length;
    var rem = fallbackTotal % colors.length;
    final map = <String, int>{};
    for (final c in colors) {
      map[c] = base + (rem > 0 ? 1 : 0);
      if (rem > 0) rem--;
    }
    return map;
  }

  int get stock =>
      colors.isNotEmpty ? colors.fold(0, (s, c) => s + (colorStock[c] ?? 0)) : _generalStock;

  set stock(int value) {
    final clean = value < 0 ? 0 : value;
    if (colors.isEmpty) {
      _generalStock = clean;
    } else {
      colorStock = _buildColorStock(colors, null, clean);
    }
  }

  int stockForColor(String? color) {
    if (colors.isEmpty || color == null) return stock;
    return colorStock[color] ?? 0;
  }

  void setStockForColor(String? color, int value) {
    final clean = value < 0 ? 0 : value;
    if (colors.isEmpty || color == null) {
      _generalStock = clean;
    } else {
      colorStock[color] = clean;
    }
  }

  void addStockForColor(String? color, int delta) {
    setStockForColor(color, stockForColor(color) + delta);
  }

  void syncColors(List<String> newColors, Map<String, int> newMap) {
    colors = List<String>.from(newColors);
    if (colors.isEmpty) {
      colorStock = {};
    } else {
      colorStock = {for (final c in colors) c: (newMap[c] ?? 0).clamp(0, 1 << 30)};
    }
  }

  String get colorStockSummary =>
      colors.isEmpty ? '$stock unid.' : colors.map((c) => '$c: ${colorStock[c] ?? 0}').join(' • ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'costPrice': costPrice,
        'categoryId': categoryId,
        'image': image,
        'sizes': sizes,
        'colors': colors,
        'colorStock': colorStock,
        'stock': stock,
        'active': active,
      };

  factory Product.fromJson(Map<String, dynamic> j) {
    final rawMap = j['colorStock'] as Map<String, dynamic>?;
    final parsedMap = rawMap?.map((k, v) => MapEntry(k, (v as num).toInt()));
    return Product(
      id: j['id'],
      name: j['name'],
      description: j['description'] ?? '',
      price: (j['price'] as num).toDouble(),
      costPrice: (j['costPrice'] as num?)?.toDouble() ?? 0,
      categoryId: j['categoryId'],
      image: j['image'] ?? '',
      sizes: List<String>.from(j['sizes'] ?? []),
      colors: List<String>.from(j['colors'] ?? []),
      colorStock: parsedMap,
      stock: j['stock'] ?? 0,
      active: j['active'] ?? true,
    );
  }
}

class CartItem {
  final Product product;
  final String? size;
  final String? color;
  int quantity;

  CartItem({required this.product, this.size, this.color, this.quantity = 1});

  double get gross => product.price * quantity;
}

class DiscountRule {
  int minQty;
  double percent;
  DiscountRule(this.minQty, this.percent);

  Map<String, dynamic> toJson() => {'minQty': minQty, 'percent': percent};
  factory DiscountRule.fromJson(Map<String, dynamic> j) =>
      DiscountRule(j['minQty'], (j['percent'] as num).toDouble());
}

class Settings {
  double exchangeRate; // Bs por 1 USD
  String rateSource; // 'Manual' | 'BCV Oficial' | 'Paralelo'
  DateTime? lastRateUpdate;
  bool autoSyncBcv;
  double shippingCost; // USD
  double freeShippingFrom; // USD
  List<DiscountRule> discounts;
  Map<String, int> customColors;
  List<String> removedColors;
  Map<String, List<String>> customSizes;
  Map<String, List<String>> removedSizes;

  Settings({
    this.exchangeRate = 40.0,
    this.rateSource = 'Manual',
    this.lastRateUpdate,
    this.autoSyncBcv = true,
    this.shippingCost = 9.90,
    this.freeShippingFrom = 150,
    List<DiscountRule>? discounts,
    Map<String, int>? customColors,
    List<String>? removedColors,
    Map<String, List<String>>? customSizes,
    Map<String, List<String>>? removedSizes,
  })  : discounts = discounts ?? [DiscountRule(3, 5), DiscountRule(5, 10), DiscountRule(10, 15)],
        customColors = customColors ?? {},
        removedColors = removedColors ?? [],
        customSizes = customSizes ?? {},
        removedSizes = removedSizes ?? {};

  Map<String, dynamic> toJson() => {
        'exchangeRate': exchangeRate,
        'rateSource': rateSource,
        'lastRateUpdate': lastRateUpdate?.toIso8601String(),
        'autoSyncBcv': autoSyncBcv,
        'shippingCost': shippingCost,
        'freeShippingFrom': freeShippingFrom,
        'discounts': discounts.map((d) => d.toJson()).toList(),
        'customColors': customColors,
        'removedColors': removedColors,
        'customSizes': customSizes,
        'removedSizes': removedSizes,
      };

  static Map<String, List<String>> _parseStringListMap(dynamic raw) {
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        e.key.toString(): (e.value as List? ?? []).map((x) => x.toString()).toList(),
    };
  }

  factory Settings.fromJson(Map<String, dynamic> j) {
    final rawColors = j['customColors'] as Map<String, dynamic>? ?? {};
    return Settings(
      exchangeRate: (j['exchangeRate'] as num?)?.toDouble() ?? 40,
      rateSource: j['rateSource'] ?? 'Manual',
      lastRateUpdate: j['lastRateUpdate'] != null ? DateTime.tryParse(j['lastRateUpdate']) : null,
      autoSyncBcv: j['autoSyncBcv'] ?? true,
      shippingCost: (j['shippingCost'] as num?)?.toDouble() ?? 9.9,
      freeShippingFrom: (j['freeShippingFrom'] as num?)?.toDouble() ?? 150,
      discounts: (j['discounts'] as List?)?.map((e) => DiscountRule.fromJson(e)).toList(),
      customColors: rawColors.map((k, v) => MapEntry(k, (v as num).toInt())),
      removedColors: List<String>.from(j['removedColors'] ?? []),
      customSizes: _parseStringListMap(j['customSizes']),
      removedSizes: _parseStringListMap(j['removedSizes']),
    );
  }
}

class StoredUser {
  String name;
  final String email;
  String phone;
  String passwordHash;
  String role; // 'admin' | 'cajero' | 'cliente'
  bool active;
  final DateTime createdAt;

  StoredUser({
    required this.name,
    required this.email,
    required this.phone,
    required this.passwordHash,
    this.role = 'cliente',
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cajero';

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'passwordHash': passwordHash,
        'role': role,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StoredUser.fromJson(Map<String, dynamic> j) => StoredUser(
        name: j['name'],
        email: j['email'],
        phone: j['phone'] ?? '',
        passwordHash: j['passwordHash'],
        role: j['role'] ?? 'cliente',
        active: j['active'] ?? true,
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

class AppUser {
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'cajero' | 'cliente'
  const AppUser({required this.name, required this.email, this.phone = '', this.role = 'cliente'});

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cajero';
  bool get isStaff => isAdmin || isCashier;
}

class OrderLine {
  final String productId;
  final String productName;
  final String? size;
  final String? color;
  final int qty;
  final double unitPrice;
  final double unitCost;
  final double discountPercent;

  OrderLine({
    required this.productId,
    required this.productName,
    this.size,
    this.color,
    required this.qty,
    required this.unitPrice,
    this.unitCost = 0,
    required this.discountPercent,
  });

  double get total => unitPrice * qty * (1 - discountPercent / 100);
  double get estimatedProfit => unitCost > 0 ? total - (unitCost * qty) : 0;

  String get variant => [?color, if (size != null) 'Talla $size'].join(' / ');

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'size': size,
        'color': color,
        'qty': qty,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'discountPercent': discountPercent,
      };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        productId: j['productId'] ?? '',
        productName: j['productName'],
        size: j['size'],
        color: j['color'],
        qty: j['qty'],
        unitPrice: (j['unitPrice'] as num).toDouble(),
        unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
        discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
      );
}

class Order {
  final String id;
  final DateTime date;
  final String channel; // 'Online' | 'Tienda física'
  final String cashierName; // nombre del cajero/admin o 'Online'
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerDocument; // cédula en tienda física (opcional)
  final String country;
  final String city;
  final String address;
  final String postalCode;
  final String paymentMethod;
  final String paymentDetails;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final double exchangeRate;

  Order({
    required this.id,
    required this.date,
    this.channel = 'Online',
    this.cashierName = '',
    required this.customerName,
    required this.customerEmail,
    this.customerPhone = '',
    this.customerDocument = '',
    required this.country,
    required this.city,
    required this.address,
    required this.postalCode,
    required this.paymentMethod,
    this.paymentDetails = '',
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    required this.exchangeRate,
  });

  int get units => lines.fold(0, (s, l) => s + l.qty);
  double get estimatedProfit => lines.fold(0.0, (s, l) => s + l.estimatedProfit);
  bool get isPhysical => channel == 'Tienda física';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'channel': channel,
        'cashierName': cashierName,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'customerDocument': customerDocument,
        'country': country,
        'city': city,
        'address': address,
        'postalCode': postalCode,
        'paymentMethod': paymentMethod,
        'paymentDetails': paymentDetails,
        'lines': lines.map((l) => l.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'shipping': shipping,
        'total': total,
        'exchangeRate': exchangeRate,
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        date: DateTime.parse(j['date']),
        channel: j['channel'] ?? 'Online',
        cashierName: j['cashierName'] ?? '',
        customerName: j['customerName'],
        customerEmail: j['customerEmail'] ?? '',
        customerPhone: j['customerPhone'] ?? '',
        customerDocument: j['customerDocument'] ?? '',
        country: j['country'] ?? '',
        city: j['city'] ?? '',
        address: j['address'] ?? '',
        postalCode: j['postalCode'] ?? '',
        paymentMethod: j['paymentMethod'],
        paymentDetails: j['paymentDetails'] ?? '',
        lines: (j['lines'] as List).map((e) => OrderLine.fromJson(e)).toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        shipping: (j['shipping'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        exchangeRate: (j['exchangeRate'] as num?)?.toDouble() ?? 0,
      );
}

class Supplier {
  final String id;
  String name;
  String phone;
  String email;
  String city;
  String specialty;
  String notes;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.city = '',
    this.specialty = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'city': city,
        'specialty': specialty,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'],
        name: j['name'],
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        city: j['city'] ?? '',
        specialty: j['specialty'] ?? '',
        notes: j['notes'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

class PurchaseLine {
  final String productId;
  final String productName;
  final String? color;
  final int qty;
  final double unitCost;
  final String? note;

  PurchaseLine({
    required this.productId,
    required this.productName,
    this.color,
    required this.qty,
    required this.unitCost,
    this.note,
  });

  double get total => qty * unitCost;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'color': color,
        'qty': qty,
        'unitCost': unitCost,
        'note': note,
      };

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
        productId: j['productId'] ?? '',
        productName: j['productName'],
        color: j['color'],
        qty: j['qty'],
        unitCost: (j['unitCost'] as num).toDouble(),
        note: j['note'],
      );
}

class SupplierPurchase {
  final String id;
  final DateTime date;
  final String supplierId;
  final String supplierName;
  final String invoiceRef;
  bool paid;
  final String notes;
  final List<PurchaseLine> lines;
  final double totalCost;

  SupplierPurchase({
    required this.id,
    required this.date,
    required this.supplierId,
    required this.supplierName,
    this.invoiceRef = '',
    this.paid = true,
    this.notes = '',
    required this.lines,
    required this.totalCost,
  });

  int get totalUnits => lines.fold(0, (s, l) => s + l.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceRef': invoiceRef,
        'paid': paid,
        'notes': notes,
        'lines': lines.map((l) => l.toJson()).toList(),
        'totalCost': totalCost,
      };

  factory SupplierPurchase.fromJson(Map<String, dynamic> j) => SupplierPurchase(
        id: j['id'],
        date: DateTime.parse(j['date']),
        supplierId: j['supplierId'] ?? '',
        supplierName: j['supplierName'],
        invoiceRef: j['invoiceRef'] ?? '',
        paid: j['paid'] ?? true,
        notes: j['notes'] ?? '',
        lines: (j['lines'] as List? ?? []).map((e) => PurchaseLine.fromJson(e)).toList(),
        totalCost: (j['totalCost'] as num).toDouble(),
      );
}

class StockMovement {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final String type; // 'entrada' | 'salida' | 'ajuste'
  final int delta;
  final int stockAfter;
  final String reason;

  StockMovement({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.type,
    required this.delta,
    required this.stockAfter,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'productId': productId,
        'productName': productName,
        'type': type,
        'delta': delta,
        'stockAfter': stockAfter,
        'reason': reason,
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'],
        date: DateTime.parse(j['date']),
        productId: j['productId'] ?? '',
        productName: j['productName'],
        type: j['type'],
        delta: j['delta'],
        stockAfter: j['stockAfter'],
        reason: j['reason'] ?? '',
      );
}

class Country {
  final String name;
  final String code;
  final String flag;
  final String postalHint;
  final RegExp postalPattern;
  const Country(this.name, this.code, this.flag, this.postalHint, this.postalPattern);
}

/// Métodos de pago exclusivos para tienda ONLINE.
enum PaymentMethod {
  paypal('PayPal', 'Pago rápido con tu cuenta PayPal', Icons.account_balance_wallet, Color(0xFF003087)),
  card('Tarjeta de crédito / débito', 'Visa, Mastercard o débito internacional', Icons.credit_card, Color(0xFF6A1B9A)),
  pagoMovil('Pago Móvil', 'Transferencia inmediata en Bs', Icons.phone_android, Color(0xFF00897B)),
  zelle('Zelle', 'Envío directo en dólares (\$)', Icons.flash_on, Color(0xFF6D1ED4)),
  googlePay('Google Pay', 'Pago con billetera Google', Icons.g_mobiledata, Color(0xFF1A73E8)),
  applePay('Apple Pay', 'Pago rápido con Apple Pay', Icons.apple, Colors.black);

  const PaymentMethod(this.label, this.subtitle, this.icon, this.color);
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// Métodos de pago exclusivos de TIENDA FÍSICA (Caja / Ventas).
enum PhysicalPaymentMethod {
  pos('Punto de Venta', 'Tarjeta débito / crédito en tienda (Bs)', Icons.point_of_sale, Color(0xFF6A1B9A)),
  pagoMovil('Pago Móvil', 'Transferencia inmediata en Bs', Icons.phone_android, Color(0xFF00897B)),
  zelle('Zelle', 'Transferencia en dólares (\$)', Icons.flash_on, Color(0xFF6D1ED4)),
  cashUsd('Efectivo Dólares (\$)', 'Pago en divisas en caja', Icons.attach_money, Color(0xFF2E7D32)),
  cashBs('Efectivo Bolívares (Bs)', 'Pago en efectivo moneda nacional', Icons.payments_outlined, Color(0xFFEF6C00));

  const PhysicalPaymentMethod(this.label, this.subtitle, this.icon, this.color);
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}
