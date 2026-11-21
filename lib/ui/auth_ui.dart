import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'theme.dart';

class InitialAdminPage extends StatefulWidget {
  const InitialAdminPage({super.key, required this.auth, required this.onAuthenticated});
  final AuthService auth;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<InitialAdminPage> createState() => _InitialAdminPageState();
}

class _InitialAdminPageState extends State<InitialAdminPage> {
  final _username = TextEditingController(text: 'admin');
  final _name = TextEditingController(text: 'Administrador');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.auth.createInitialAdmin(
        username: _username.text,
        displayName: _name.text,
        password: _password.text,
      );
      final user = await widget.auth.login(_username.text, _password.text);
      if (user == null) throw StateError('No se pudo iniciar la sesión inicial.');
      if (mounted) widget.onAuthenticated(user);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Configura tu taller',
    subtitle: 'Crea la cuenta administradora. Este paso solo aparece una vez en este dispositivo.',
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre del administrador', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(controller: _username, autocorrect: false, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.alternate_email))),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: !_showPassword, decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility)))),
      const SizedBox(height: 12),
      TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_reset_outlined))),
      const SizedBox(height: 8),
      const Text('Mínimo 10 caracteres, con mayúscula, minúscula y número.', style: TextStyle(fontSize: 11, color: Color(0xFF81778D))),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _setup, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Crear administrador y entrar')),
    ]),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, required this.onAuthenticated});
  final AuthService auth;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      final user = await widget.auth.login(_username.text, _password.text);
      if (user == null) throw StateError('Usuario o contraseña incorrectos.');
      if (mounted) widget.onAuthenticated(user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Bienvenido a eShokFix',
    subtitle: 'Inicia sesión para acceder a la operación del taller.',
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _username, autocorrect: false, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: !_showPassword, onSubmitted: (_) => _login(), decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility)))),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _login, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión')),
    ]),
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 72, height: 72, decoration: BoxDecoration(color: eShokPurple.withValues(alpha: .10), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.handyman_outlined, color: eShokPurple, size: 38)),
              const SizedBox(height: 22),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: eShokInk)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF81778D), height: 1.45)),
              const SizedBox(height: 26),
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: eShokBorder), boxShadow: [BoxShadow(color: eShokPurple.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8))]), child: child),
            ]),
          ),
        ),
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(10)),
    child: Text(message, style: const TextStyle(color: Color(0xFFAA3944), fontSize: 12)),
  );
}
