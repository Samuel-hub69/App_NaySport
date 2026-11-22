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

/// Paleta de colores que el admin puede asignar a los productos.
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
  double price; // en dólares (USD)
  String categoryId;
  String image; // URL, ruta de archivo local o asset
  List<String> sizes;
  List<String> colors; // nombres de kColorPalette
  int stock;
  bool active;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.image,
    this.sizes = const [],
    this.colors = const [],
    this.stock = 20,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'image': image,
        'sizes': sizes,
        'colors': colors,
        'stock': stock,
        'active': active,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        price: (j['price'] as num).toDouble(),
        categoryId: j['categoryId'],
        image: j['image'] ?? '',
        sizes: List<String>.from(j['sizes'] ?? []),
        colors: List<String>.from(j['colors'] ?? []),
        stock: j['stock'] ?? 0,
        active: j['active'] ?? true,
      );
}

class CartItem {
  final Product product;
  final String? size;
  final String? color;
  int quantity;

  CartItem({required this.product, this.size, this.color, this.quantity = 1});

  double get gross => product.price * quantity;
}

/// Regla de descuento por cantidad: si lleva [minQty] o más unidades del mismo producto, descuenta [percent]%.
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
  double shippingCost; // USD
  double freeShippingFrom; // USD
  List<DiscountRule> discounts;

  Settings({
    this.exchangeRate = 40.0,
    this.shippingCost = 9.90,
    this.freeShippingFrom = 150,
    List<DiscountRule>? discounts,
  }) : discounts = discounts ?? [DiscountRule(3, 5), DiscountRule(5, 10), DiscountRule(10, 15)];

  Map<String, dynamic> toJson() => {
        'exchangeRate': exchangeRate,
        'shippingCost': shippingCost,
        'freeShippingFrom': freeShippingFrom,
        'discounts': discounts.map((d) => d.toJson()).toList(),
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        exchangeRate: (j['exchangeRate'] as num?)?.toDouble() ?? 40,
        shippingCost: (j['shippingCost'] as num?)?.toDouble() ?? 9.9,
        freeShippingFrom: (j['freeShippingFrom'] as num?)?.toDouble() ?? 150,
        discounts: (j['discounts'] as List?)?.map((e) => DiscountRule.fromJson(e)).toList(),
      );
}

class StoredUser {
  String name;
  final String email;
  String phone;
  String passwordHash;
  String role; // 'admin' | 'cliente'
  final DateTime createdAt;

  StoredUser({
    required this.name,
    required this.email,
    required this.phone,
    required this.passwordHash,
    this.role = 'cliente',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'passwordHash': passwordHash,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StoredUser.fromJson(Map<String, dynamic> j) => StoredUser(
        name: j['name'],
        email: j['email'],
        phone: j['phone'] ?? '',
        passwordHash: j['passwordHash'],
        role: j['role'] ?? 'cliente',
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

class AppUser {
  final String name;
  final String email;
  final String provider; // 'email' | 'facebook'
  final bool isAdmin;
  const AppUser({required this.name, required this.email, required this.provider, this.isAdmin = false});
}

class OrderLine {
  final String productId;
  final String productName;
  final String? size;
  final String? color;
  final int qty;
  final double unitPrice;
  final double discountPercent;

  OrderLine({
    required this.productId,
    required this.productName,
    this.size,
    this.color,
    required this.qty,
    required this.unitPrice,
    required this.discountPercent,
  });

  double get total => unitPrice * qty * (1 - discountPercent / 100);

  String get variant => [?color, if (size != null) 'Talla $size'].join(' / ');

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'size': size,
        'color': color,
        'qty': qty,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
      };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        productId: j['productId'] ?? '',
        productName: j['productName'],
        size: j['size'],
        color: j['color'],
        qty: j['qty'],
        unitPrice: (j['unitPrice'] as num).toDouble(),
        discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
      );
}

class Order {
  final String id;
  final DateTime date;
  final String customerName;
  final String customerEmail;
  final String country;
  final String city;
  final String address;
  final String postalCode;
  final String paymentMethod;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final double exchangeRate;

  Order({
    required this.id,
    required this.date,
    required this.customerName,
    required this.customerEmail,
    required this.country,
    required this.city,
    required this.address,
    required this.postalCode,
    required this.paymentMethod,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    required this.exchangeRate,
  });

  int get units => lines.fold(0, (s, l) => s + l.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'customerName': customerName,
        'customerEmail': customerEmail,
        'country': country,
        'city': city,
        'address': address,
        'postalCode': postalCode,
        'paymentMethod': paymentMethod,
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
        customerName: j['customerName'],
        customerEmail: j['customerEmail'],
        country: j['country'],
        city: j['city'],
        address: j['address'],
        postalCode: j['postalCode'],
        paymentMethod: j['paymentMethod'],
        lines: (j['lines'] as List).map((e) => OrderLine.fromJson(e)).toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        shipping: (j['shipping'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        exchangeRate: (j['exchangeRate'] as num?)?.toDouble() ?? 0,
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

enum PaymentMethod {
  paypal('PayPal', Icons.account_balance_wallet, Color(0xFF003087)),
  card('Tarjeta de crédito / débito', Icons.credit_card, Color(0xFF6A1B9A)),
  pagoMovil('Pago Móvil', Icons.phone_android, Color(0xFF00897B)),
  zelle('Zelle', Icons.flash_on, Color(0xFF6D1ED4)),
  googlePay('Google Pay', Icons.g_mobiledata, Color(0xFF1A73E8)),
  applePay('Apple Pay', Icons.apple, Colors.black),
  transfer('Transferencia bancaria', Icons.account_balance, Color(0xFF2E7D32)),
  cash('Efectivo / contra entrega', Icons.payments, Color(0xFFEF6C00));

  const PaymentMethod(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
