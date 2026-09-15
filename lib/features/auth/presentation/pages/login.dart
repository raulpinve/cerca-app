import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _loading = true;
      });

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('No se pudo obtener el usuario.');
      }

      // Forzar renovación del Firebase ID Token
      final String? idToken = await user.getIdToken(true);

      if (idToken == null) {
        throw Exception('No se pudo obtener el token de Firebase.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error Firebase: ${e.message}');
    } catch (e) {
      debugPrint('Error al iniciar sesión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _loading ? null : _signInWithGoogle,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(),
                )
              : const Text('Continuar con Google'),
        ),
      ),
    );
  }
}
