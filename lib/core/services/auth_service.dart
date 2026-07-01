import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:poultryos_farmer_app/core/services/database_service.dart';

class GoogleAuthResult {
  final bool success;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? errorMessage;
  final bool isMock;

  GoogleAuthResult({
    required this.success,
    this.email,
    this.displayName,
    this.photoUrl,
    this.errorMessage,
    this.isMock = false,
  });
}

class AuthService {
  // static Future<void> _ensureInitialized() async {
  //   final clientId = dotenv.env['GOOGLE_CLIENT_ID'];
  //   await GoogleSignIn.instance.initialize(
  //     clientId: clientId,
  //   );
  // }
  static Future<void> _ensureInitialized() async {
    final clientId = dotenv.env['IOS_CLIENT_ID'];
    final serverClientId = dotenv.env['WEB_CLIENT_ID'];

    await GoogleSignIn.instance.initialize(
      clientId: clientId, // iOS only
      serverClientId: serverClientId, // Required for Android
    );
  }

  /// Performs Google Sign-In.
  /// On successful authentication, it connects to PostgreSQL to insert/update the user records.
  static Future<GoogleAuthResult> signInWithGoogle(
      {bool allowMockFallback = true}) async {
    try {
      debugPrint('Initiating Google Sign-In process...');

      await _ensureInitialized();

      // Clear any previous sign in state to force account selection
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Error signing out of Google: $e');
      }

      final GoogleSignInAccount? account =
          await GoogleSignIn.instance.authenticate();

      if (account == null) {
        debugPrint('Google Sign-In canceled by user.');
        return GoogleAuthResult(
          success: false,
          errorMessage: 'Sign-In canceled by user.',
        );
      }

      final String email = account.email;
      final String displayName = account.displayName ?? 'Google User';
      final String photoUrl = account.photoUrl ?? '';

      debugPrint('Google Sign-In succeeded for: $email');

      // Now attempt to insert/update user in PostgreSQL database
      bool dbSuccess = false;
      String? dbError;
      try {
        await DatabaseService.insertOrUpdateUser(
          email: email,
          name: displayName,
          photoUrl: photoUrl,
          role: 'Farmer',
        );
        dbSuccess = true;
      } catch (e) {
        dbError = e.toString();
        debugPrint('PostgreSQL insertion failed during Google login: $e');
      }

      return GoogleAuthResult(
        success: true,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        errorMessage: dbSuccess
            ? null
            : 'Google Login succeeded, but database sync failed: $dbError',
      );
    } catch (error) {
      debugPrint('Google Sign-In failed with error: $error');

      if (allowMockFallback) {
        debugPrint(
            'Falling back to Mock Google User for development/testing...');

        const String mockEmail = 'mock.farmer@gmail.com';
        const String mockName = 'Mock Farmer Dev';
        const String mockPhoto =
            'https://api.dicebear.com/7.x/adventurer/svg?seed=mock';

        bool dbSuccess = false;
        String? dbError;
        try {
          await DatabaseService.insertOrUpdateUser(
            email: mockEmail,
            name: mockName,
            photoUrl: mockPhoto,
            role: 'Farmer',
          );
          dbSuccess = true;
        } catch (e) {
          dbError = e.toString();
          debugPrint(
              'PostgreSQL insertion failed during Mock Google login: $e');
        }

        return GoogleAuthResult(
          success: true,
          email: mockEmail,
          displayName: mockName,
          photoUrl: mockPhoto,
          isMock: true,
          errorMessage: dbSuccess
              ? null
              : 'Mock Login succeeded, but database sync failed: $dbError',
        );
      }

      return GoogleAuthResult(
        success: false,
        errorMessage: error.toString(),
      );
    }
  }

  /// Logs out the user from Google Sign-In and closes PostgreSQL connection.
  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      debugPrint('Signed out from Google.');
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }

    try {
      await DatabaseService.close();
    } catch (e) {
      debugPrint('Error closing PostgreSQL connection: $e');
    }
  }
}
