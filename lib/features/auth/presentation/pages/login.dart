import 'package:app/core/services/app_location_controller.dart';
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
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _loading = true;
        _errorMessage = null;
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

      // Login de Firebase OK → ahora vinculamos/registramos el device.
      // Si esto falla (sin red, backend caído), no deshacemos el login:
      // el usuario ya quedó autenticado y el DeviceLinkGate lo va a
      // mandar a la pantalla de "Dispositivo no vinculado", donde
      // puede reintentar con el botón sin tener que volver a loguearse.
      final linked = await AppLocationController.instance
          .registerDeviceOnLogin();

      if (!linked) {
        debugPrint(
          'Login OK pero no se pudo vincular el dispositivo, '
          'el DeviceLinkGate mostrará la pantalla de reintento.',
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error Firebase: ${e.message}');
      setState(() => _errorMessage = 'No se pudo iniciar sesión.');
    } catch (e) {
      debugPrint('Error al iniciar sesión: $e');
      setState(() => _errorMessage = 'No se pudo iniciar sesión.');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _signInWithGoogle,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Continuar con Google'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
