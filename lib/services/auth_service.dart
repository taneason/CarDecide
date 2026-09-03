import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Email & Password Sign Up
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(email: email, password: password);
    return response;
  }

  Future<void> signInWithGoogle() async {

    const webClientId = '802858394897-j3ugjq7opjtcfck6pfs1t2o4kbtkong5.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn(
      clientId: webClientId,
      serverClientId: webClientId,
    );
    final googleUser = await googleSignIn.signIn();
    final googleAuth = await googleUser!.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null || idToken == null) {
      throw 'No Access Token or ID Token found.';
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> sendPasswordResetOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> sendOtp(String email, {bool shouldCreateUser = true}) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: shouldCreateUser,
    );
  }

  Future<AuthResponse> verifyOtp(String email, String token, {bool isRecovery = false}) async {
    if (isRecovery) {
      return await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
    }
    try {
      return await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } catch (e) {
      return await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}


