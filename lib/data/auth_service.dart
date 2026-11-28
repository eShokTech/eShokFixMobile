import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  final int id;
  final String username;
  final String displayName;
  final String role;

  factory AuthUser.fromRow(Map<String, Object?> row) => AuthUser(
    id: row['id'] as int,
    username: row['username'] as String,
    displayName: row['display_name'] as String,
    role: (row['role'] as String).toUpperCase(),
  );
}

class AuthService {
  AuthService(this.db, {FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Database db;
  final FlutterSecureStorage _secureStorage;

  static const sessionKey = 'eshokfix.auth.session';
  static const passwordIterations = 120000;
  static const sessionLifetime = Duration(hours: 12);
  static const idleLifetime = Duration(minutes: 30);
  static const maxFailedAttempts = 5;
  static const lockDuration = Duration(minutes: 15);

  static const rolePermissions = <String, Set<String>>{
    'ADMIN': {'*'},
    'ENCARGADO': {
      'dashboard.view', 'clients.view', 'clients.manage', 'clients.delete', 'orders.cancel',
      'orders.view', 'orders.manage', 'orders.authorize', 'orders.pay', 'orders.payments.view',
      'inventory.view', 'inventory.manage', 'inventory.cost.view', 'sales.view', 'sales.manage',
      'cash.view', 'cash.manage', 'purchases.view', 'purchases.manage',
      'warranties.view', 'reports.view', 'settings.read', 'settings.view', 'settings.manage', 'users.manage',
    },
    'TECNICO': {
      'dashboard.view', 'clients.view', 'clients.manage', 'settings.read',
      'orders.view', 'orders.manage', 'orders.authorize', 'orders.payments.view',
      'inventory.view', 'warranties.view',
    },
    'CAJA': {
      'dashboard.view', 'clients.view', 'settings.read', 'orders.view', 'orders.pay', 'orders.payments.view',
      'inventory.view', 'sales.view', 'sales.manage', 'cash.view', 'cash.manage',
      'warranties.view', 'reports.view',
    },
  };

  static bool can(String role, String permission) {
    final permissions = rolePermissions[role.toUpperCase()];
    return permissions?.contains('*') == true ||
        permissions?.contains(permission) == true;
  }

  Future<bool> needsInitialSetup() async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) total FROM users WHERE COALESCE(password_hash,'') != ''",
    );
    return ((rows.first['total'] as num).toInt()) == 0;
  }

  Future<void> createInitialAdmin({
    required String username,
    required String displayName,
    required String password,
  }) async {
    _validateCredentials(username, displayName, password);
    await db.transaction((tx) async {
      final rows = await tx.rawQuery(
        "SELECT COUNT(*) total FROM users WHERE COALESCE(password_hash,'') != ''",
      );
      if ((rows.first['total'] as num).toInt() != 0) {
        throw StateError('La configuración inicial ya fue completada.');
      }
      final existing = await tx.query('users',
          where: 'username=?', whereArgs: [username.trim()], limit: 1);
      final salt = _randomBytes(16);
      final hash = _derive(password, salt);
      if (existing.isEmpty) {
        await tx.insert('users', {
          'username': username.trim(),
          'display_name': displayName.trim(),
          'role': 'ADMIN',
          'active': 1,
          'password_salt': base64Encode(salt),
          'password_hash': base64Encode(hash),
          'failed_attempts': 0,
          'locked_until': null,
          'last_login_at': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await tx.update('users', {
          'display_name': displayName.trim(),
          'role': 'ADMIN',
          'active': 1,
          'password_salt': base64Encode(salt),
          'password_hash': base64Encode(hash),
          'failed_attempts': 0,
          'locked_until': null,
        }, where: 'id=?', whereArgs: [existing.first['id']]);
      }
    });
  }

  Future<AuthUser?> login(String username, String password) async {
    final rows = await db.query('users',
        where: 'username=?', whereArgs: [username.trim()], limit: 1);
    if (rows.isEmpty) {
      _derive(password, _randomBytes(16));
      return null;
    }
    final row = rows.first;
    if ((row['active'] as num?)?.toInt() != 1) {
      throw StateError('Esta cuenta está desactivada. Contacta al administrador.');
    }
    final lockedUntil = row['locked_until'] as String?;
    if (lockedUntil != null &&
        DateTime.tryParse(lockedUntil)?.isAfter(DateTime.now()) == true) {
      throw StateError('Cuenta bloqueada temporalmente. Intenta más tarde.');
    }
    final saltText = row['password_salt'] as String? ?? '';
    final hashText = row['password_hash'] as String? ?? '';
    if (saltText.isEmpty || hashText.isEmpty) {
      throw StateError('Esta cuenta aún no tiene contraseña. Solicita al administrador que la configure.');
    }
    final expected = base64Decode(hashText);
    final actual = _derive(password, base64Decode(saltText));
    if (!_constantTimeEquals(expected, actual)) {
      final attempts = ((row['failed_attempts'] as num?)?.toInt() ?? 0) + 1;
      final locked = attempts >= maxFailedAttempts
          ? DateTime.now().add(lockDuration).toIso8601String()
          : null;
      await db.update('users', {
        'failed_attempts': attempts >= maxFailedAttempts ? 0 : attempts,
        'locked_until': locked,
      }, where: 'id=?', whereArgs: [row['id']]);
      throw StateError(locked == null
          ? 'Usuario o contraseña incorrectos.'
          : 'Demasiados intentos. La cuenta se bloqueó durante 15 minutos.');
    }

    final now = DateTime.now();
    final token = _randomToken();
    await db.transaction((tx) async {
      await tx.update('auth_sessions', {
        'revoked_at': now.toIso8601String(),
      }, where: 'user_id=? AND revoked_at IS NULL', whereArgs: [row['id']]);
      await tx.update('users', {
        'failed_attempts': 0,
        'locked_until': null,
        'last_login_at': now.toIso8601String(),
      }, where: 'id=?', whereArgs: [row['id']]);
      await tx.insert('auth_sessions', {
        'user_id': row['id'],
        'token_hash': sha256.convert(utf8.encode(token)).toString(),
        'created_at': now.toIso8601String(),
        'last_seen_at': now.toIso8601String(),
        'expires_at': now.add(sessionLifetime).toIso8601String(),
        'revoked_at': null,
      });
    });
    await _secureStorage.write(key: sessionKey, value: token);
    return AuthUser.fromRow(row);
  }

  Future<AuthUser?> restoreSession() async {
    final token = await _secureStorage.read(key: sessionKey);
    if (token == null || token.isEmpty) return null;
    final digest = sha256.convert(utf8.encode(token)).toString();
    final rows = await db.rawQuery('''
      SELECT u.* , s.id session_id, s.last_seen_at, s.expires_at
      FROM auth_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.revoked_at IS NULL LIMIT 1
    ''', [digest]);
    if (rows.isEmpty) {
      await _secureStorage.delete(key: sessionKey);
      return null;
    }
    final row = rows.first;
    final now = DateTime.now();
    final lastSeen = DateTime.tryParse(row['last_seen_at'] as String? ?? '');
    final expires = DateTime.tryParse(row['expires_at'] as String? ?? '');
    final active = (row['active'] as num?)?.toInt() == 1;
    if (!active || expires == null || !expires.isAfter(now) ||
        lastSeen == null || now.difference(lastSeen) > idleLifetime) {
      await db.update('auth_sessions',
          {'revoked_at': now.toIso8601String()},
          where: 'id=?', whereArgs: [row['session_id']]);
      await _secureStorage.delete(key: sessionKey);
      return null;
    }
    await db.update('auth_sessions',
        {'last_seen_at': now.toIso8601String()},
        where: 'id=?', whereArgs: [row['session_id']]);
    return AuthUser.fromRow(row);
  }

  Future<void> touchSession() async {
    final token = await _secureStorage.read(key: sessionKey);
    if (token == null || token.isEmpty) {
      throw StateError('La sesión ya no está disponible.');
    }
    final digest = sha256.convert(utf8.encode(token)).toString();
    final rows = await db.rawQuery('''
      SELECT u.active, s.id session_id, s.expires_at, s.last_seen_at
      FROM auth_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.revoked_at IS NULL LIMIT 1
    ''', [digest]);
    if (rows.isEmpty) {
      await _secureStorage.delete(key: sessionKey);
      throw StateError('La sesión ya no es válida.');
    }
    final row = rows.first;
    final now = DateTime.now();
    final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
    final lastSeen = DateTime.tryParse(row['last_seen_at'] as String? ?? '');
    if ((row['active'] as num?)?.toInt() != 1 ||
        expiry == null || !expiry.isAfter(now) ||
        lastSeen == null || now.difference(lastSeen) > idleLifetime) {
      await db.update('auth_sessions',
          {'revoked_at': now.toIso8601String()},
          where: 'id=?', whereArgs: [row['session_id']]);
      await _secureStorage.delete(key: sessionKey);
      throw StateError('La sesión expiró por tiempo o inactividad.');
    }
    await db.update('auth_sessions',
        {'last_seen_at': now.toIso8601String()},
        where: 'id=?', whereArgs: [row['session_id']]);
  }

  Future<void> logout() async {
    final token = await _secureStorage.read(key: sessionKey);
    if (token != null && token.isNotEmpty) {
      final digest = sha256.convert(utf8.encode(token)).toString();
      await db.update('auth_sessions',
          {'revoked_at': DateTime.now().toIso8601String()},
          where: 'token_hash=? AND revoked_at IS NULL', whereArgs: [digest]);
    }
    await _secureStorage.delete(key: sessionKey);
  }

  Future<List<Map<String, Object?>>> loginOptions() async {
    return db.query(
      'users',
      columns: ['username', 'display_name', 'role'],
      where: "active=1 AND COALESCE(password_hash,'') != ''",
      orderBy: 'display_name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> users() async {
    await _requirePermission('users.manage');
    return db.rawQuery("""
      SELECT users.*,
        CASE WHEN users.id = (
          SELECT id FROM users WHERE UPPER(role)='ADMIN' ORDER BY id ASC LIMIT 1
        ) THEN 1 ELSE 0 END AS protected_admin
      FROM users
      ORDER BY display_name COLLATE NOCASE
    """);
  }

  Future<void> createUser({
    required String username,
    required String displayName,
    required String role,
    required String password,
  }) async {
    await _requirePermission('users.manage');
    _validateCredentials(username, displayName, password);
    final normalizedRole = role.toUpperCase();
    if (!rolePermissions.containsKey(normalizedRole)) {
      throw ArgumentError('Selecciona un rol válido.');
    }
    final salt = _randomBytes(16);
    await db.insert('users', {
      'username': username.trim(),
      'display_name': displayName.trim(),
      'role': normalizedRole,
      'active': 1,
      'password_salt': base64Encode(salt),
      'password_hash': base64Encode(_derive(password, salt)),
      'failed_attempts': 0,
      'locked_until': null,
      'last_login_at': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateUser({
    required int id,
    required String displayName,
    required String role,
    required bool active,
  }) async {
    await _requirePermission('users.manage');
    if (displayName.trim().isEmpty) throw ArgumentError('El nombre es obligatorio.');
    if (!rolePermissions.containsKey(role.toUpperCase())) {
      throw ArgumentError('Selecciona un rol válido.');
    }
    final rows = await db.query('users', columns: ['role'],
        where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Usuario no encontrado.');
    if (rows.first['role'] == 'ADMIN' && (!active || role.toUpperCase() != 'ADMIN')) {
      final admins = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM users WHERE role='ADMIN' AND active=1",
      )) ?? 0;
      if (admins <= 1) throw StateError('Debe existir al menos un administrador activo.');
    }
    await db.update('users', {
      'display_name': displayName.trim(),
      'role': role.toUpperCase(),
      'active': active ? 1 : 0,
    }, where: 'id=?', whereArgs: [id]);
    if (!active || rows.first['role'] != role.toUpperCase()) {
      await db.update('auth_sessions',
          {'revoked_at': DateTime.now().toIso8601String()},
          where: 'user_id=? AND revoked_at IS NULL', whereArgs: [id]);
    }
  }

  Future<void> deleteUser(int userId) async {
    await _requirePermission('users.manage');
    final token = await _secureStorage.read(key: sessionKey);
    if (token == null || token.isEmpty) {
      throw StateError('Inicia sesión para administrar usuarios.');
    }
    final digest = sha256.convert(utf8.encode(token)).toString();
    final sessionRows = await db.query(
      'auth_sessions',
      columns: ['user_id'],
      where: 'token_hash=? AND revoked_at IS NULL',
      whereArgs: [digest],
      limit: 1,
    );
    if (sessionRows.isEmpty) throw StateError('La sesión ya no es válida.');
    final currentUserId = sessionRows.first['user_id'] as int;
    if (userId == currentUserId) {
      throw StateError('No puedes eliminar la cuenta con la que tienes iniciada sesión.');
    }

    await db.transaction((tx) async {
      final targets = await tx.query(
        'users',
        columns: ['id', 'role', 'username'],
        where: 'id=?',
        whereArgs: [userId],
        limit: 1,
      );
      if (targets.isEmpty) throw StateError('Usuario no encontrado.');

      final target = targets.first;
      if ((target['role'] as String).toUpperCase() == 'ADMIN') {
        final originalAdmins = await tx.query(
          'users',
          columns: ['id'],
          where: "UPPER(role)='ADMIN'",
          orderBy: 'id ASC',
          limit: 1,
        );
        if (originalAdmins.isNotEmpty && originalAdmins.first['id'] == userId) {
          throw StateError('La cuenta administradora original está protegida y no se puede eliminar.');
        }
      }

      await tx.update(
        'inventory_price_history',
        {'changed_by': null},
        where: 'changed_by=?',
        whereArgs: [userId],
      );
      await tx.delete('auth_sessions', where: 'user_id=?', whereArgs: [userId]);
      final deleted = await tx.delete('users', where: 'id=?', whereArgs: [userId]);
      if (deleted != 1) throw StateError('No se pudo eliminar el usuario.');
    });
  }

  Future<void> resetPassword(int userId, String newPassword) async {
    await _requirePermission('users.manage');
    _validatePassword(newPassword);
    final salt = _randomBytes(16);
    final changed = await db.update('users', {
      'password_salt': base64Encode(salt),
      'password_hash': base64Encode(_derive(newPassword, salt)),
      'failed_attempts': 0,
      'locked_until': null,
    }, where: 'id=?', whereArgs: [userId]);
    if (changed == 0) throw StateError('Usuario no encontrado.');
    await db.update('auth_sessions',
        {'revoked_at': DateTime.now().toIso8601String()},
        where: 'user_id=? AND revoked_at IS NULL', whereArgs: [userId]);
  }


  Future<void> _requirePermission(String permission) async {
    final token = await _secureStorage.read(key: sessionKey);
    if (token == null || token.isEmpty) {
      throw StateError('Inicia sesión para administrar usuarios.');
    }
    final digest = sha256.convert(utf8.encode(token)).toString();
    final rows = await db.rawQuery('''
      SELECT u.role, u.active, s.expires_at, s.last_seen_at
      FROM auth_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.revoked_at IS NULL LIMIT 1
    ''', [digest]);
    if (rows.isEmpty) throw StateError('La sesión ya no es válida.');
    final row = rows.first;
    final now = DateTime.now();
    final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
    final lastSeen = DateTime.tryParse(row['last_seen_at'] as String? ?? '');
    if ((row['active'] as num?)?.toInt() != 1 ||
        expiry == null || !expiry.isAfter(now) ||
        lastSeen == null || now.difference(lastSeen) > idleLifetime ||
        !can(row['role'] as String, permission)) {
      throw StateError('No tienes permiso para realizar esta operación o tu sesión expiró.');
    }
    await db.update('auth_sessions', {'last_seen_at': now.toIso8601String()},
        where: 'token_hash=? AND revoked_at IS NULL', whereArgs: [digest]);
  }

  void _validateCredentials(String username, String displayName, String password) {
    if (username.trim().length < 3) throw ArgumentError('El usuario debe tener al menos 3 caracteres.');
    if (displayName.trim().isEmpty) throw ArgumentError('El nombre es obligatorio.');
    _validatePassword(password);
  }

  void _validatePassword(String password) {
    if (password.length != 6 ||
        password.codeUnits.any((digit) => digit < 48 || digit > 57)) {
      throw ArgumentError('El PIN debe contener exactamente 6 dígitos numéricos.');
    }
  }
  Uint8List _derive(String password, List<int> salt) {
    final key = utf8.encode(password);
    final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
    block[block.length - 1] = 1;
    final hmac = Hmac(sha256, key);
    var u = hmac.convert(block).bytes;
    final output = Uint8List.fromList(u);
    for (var i = 1; i < passwordIterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < output.length; j++) {
        output[j] ^= u[j];
      }
    }
    return output;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _randomToken() => base64UrlEncode(_randomBytes(32));
}
