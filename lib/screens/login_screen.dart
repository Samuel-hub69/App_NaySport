import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _registerMode = false;

  void _success() {
    final u = AppScope.read(context).user!;
    showSnack(context, u.isAdmin ? 'Sesión de administrador iniciada' : 'Bienvenida, ${u.name}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [NayColors.dark, NayColors.primary, NayColors.accent],
                ),
              ),
            ),
            const ProductImage('https://loremflickr.com/900/1200/fashion,model?lock=7'),
            Container(color: NayColors.dark.withValues(alpha: 0.45)),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NayLogo(size: 110),
                  SizedBox(height: 12),
                  BrandName(fontSize: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text('Viste tu estilo.\nModa casual y deportiva para ella.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                ],
              ),
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
                  const SizedBox(height: 20),
                  Text(_registerMode ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    _registerMode
                        ? 'Completa tus datos para comprar en NaySport'
                        : 'Ingresa con tu correo y contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
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
  final VoidCallback onSuccess;
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

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final err = AppScope.read(context).loginWithEmail(_email.text, _pass.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    widget.onSuccess();
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
  final VoidCallback onSuccess;
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) return showSnack(context, 'Selecciona tu fecha de nacimiento', error: true);
    final age = DateTime.now().difference(_birth!).inDays ~/ 365;
    if (age < 18) return showSnack(context, 'Debes ser mayor de 18 años para comprar', error: true);
    if (!_terms) return showSnack(context, 'Debes aceptar los términos y condiciones', error: true);
    final err = await AppScope.read(context).register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _pass.text,
    );
    if (!mounted) return;
    if (err != null) return showSnack(context, err, error: true);
    widget.onSuccess();
  }

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
          decoration: const InputDecoration(
              labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined), hintText: '+58 414 0000000'),
          validator: (v) => RegExp(r'^\+?[\d\s\-]{7,18}$').hasMatch(v ?? '') ? null : 'Teléfono no válido',
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
