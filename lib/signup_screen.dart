import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:khuje_nao/login_screen.dart';
import 'activity_feed.dart';
import 'api_service.dart';
import 'localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:khuje_nao/profile_completion_screen.dart';

/// `SignupScreen` handles user sign-up via Google Sign-In only.
/// Users must select their @northsouth.edu Google account to sign up.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  SignupScreenState createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  /// The `ApiService` instance used to interact with the backend API for sign-up.
  final ApiService api_service = ApiService();

  /// Secure storage used to persist sensitive data such as the preferred language.
  final STORAGE = const FlutterSecureStorage();

  /// The current selected language (default is English).
  String language = 'en';

  /// Loading state for Google Sign-In
  bool is_loading = false;

  @override
  void initState() {
    super.initState();
    loadLanguage(); // Load the language preference from secure storage
  }

  /// Loads the preferred language from secure storage.
  Future<void> loadLanguage() async {
    String? stored_language = await STORAGE.read(key: 'language');
    setState(() {
      language = stored_language ?? 'en';
    });
  }

  /// Displays a response dialog with a custom message.
  ///
  /// [message_diag] is the message to be displayed in the dialog.
  void showResponseDialog(String message_diag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message_diag),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text(AppLocalization.getString(language, "okay")),
            ),
          ],
        );
      },
    );
  }

  /// Handles Google Sign-In for sign-up.
  /// Checks if user exists in database, if no - goes to profile completion, if yes - shows error.
  Future<void> signUpWithGoogle() async {
    setState(() {
      is_loading = true;
    });

    try {
      // Show account picker (all Google accounts on device)
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          is_loading = false;
        });
        return; // User cancelled
      }

      final email = googleUser.email;
      if (email == null || !email.endsWith('@northsouth.edu')) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Only @northsouth.edu email accounts are allowed. Please select your North South University account.");
        return;
      }

      // Check if user already exists in database
      final userExists = await api_service.checkUserExists(email);
      if (userExists) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("An account with this email already exists. Please sign in instead.");
        return;
      }

      // User doesn't exist - proceed with backend authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Google sign-in failed: No access token.");
        return;
      }

      // Verify with backend (this will create a placeholder profile)
      final response = await api_service.firebaseGoogleLogin(accessToken);
      if (response == null || response['session'] == null) {
        setState(() {
          is_loading = false;
        });
        showResponseDialog("Google Sign-In backend verification failed.");
        return;
      }

      // Store email for session
      await STORAGE.write(key: 'email', value: email);

      setState(() {
        is_loading = false;
      });

      // Navigate to profile completion screen with email
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileCompletionScreen(email: email)),
      );
      
      if (result == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ActivityFeedPage()),
        );
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalization.getString(language, "signup"))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.person_add,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Create your account\nwith North South University',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Select your @northsouth.edu Google account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              if (is_loading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: signUpWithGoogle,
                  icon: const Icon(Icons.account_circle),
                  label: const Text("Sign up with Google"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
