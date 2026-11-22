import 'package:flutter/material.dart';

enum Category {
  casual('Casual', Icons.checkroom),
  deportiva('Deportiva', Icons.sports_gymnastics),
  calzado('Calzado', Icons.ice_skating),
  prendas('Prendas', Icons.dry_cleaning),
  perfumes('Perfumes', Icons.spa),
  accesorios('Accesorios', Icons.diamond_outlined);

  const Category(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final Category category;
  final String imageUrl;
  final List<String> sizes;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.sizes = const [],
  });
}

class CartItem {
  final Product product;
  final String? size;
  int quantity;

  CartItem({required this.product, this.size, this.quantity = 1});

  double get total => product.price * quantity;
}

class AppUser {
  final String name;
  final String email;
  final String provider; // 'email' | 'facebook'
  const AppUser({required this.name, required this.email, required this.provider});
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
  googlePay('Google Pay', Icons.g_mobiledata, Color(0xFF1A73E8)),
  applePay('Apple Pay', Icons.apple, Colors.black),
  mercadoPago('Mercado Pago', Icons.handshake, Color(0xFF00B1EA)),
  transfer('Transferencia bancaria', Icons.account_balance, Color(0xFF2E7D32)),
  cash('Pago contra entrega', Icons.payments, Color(0xFFEF6C00));

  const PaymentMethod(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
