import 'package:firebase_auth/firebase_auth.dart';

class AuthTokenProvider {
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return await user.getIdToken(forceRefresh);
  }
}
