import 'package:flutter/material.dart';
import 'data/local_store.dart';
import 'data/auth_service.dart';
import 'ui/app.dart';
import 'ui/auth_ui.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EShokFixMobileApp());
}

class EShokFixMobileApp extends StatelessWidget {
  const EShokFixMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eShokFix',
      debugShowCheckedModeBanner: false,
      theme: buildEShokFixTheme(),
      home: const StoreGate(),
    );
  }
}

class StoreGate extends StatelessWidget {
  const StoreGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalStore>(
      future: LocalStore.open(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('No se pudo abrir la base local de eShokFix.'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return AuthGate(store: snapshot.data!);
      },
    );
  }
}


class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.store});
  final LocalStore store;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthService _auth;
  AuthUser? _user;
  bool _loading = true;
  bool _setupRequired = false;
  Object? _error;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = AuthService(widget.store.db);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final user = await _auth.restoreSession();
      final setup = user == null ? await _auth.needsInitialSetup() : false;
      if (mounted) setState(() {
        _user = user;
        widget.store.setAuthenticatedUser(user);
        _setupRequired = setup;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = error; _loading = false; });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground && _user != null) {
      _validateSessionOnResume();
    }
  }

  Future<void> _touchSession() async {
    if (_user == null) return;
    try {
      await _auth.touchSession();
    } catch (_) {
      if (!mounted) return;
      widget.store.setAuthenticatedUser(null);
      setState(() => _user = null);
    }
  }

  Future<void> _validateSessionOnResume() async {
    try {
      final user = await _auth.restoreSession();
      if (!mounted) return;
      widget.store.setAuthenticatedUser(user);
      setState(() => _user = user);
    } catch (_) {
      if (!mounted) return;
      widget.store.setAuthenticatedUser(null);
      setState(() => _user = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _authenticated(AuthUser user) {
    widget.store.setAuthenticatedUser(user);
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    await _auth.logout();
    widget.store.setAuthenticatedUser(null);
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No se pudo validar la sesión local: $_error', textAlign: TextAlign.center),
      )));
    }
    if (_user != null) {
      return Listener(
        onPointerDown: (_) => _touchSession(),
        child: EShokFixShell(
          store: widget.store,
          authUser: _user!,
          onLogout: _logout,
        ),
      );
    }
    if (_setupRequired) {
      return InitialAdminPage(auth: _auth, onAuthenticated: _authenticated);
    }
    return LoginPage(auth: _auth, onAuthenticated: _authenticated);
  }
}
