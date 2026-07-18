import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:khuje_nao/activity_feed.dart';
import 'package:khuje_nao/admin_page.dart';
import 'package:khuje_nao/localization.dart';
import 'package:khuje_nao/main.dart';
import 'api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:khuje_nao/profile_completion_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final ApiService api_service = ApiService();
  final STORAGE = const FlutterSecureStorage();
  String language = 'en';
  bool is_loading = false;

  @override
  void initState() {
    super.initState();
    checkIfUserRemembered();
    loadLanguage();
  }

  Future<void> loadLanguage() async {
    String? stored_language = await STORAGE.read(key: 'language');
    setState(() {
      language = stored_language ?? 'en';
    });
  }

  Future<void> checkIfUserRemembered() async {
    final saved_email = await STORAGE.read(key: 'email');
    if (saved_email != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ActivityFeedPage()),
      );
    }
  }

  void showResponseDialog(String message_diag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(message_diag),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalization.getString(language, "okay")),
            ),
          ],
        );
      },
    );
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      is_loading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          is_loading = false;
        });
        return;
      }

      final email = googleUser.email;
      if (email == null || !email.endsWith('@northsouth.edu')) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Only @northsouth.edu email accounts are allowed. Please select your North South University account.");
        return;
      }

      final userExists = await api_service.checkUserExists(email);
      if (!userExists) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Account does not exist. Please sign up first.");
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Google sign-in failed: No access token.");
        return;
      }

      final response = await api_service.firebaseGoogleLogin(accessToken);
      if (response == null || response['session'] == null) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Google Sign-In backend verification failed.");
        return;
      }

      final profile = await api_service.getProfile(email);
      final isProfileComplete = profile != null && profile['profile_complete'] == true;

      await STORAGE.write(key: 'email', value: email);

      setState(() {
        is_loading = false;
      });

      if (!isProfileComplete) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileCompletionScreen(email: email)),
        );
        if (result == true && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ActivityFeedPage()));
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ActivityFeedPage()));
        }
      }
    } catch (e) {
      setState(() {
        is_loading = false;
      });
      showResponseDialog("Google Sign-In error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.getString(language, "login")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalization.getString(language, "go_home")),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_circle,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in with your\nNorth South University account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                if (is_loading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      label: const Text("Sign in with Google"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Select your @northsouth.edu Google account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
