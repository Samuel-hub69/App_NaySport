import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Usuarios registrados en memoria (simulación; luego se reemplaza por un backend real).
final Map<String, ({String name, String password})> _registered = {};

final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _registerMode = false;

  void _success(AppUser u) {
    AppScope.of(context).login(u);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bienvenida, ${u.name}'),
      behavior: SnackBarBehavior.floating,
      width: 400,
    ));
    Navigator.pop(context, true);
  }

  Future<void> _facebook() async {
    // Simulación del flujo OAuth de Facebook.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Conectando con Facebook...'),
        ]),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);
    _success(const AppUser(name: 'Usuaria Facebook', email: 'usuario@facebook.com', provider: 'facebook'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            const NetImage('https://loremflickr.com/900/1200/fashion,model?lock=7'),
            Container(color: NayColors.dark.withValues(alpha: 0.45)),
            const Center(
              child: Text('Viste tu estilo.\nViste NaySport.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            ),
          ]),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: NayLogo(size: 80)),
                  const SizedBox(height: 24),
                  Text(_registerMode ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                    icon: const Icon(Icons.facebook),
                    label: const Text('Continuar con Facebook'),
                    onPressed: _facebook,
                  ),
                  const SizedBox(height: 20),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('o con tu correo')),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _registerMode
                        ? _RegisterForm(key: const ValueKey('r'), onSuccess: _success)
                        : _LoginForm(key: const ValueKey('l'), onSuccess: _success),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _registerMode = !_registerMode),
                    child: Text(_registerMode
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿No tienes cuenta? Regístrate'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LoginForm extends StatefulWidget {
  final void Function(AppUser) onSuccess;
  const _LoginForm({super.key, required this.onSuccess});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final u = _registered[_email.text.trim().toLowerCase()];
    if (u == null || u.password != _pass.text) {
      setState(() => _error = 'Correo o contraseña incorrectos');
      return;
    }
    widget.onSuccess(AppUser(name: u.name, email: _email.text.trim(), provider: 'email'));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => _emailRe.hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _pass,
          obscureText: _obscure,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: const Text('Ingresar')),
      ]),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  final void Function(AppUser) onSuccess;
  const _RegisterForm({super.key, required this.onSuccess});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birth;
  bool _terms = false;
  bool _obscure = true;

  String? _passValidator(String? v) {
    final p = v ?? '';
    if (p.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Debe tener al menos una mayúscula';
    if (!RegExp(r'[a-z]').hasMatch(p)) return 'Debe tener al menos una minúscula';
    if (!RegExp(r'\d').hasMatch(p)) return 'Debe tener al menos un número';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) return 'Debe tener un símbolo (!@#...)';
    return null;
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (d != null) setState(() => _birth = d);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) return _snack('Selecciona tu fecha de nacimiento');
    final age = DateTime.now().difference(_birth!).inDays ~/ 365;
    if (age < 18) return _snack('Debes ser mayor de 18 años para comprar');
    if (!_terms) return _snack('Debes aceptar los términos y condiciones');
    final key = _email.text.trim().toLowerCase();
    if (_registered.containsKey(key)) return _snack('Ese correo ya está registrado');
    _registered[key] = (name: _name.text.trim(), password: _pass.text);
    widget.onSuccess(AppUser(name: _name.text.trim(), email: _email.text.trim(), provider: 'email'));
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, width: 400));

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => (v ?? '').trim().split(RegExp(r'\s+')).length < 2 ? 'Ingresa nombre y apellido' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => _emailRe.hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined), hintText: '+591 70000000'),
          validator: (v) => RegExp(r'^\+?[\d\s]{7,15}$').hasMatch(v ?? '') ? null : 'Teléfono no válido',
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18), alignment: Alignment.centerLeft),
          icon: const Icon(Icons.cake_outlined),
          label: Text(_birth == null
              ? 'Fecha de nacimiento'
              : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}'),
          onPressed: _pickBirth,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _pass,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: '8+ caracteres, mayúscula, minúscula, número y símbolo',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: _passValidator,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_reset)),
          validator: (v) => v == _pass.text ? null : 'Las contraseñas no coinciden',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _terms,
          onChanged: (v) => setState(() => _terms = v ?? false),
          title: const Text('Acepto los términos, condiciones y la política de privacidad'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _submit, child: const Text('Crear cuenta')),
      ]),
    );
  }
}
