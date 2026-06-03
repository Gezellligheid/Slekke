import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../core/config/google_oauth_config.dart';
import '../models/user_model.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? GoogleOAuthConfig.webClientId : null,
  );
  final _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<UserCredential?> signInWithGoogle() async {
    UserCredential result;

    if (_isDesktop) {
      result = await _signInWithGoogleDesktop();
    } else {
      // Android / iOS / Web / macOS: use google_sign_in plugin
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      result = await _auth.signInWithCredential(credential);
    }

    // Upsert user profile in Firestore
    await _firestore.collection('users').doc(result.user!.uid).set({
      'displayName': result.user!.displayName ?? '',
      'email': result.user!.email ?? '',
      'photoUrl': result.user!.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return result;
  }

  // Opens the system browser → local callback server → exchanges code for token
  Future<UserCredential> _signInWithGoogleDesktop() async {
    const clientId = GoogleOAuthConfig.clientId;
    const clientSecret = GoogleOAuthConfig.clientSecret;

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'response_type': 'code',
      'scope': 'openid email profile',
      'redirect_uri': 'http://localhost',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    // flutter_web_auth_2 starts a local HTTP server, opens the browser,
    // and returns the full callback URL once Google redirects back.
    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: 'http',
    );

    final code = Uri.parse(callbackUrl).queryParameters['code'];
    if (code == null) throw Exception('Google OAuth: no code in callback');

    // Exchange auth code for tokens
    final tokenResponse = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'redirect_uri': 'http://localhost',
        'grant_type': 'authorization_code',
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Token exchange failed: ${tokenResponse.body}');
    }

    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final credential = GoogleAuthProvider.credential(
      idToken: tokenData['id_token'] as String?,
      accessToken: tokenData['access_token'] as String?,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (_isDesktop) {
      await _auth.signOut();
    } else {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }
}
