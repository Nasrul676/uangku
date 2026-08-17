import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uangkeluar/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
  });

  test('password tidak pernah tersimpan sebagai plaintext', () async {
    await auth.register(
      name: 'Nasrul',
      email: 'a@b.com',
      password: 'rahasia123',
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getKeys().map((k) => '${prefs.get(k)}').join('|');

    expect(stored.contains('rahasia123'), isFalse);
    expect(prefs.getString('auth_password'), isNull);
    expect(prefs.getString('auth_password_hash'), isNotNull);
    expect(prefs.getString('auth_password_salt'), isNotNull);
  });

  test('login menerima password benar dan menolak yang salah', () async {
    await auth.register(name: 'N', email: 'a@b.com', password: 'rahasia123');

    expect(
      await auth.login(
        email: 'A@B.com',
        password: 'rahasia123',
        rememberMe: true,
      ),
      isTrue,
    );
    expect(
      await auth.login(
        email: 'a@b.com',
        password: 'rahasia124',
        rememberMe: true,
      ),
      isFalse,
    );
    expect(
      await auth.login(
        email: 'lain@b.com',
        password: 'rahasia123',
        rememberMe: true,
      ),
      isFalse,
    );
  });

  test(
    'salt berbeda tiap register, jadi hash tidak bisa dibandingkan',
    () async {
      await auth.register(name: 'N', email: 'a@b.com', password: 'sama');
      final prefs = await SharedPreferences.getInstance();
      final hash1 = prefs.getString('auth_password_hash');

      SharedPreferences.setMockInitialValues({});
      await AuthService().register(
        name: 'N',
        email: 'a@b.com',
        password: 'sama',
      );
      final hash2 = (await SharedPreferences.getInstance()).getString(
        'auth_password_hash',
      );

      expect(hash1, isNotNull);
      expect(hash2, isNotNull);
      expect(hash1, isNot(equals(hash2)));
    },
  );

  test('verifyPassword bekerja dan menolak string kosong', () async {
    await auth.register(name: 'N', email: 'a@b.com', password: 'rahasia123');

    expect(await auth.verifyPassword('rahasia123'), isTrue);
    expect(await auth.verifyPassword('salah'), isFalse);
    expect(await auth.verifyPassword(''), isFalse);
  });

  group('migrasi akun lama (plaintext)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_name': 'Lama',
        'auth_email': 'lama@b.com',
        'auth_password': 'passwordlama',
      });
      auth = AuthService();
    });

    test('login lama tetap berhasil lalu di-upgrade ke hash', () async {
      expect(
        await auth.login(
          email: 'lama@b.com',
          password: 'passwordlama',
          rememberMe: false,
        ),
        isTrue,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_password'), isNull);
      expect(prefs.getString('auth_password_hash'), isNotNull);

      // Setelah migrasi, login berikutnya memakai jalur hash.
      expect(
        await auth.login(
          email: 'lama@b.com',
          password: 'passwordlama',
          rememberMe: false,
        ),
        isTrue,
      );
      expect(
        await auth.login(
          email: 'lama@b.com',
          password: 'salah',
          rememberMe: false,
        ),
        isFalse,
      );
    });

    test('password salah tidak memicu migrasi', () async {
      expect(await auth.verifyPassword('salah'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_password'), 'passwordlama');
      expect(prefs.getString('auth_password_hash'), isNull);
    });
  });
}
