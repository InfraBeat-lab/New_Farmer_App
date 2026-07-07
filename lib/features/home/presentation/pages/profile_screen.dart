import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/farm_settings_api_service.dart';
import 'package:poultryos_farmer_app/core/services/farmer_api_service.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/core/widgets/powered_by_footer.widget.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  final _userCodeCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  final _farmerNameCtrl = TextEditingController();

  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();

  final _currencyCodeCtrl = TextEditingController(text: 'INR');
  final _timezoneCtrl = TextEditingController(text: 'Asia/Kolkata');
  final _languageCtrl = TextEditingController(text: 'en');

  final List<Map<String, dynamic>> _countriesList = [
    {'id': 1, 'name': 'India', 'currency': 'INR', 'timezone': 'Asia/Kolkata'},
    {'id': 2, 'name': 'United States', 'currency': 'USD', 'timezone': 'America/New_York'},
    {'id': 3, 'name': 'United Kingdom', 'currency': 'GBP', 'timezone': 'Europe/London'},
    {'id': 4, 'name': 'Australia', 'currency': 'AUD', 'timezone': 'Australia/Sydney'},
    {'id': 5, 'name': 'Canada', 'currency': 'CAD', 'timezone': 'America/Toronto'},
    {'id': 6, 'name': 'Germany', 'currency': 'EUR', 'timezone': 'Europe/Berlin'},
    {'id': 7, 'name': 'France', 'currency': 'EUR', 'timezone': 'Europe/Paris'},
    {'id': 8, 'name': 'Japan', 'currency': 'JPY', 'timezone': 'Asia/Tokyo'},
    {'id': 9, 'name': 'China', 'currency': 'CNY', 'timezone': 'Asia/Shanghai'},
    {'id': 10, 'name': 'UAE', 'currency': 'AED', 'timezone': 'Asia/Dubai'},
    {'id': 11, 'name': 'Saudi Arabia', 'currency': 'SAR', 'timezone': 'Asia/Riyadh'},
    {'id': 12, 'name': 'Singapore', 'currency': 'SGD', 'timezone': 'Asia/Singapore'},
    {'id': 13, 'name': 'South Africa', 'currency': 'ZAR', 'timezone': 'Africa/Johannesburg'},
    {'id': 14, 'name': 'Brazil', 'currency': 'BRL', 'timezone': 'America/Sao_Paulo'},
    {'id': 15, 'name': 'Mexico', 'currency': 'MXN', 'timezone': 'America/Mexico_City'},
  ];

  int? _selectedCountryId;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  void _loadSavedValues() {
    _userCodeCtrl.text = LocalStorageService.getString('user_code') ?? '';
    _userNameCtrl.text = LocalStorageService.getString('full_name') ?? LocalStorageService.getString('display_name') ?? '';
    _farmerNameCtrl.text = LocalStorageService.getString('farm_name') ?? '';
    _mobileCtrl.text = LocalStorageService.getString('mobile') ?? '';
    _emailCtrl.text = LocalStorageService.getString('email') ?? '';
    _addressCtrl.text = LocalStorageService.getString('address') ?? '';
    _cityCtrl.text = LocalStorageService.getString('city') ?? '';
    _pincodeCtrl.text = LocalStorageService.getString('pin_code') ?? '';
    _gstCtrl.text = LocalStorageService.getString('gst') ?? '';
    _panCtrl.text = LocalStorageService.getString('pan') ?? '';
    
    _currencyCodeCtrl.text = LocalStorageService.getString('currency_code') ?? 'INR';
    _timezoneCtrl.text = LocalStorageService.getString('timezone') ?? 'Asia/Kolkata';
    _languageCtrl.text = LocalStorageService.getString('language') ?? 'en';
    
    _selectedCountryId = LocalStorageService.getInt('country_id');
    if (_selectedCountryId == null) {
      final savedCountry = LocalStorageService.getString('country');
      if (savedCountry != null) {
        final match = _countriesList.firstWhere(
          (c) => (c['name'] as String).toLowerCase() == savedCountry.toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          _selectedCountryId = match['id'] as int;
        }
      }
    }
    _selectedCountryId ??= 1;
  }

  void _skipProfile() async {
    FocusScope.of(context).unfocus();
    await LocalStorageService.setBool('profile_completed', true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile setup skipped.'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 1),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.go('/');
    });
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoading) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. CREATE FARMER
      final farmerResponse = await FarmerApiService.createFarmer(
        farmerName: _farmerNameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        countryId: _selectedCountryId,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        pincode:
            _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      );

      if (farmerResponse['success'] != true) {
        throw Exception(farmerResponse['message'] ?? 'Failed to create farmer');
      }

      final farmerId = farmerResponse['data']['id'];

      // 2. CREATE SETTINGS
      final settingsResponse = await FarmSettingsApiService.createSettings(
        farmerId: farmerId,
        currencyCode: _currencyCodeCtrl.text.trim(),
        languageCode: _languageCtrl.text.trim(),
        timezone: _timezoneCtrl.text.trim(),
      );

      if (settingsResponse['success'] != true) {
        throw Exception(
            settingsResponse['message'] ?? 'Failed to save settings');
      }

      // 3. SAVE LOCALLY
      await LocalStorageService.setInt('farmer_id', farmerId);
      await LocalStorageService.setBool('profile_completed', true);

      // Cache all values locally
      await LocalStorageService.setString('full_name', _userNameCtrl.text.trim());
      await LocalStorageService.setString('display_name', _userNameCtrl.text.trim());
      await LocalStorageService.setString('farm_name', _farmerNameCtrl.text.trim());
      await LocalStorageService.setString('mobile', _mobileCtrl.text.trim());
      await LocalStorageService.setString('email', _emailCtrl.text.trim());
      await LocalStorageService.setString('address', _addressCtrl.text.trim());
      await LocalStorageService.setString('city', _cityCtrl.text.trim());
      await LocalStorageService.setString('pin_code', _pincodeCtrl.text.trim());
      await LocalStorageService.setString('gst', _gstCtrl.text.trim());
      await LocalStorageService.setString('pan', _panCtrl.text.trim());
      await LocalStorageService.setString('currency_code', _currencyCodeCtrl.text.trim());
      await LocalStorageService.setString('language', _languageCtrl.text.trim());
      await LocalStorageService.setString('timezone', _timezoneCtrl.text.trim());
      if (_selectedCountryId != null) {
        await LocalStorageService.setInt('country_id', _selectedCountryId!);
        final countryMatch = _countriesList.firstWhere(
          (c) => c['id'] == _selectedCountryId,
          orElse: () => {},
        );
        if (countryMatch.isNotEmpty) {
          await LocalStorageService.setString('country', countryMatch['name'] as String);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );

      context.go('/');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _userCodeCtrl.dispose();
    _userNameCtrl.dispose();
    _farmerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _timezoneCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  // ---- Helpers ----
  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey600,
                  letterSpacing: 0.5)),
        ]),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool mandatory = false,
    bool disabled = false,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? prefixText,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: !disabled,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: mandatory ? '$label *' : label,
        prefixIcon: Icon(icon,
            color: disabled ? AppTheme.grey400 : AppTheme.primaryRed),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        filled: disabled,
        fillColor: disabled ? AppTheme.grey100 : null,
        labelStyle: TextStyle(color: disabled ? AppTheme.grey400 : null),
      ),
      style: TextStyle(color: disabled ? AppTheme.grey500 : null),
      validator: validator ??
          (mandatory
              ? (v) =>
                  v == null || v.trim().isEmpty ? '$label is required' : null
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = LocalStorageService.getBool('profile_completed') == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (!isCompleted)
            TextButton.icon(
              onPressed: _skipProfile,
              icon: const Icon(Icons.skip_next_outlined, color: Colors.white),
              label: const Text('Skip',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Column(children: [
                Icon(Icons.account_circle_outlined,
                    size: 60, color: Colors.white),
                SizedBox(height: 10),
                Text('Setup Your Farm Profile',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Fields marked * are mandatory',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFFFDE8E8))),
              ]),
            ),
            const SizedBox(height: 20),

            // Form card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius16)),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── IDENTITY ──────────────────────────────
                        _sectionLabel('USER ACCOUNT'),

                        _field(
                          ctrl: _userCodeCtrl,
                          label: 'User Code',
                          icon: Icons.vpn_key_outlined,
                          disabled: true,
                        ),

                        SizedBox(height: 8),

                        _field(
                          ctrl: _userNameCtrl,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          mandatory: true,
                        ),

                        SizedBox(height: 8),

                        _field(
                          ctrl: _mobileCtrl,
                          label: 'Mobile Number',
                          icon: Icons.phone_android_outlined,
                          mandatory: true,
                          keyboard: TextInputType.phone,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                          validator: (v) {
                            final val = v ?? '';
                            if (val.trim().isEmpty) return 'Mobile Number is required';
                            if (!RegExp(r'^\d{10}$').hasMatch(val.trim())) {
                              return 'Enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 8),

                        _field(
                          ctrl: _emailCtrl,
                          label: 'Email Address',
                          icon: Icons.mail_outline,
                          mandatory: false,
                          validator: (v) {
                            final val = v ?? '';
                            if (val.trim().isEmpty) return null; // Optional
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 28),

                        _sectionLabel('FARMER PROFILE'),

                        _field(
                            ctrl: _farmerNameCtrl,
                            label: 'Farm Name',
                            icon: Icons.agriculture,
                            mandatory: true),

                        SizedBox(height: 8),

                        DropdownButtonFormField<int>(
                          value: _selectedCountryId,
                          decoration: const InputDecoration(
                            labelText: 'Country *',
                            prefixIcon: Icon(Icons.public, color: AppTheme.primaryRed),
                          ),
                          items: _countriesList.map((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name'] as String),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCountryId = val;
                                final countryData = _countriesList.firstWhere((c) => c['id'] == val);
                                _currencyCodeCtrl.text = countryData['currency'] as String;
                                _timezoneCtrl.text = countryData['timezone'] as String;
                              });
                            }
                          },
                          validator: (v) => v == null ? 'Country is required' : null,
                        ),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _addressCtrl,
                            label: 'Address',
                            icon: Icons.location_on),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _cityCtrl,
                            label: 'City',
                            icon: Icons.location_city),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _pincodeCtrl,
                            label: 'Pincode',
                            icon: Icons.pin_drop),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _gstCtrl,
                            label: 'GST Number',
                            icon: Icons.receipt),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _panCtrl,
                            label: 'PAN Number',
                            icon: Icons.badge),

                        const SizedBox(height: 28),

                        _sectionLabel('FARM SETTINGS'),

                        _field(
                            ctrl: _currencyCodeCtrl,
                            label: 'Currency',
                            icon: Icons.currency_exchange),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _languageCtrl,
                            label: 'Language',
                            icon: Icons.language),

                        SizedBox(height: 8),

                        _field(
                            ctrl: _timezoneCtrl,
                            label: 'Timezone',
                            icon: Icons.schedule),

                        const SizedBox(height: 28),

                        // Save button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save & Continue',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        )
                      ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const PoweredByFooter(),
          ]),
        ),
      ),
    );
  }
}
