import 'package:flutter/material.dart';
import 'data/local_store.dart';
import 'ui/app.dart';
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
        return EShokFixShell(store: snapshot.data!);
      },
    );
  }
}
