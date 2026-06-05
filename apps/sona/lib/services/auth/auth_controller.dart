import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin [ChangeNotifier] wrapper over [FirebaseAuth] exposing the pieces the UI
/// and API client need (Auth·06). The login / set-password / magic-link screens
/// (Auth·12, Auth·13) build on this.
class AuthController extends ChangeNotifier {
  AuthController({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _sub = _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;
  User? _user;

  User? get user => _user;
  bool get isSignedIn => _user != null;

  /// Current Firebase ID token (used by [AuthedHttpClient] for API calls).
  Future<String?> idToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Creates a new email/password user and signs them in (admin sign-up,
  /// Auth·07).
  Future<UserCredential> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithPassword(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Sends a passwordless magic-link sign-in email (clinician login, Auth·12).
  Future<void> sendSignInLink(String email, ActionCodeSettings settings) =>
      _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: settings);

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
