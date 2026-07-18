import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class GooglePhoneOnboarding extends StatefulWidget {
  const GooglePhoneOnboarding({super.key});

  @override
  State<GooglePhoneOnboarding> createState() => _GooglePhoneOnboardingState();
}

class _GooglePhoneOnboardingState extends State<GooglePhoneOnboarding> {
  final _nameCtrl = TextEditingController();
  final _nsuCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  bool _googleDone = false;
  String _status = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nsuCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String msg) => setState(() => _status = msg);

  Future<void> _continueWithGoogle() async {
    setState(() { _loading = true; _status = ''; });
    try {
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      if (gUser == null) {
        _setStatus('Google sign-in canceled');
        return;
      }

      final email = gUser.email;
      if (email == null || !email.endsWith('@northsouth.edu')) {
        _setStatus('Only @northsouth.edu email accounts are allowed.');
        return;
      }

      final gAuth = await gUser.authentication;
      final accessToken = gAuth.accessToken;
      if (accessToken == null) {
        _setStatus('Google sign-in failed: No access token.');
        return;
      }

      final response = await _api.firebaseGoogleLogin(accessToken);
      if (response == null || response['session'] == null) {
        _setStatus('Google Sign-In backend verification failed.');
        return;
      }

      await _storage.write(key: 'email', value: email);

      setState(() {
        _googleDone = true;
      });
      _setStatus('Google signed in. Complete your profile.');
    } catch (e) {
      _setStatus('Google sign-in error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // OTP removed

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final nsu = int.tryParse(_nsuCtrl.text.trim()) ?? 0;
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || nsu <= 0 || phone.isEmpty) {
      _setStatus('Enter name, NSU ID and phone.');
      return;
    }
    setState(() { _loading = true; _status = ''; });
    try {
      final saved = await _api.completeProfile(
        name: name,
        nsuId: nsu,
        phone: phone,
      );
      if (!saved) {
        _setStatus('Server profile save failed.');
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _googleDone && !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete profile (Google)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _continueWithGoogle,
              child: const Text('Continue with Google'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name (required)'),
            ),
            TextField(
              controller: _nsuCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NSU ID (required)'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (required)'),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: canSave ? _saveProfile : null,
              child: const Text('Save profile'),
            ),

            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_status.isNotEmpty)
              Text(_status, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
