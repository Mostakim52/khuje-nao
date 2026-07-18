import 'package:flutter/material.dart';
import 'api_service.dart';
import 'localization.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Screen to complete user profile after Google Sign-In.
/// Collects NSU ID and phone number which are not provided by Google.
class ProfileCompletionScreen extends StatefulWidget {
  final String email;
  
  const ProfileCompletionScreen({super.key, required this.email});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _nameCtrl = TextEditingController();
  final _nsuCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  
  bool _loading = false;
  String _status = '';
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _prefillData();
  }

  Future<void> _loadLanguage() async {
    final lang = await _storage.read(key: 'language');
    setState(() {
      _language = lang ?? 'en';
    });
  }

  Future<void> _prefillData() async {
    // Try to get existing profile data
    final profile = await _api.getProfile(widget.email);
    if (profile != null) {
      if (profile['name'] != null) _nameCtrl.text = profile['name'];
      if (profile['nsu_id'] != null) _nsuCtrl.text = profile['nsu_id'].toString();
      if (profile['phone_number'] != null) _phoneCtrl.text = profile['phone_number'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nsuCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String msg) => setState(() => _status = msg);

  bool _validateNsuId(String value) {
    // NSU ID format: 2 digits, then 1-3, then 4 digits (e.g., 1234567, 2234567, 3234567)
    final nsuIdRegExp = RegExp(r'^\d{2}[1-3]\d{4}$');
    return nsuIdRegExp.hasMatch(value);
  }

  bool _validatePhone(String value) {
    // Bangladesh phone format: optional +88/88 prefix, then 01[3-9] followed by 8 digits
    final phoneRegExp = RegExp(r'^(?:\+88|88)?(01[3-9]\d{8})$');
    return phoneRegExp.hasMatch(value);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameCtrl.text.trim();
    final nsuStr = _nsuCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    
    final nsu = int.tryParse(nsuStr);
    if (nsu == null || !_validateNsuId(nsuStr)) {
      _setStatus('Invalid NSU ID format. Example: 1234567');
      return;
    }
    
    if (!_validatePhone(phone)) {
      _setStatus('Invalid phone number format. Use: 01XXXXXXXXX or +8801XXXXXXXXX');
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final saved = await _api.completeProfile(
        name: name,
        nsuId: nsu,
        phone: phone,
      );
      
      if (!saved) {
        _setStatus('Failed to save profile. Please try again.');
        return;
      }
      
      // Success - navigate back
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _setStatus('Error: $e');
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
      appBar: AppBar(
        title: Text(AppLocalization.getString(_language, "complete_profile")),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email (from Google):',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalization.getString(_language, "name") + ' *',
                  hintText: 'Your full name',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nsuCtrl,
                decoration: InputDecoration(
                  labelText: 'NSU ID *',
                  hintText: 'e.g., 1234567',
                  border: const OutlineInputBorder(),
                  helperText: 'Format: 7 digits (e.g., 1234567)',
                ),
                keyboardType: TextInputType.number,
                maxLength: 7,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'NSU ID is required';
                  }
                  if (!_validateNsuId(value.trim())) {
                    return 'Invalid NSU ID format. Must be 7 digits (e.g., 1234567)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalization.getString(_language, "phone") + ' *',
                  hintText: '01XXXXXXXXX or +8801XXXXXXXXX',
                  border: const OutlineInputBorder(),
                  helperText: 'Bangladesh phone number format',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (!_validatePhone(value.trim())) {
                    return 'Invalid phone format. Use: 01XXXXXXXXX or +8801XXXXXXXXX';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalization.getString(_language, "save_profile")),
              ),
              
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _status,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              Text(
                '* Required fields. Google Sign-In does not provide NSU ID or phone number, so we need to collect this information.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
