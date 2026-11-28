import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../data/auth_service.dart';
import 'theme.dart';
import 'brand_logo.dart';

const String _appVersion = String.fromEnvironment(
  'ESHOKFIX_VERSION',
  defaultValue: '0.0.1.001',
);

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
      final username = _selectedUsername;
      if (username == null || username.isEmpty) {
        throw StateError('Selecciona un usuario para continuar.');
      }
      final user = await widget.auth.login(username, _password.text);
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
      TextField(controller: _password, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], obscureText: !_showPassword, decoration: InputDecoration(labelText: 'PIN de 6 dígitos', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility)))),
      const SizedBox(height: 12),
      TextField(controller: _confirm, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar PIN', prefixIcon: Icon(Icons.lock_reset_outlined))),
      const SizedBox(height: 8),
      const Text('El PIN debe tener exactamente 6 números.', style: TextStyle(fontSize: 11, color: Color(0xFF81778D))),
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
  final _password = TextEditingController();
  late final Future<List<Map<String, Object?>>> _loginOptionsFuture;
  String? _selectedUsername;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  final _biometric = LocalAuthentication();
  final _secure = const FlutterSecureStorage();
  bool _biometricAvailable = false;
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _loginOptionsFuture = widget.auth.loginOptions();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final supported = await _biometric.isDeviceSupported();
      final enrolled = await _biometric.getAvailableBiometrics();
      final savedUser = await _secure.read(key: 'eshokfix.biometric.username');
      final savedPin = await _secure.read(key: 'eshokfix.biometric.pin');
      if (mounted) {
        setState(() {
          _biometricAvailable = supported && enrolled.isNotEmpty;
          _biometricReady = _biometricAvailable && savedUser != null && savedPin != null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _selectedUsername;
    if (username == null || username.isEmpty) {
      setState(() => _error = 'Selecciona un usuario para continuar.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final user = await widget.auth.login(username, _password.text);
      if (user == null) throw StateError('Usuario o contraseña incorrectos.');
      await _secure.write(key: 'eshokfix.biometric.username', value: username);
      await _secure.write(key: 'eshokfix.biometric.pin', value: _password.text);
      if (mounted) widget.onAuthenticated(user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() { _busy = true; _error = null; });
    try {
      final authenticated = await _biometric.authenticate(
        localizedReason: 'Confirma tu identidad para iniciar sesión en eShokFix',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!authenticated) return;
      final username = await _secure.read(key: 'eshokfix.biometric.username');
      final pin = await _secure.read(key: 'eshokfix.biometric.pin');
      if (username == null || pin == null) {
        throw StateError('Inicia sesión con tu PIN una vez para activar el acceso biométrico.');
      }
      final user = await widget.auth.login(username, pin);
      if (user == null) throw StateError('No se pudo validar la cuenta guardada.');
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
      FutureBuilder<List<Map<String, Object?>>>(
        future: _loginOptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'No se pudieron cargar los usuarios: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFAA3944), fontSize: 12),
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Text(
              'No hay usuarios activos con PIN configurado.',
              style: TextStyle(color: Color(0xFF81778D), fontSize: 12),
            );
          }
          final selected = users.any((user) => user['username'] == _selectedUsername)
              ? _selectedUsername
              : users.first['username'] as String;
          if (_selectedUsername != selected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedUsername = selected);
            });
          }
          return DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Seleccionar usuario',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: users.map((user) {
              final username = user['username'] as String;
              final displayName = user['display_name'] as String;
              final role = (user['role'] as String).toUpperCase();
              return DropdownMenuItem<String>(
                value: username,
                child: Text('$displayName · $role', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _selectedUsername = value;
                    _error = null;
                  }),
          );
        },
      ),
      const SizedBox(height: 12),
      TextField(controller: _password, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], obscureText: !_showPassword, onSubmitted: (_) => _login(), decoration: InputDecoration(labelText: 'PIN de 6 dígitos', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility)))),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy || _selectedUsername == null ? null : _login, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión')),
      if (_biometricAvailable) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _loginWithBiometrics,
          icon: const Icon(Icons.fingerprint),
          label: Text(_biometricReady ? 'Iniciar con huella dactilar' : 'Activar acceso con huella'),
        ),
      ],
      if (_biometricAvailable && !_biometricReady) ...[
        const SizedBox(height: 8),
        const Text('Inicia sesión una vez con tu PIN para vincular esta cuenta con la huella del dispositivo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF81778D))),
      ],
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
              const SizedBox(width: 220, height: 114, child: BrandLogo(fit: BoxFit.contain)),
              const SizedBox(height: 22),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: eShokInk)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF81778D), height: 1.45)),
              const SizedBox(height: 26),
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: eShokBorder), boxShadow: [BoxShadow(color: eShokPurple.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8))]), child: child),
              const SizedBox(height: 16),
              Text(
                'eShokFix v$_appVersion',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF968DA0), fontWeight: FontWeight.w600),
              ),
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
