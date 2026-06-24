import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String _webClientId =
      '834121133893-rgpd5c7cv4htn5io7q4k6siltg15fo1r.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: _webClientId,
              scopes: const <String>['email', 'profile'],
            );

  // Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } on PlatformException catch (e) {
      throw _handleGoogleSignInError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        await _googleSignIn.signOut();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Update profile display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Ensure signed in (for anonymous users)
  Future<User> ensureSignedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    final result = await _auth.signInAnonymously();
    if (result.user == null) {
      throw StateError('Anonymous sign-in failed.');
    }
    return result.user!;
  }

  // Handle Firebase auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This authentication method is not enabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  String _handleGoogleSignInError(PlatformException e) {
    final details = e.details?.toString() ?? '';
    final message = e.message ?? '';
    final combined = '$message $details';

    if (e.code == 'sign_in_canceled' || e.code == 'network_error') {
      return 'Google sign-in could not complete. Please try again.';
    }
    if (e.code == 'sign_in_failed' && combined.contains('ApiException: 10')) {
      return 'Google sign-in is not configured for this production build. Add the release or Play App Signing SHA-1 and SHA-256 fingerprints for com.leafsnap.ai in Firebase, then download the updated google-services.json.';
    }
    if (e.code == 'sign_in_failed') {
      return 'Google sign-in failed. Please try again or use email sign-in.';
    }
    return 'Google sign-in could not complete. Please try again.';
  }
}
