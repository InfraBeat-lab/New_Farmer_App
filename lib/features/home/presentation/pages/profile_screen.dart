import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/core/widgets/powered_by_footer.widget.dart';

// Country → Currency map
const Map<String, String> _countryCurrencyMap = {
  'India': '₹ INR',
  'United States': '\$ USD',
  'United Kingdom': '£ GBP',
  'Australia': 'A\$ AUD',
  'Canada': 'C\$ CAD',
  'Germany': '€ EUR',
  'France': '€ EUR',
  'Japan': '¥ JPY',
  'China': '¥ CNY',
  'UAE': 'AED',
  'Saudi Arabia': 'SAR',
  'Singapore': 'S\$ SGD',
  'South Africa': 'R ZAR',
  'Brazil': 'R\$ BRL',
  'Mexico': 'Mex\$ MXN',
};

const List<String> _countries = [
  'India',
  'United States',
  'United Kingdom',
  'Australia',
  'Canada',
  'Germany',
  'France',
  'Japan',
  'China',
  'UAE',
  'Saudi Arabia',
  'Singapore',
  'South Africa',
  'Brazil',
  'Mexico',
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _farmerIdCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _farmsCtrl = TextEditingController();
  final _shedsCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _deviceIdCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: '₹ INR');

  String _selectedCountry = 'India';
  String _selectedRole = 'Admin';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _generateFarmerId();
    _generateDeviceId();
    _loadSavedValues();
  }

  void _generateFarmerId() {
    final existingId = LocalStorageService.getString('farmer_id');
    if (existingId != null && existingId.isNotEmpty) {
      _farmerIdCtrl.text = existingId;
    } else {
      final rnd = Random().nextInt(90000) + 10000;
      _farmerIdCtrl.text = 'FRM-$rnd';
    }
  }

  void _generateDeviceId() {
    final existingDevice = LocalStorageService.getString('device_id');
    if (existingDevice != null && existingDevice.isNotEmpty) {
      _deviceIdCtrl.text = existingDevice;
    } else {
      // Use kIsWeb + defaultTargetPlatform (works on all platforms including web)
      String platform;
      if (kIsWeb) {
        platform = 'WEB';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            platform = 'AND';
            break;
          case TargetPlatform.iOS:
            platform = 'IOS';
            break;
          default:
            platform = 'OTH';
        }
      }
      final rnd = Random().nextInt(900000000) + 100000000;
      _deviceIdCtrl.text = '$platform-$rnd';
    }
  }

  void _loadSavedValues() {
    _zipCtrl.text = LocalStorageService.getString('zip_code') ?? '';
    _mobileCtrl.text = LocalStorageService.getString('mobile_number') ?? '';
    _emailCtrl.text = LocalStorageService.getString('email') ?? '';
    _fullNameCtrl.text = LocalStorageService.getString('full_name') ?? '';
    _addressCtrl.text = LocalStorageService.getString('address') ?? '';
    _stateCtrl.text = LocalStorageService.getString('state') ?? '';
    _farmsCtrl.text = LocalStorageService.getString('farms') ?? '';
    _shedsCtrl.text = LocalStorageService.getString('sheds') ?? '';
    _passwordCtrl.text = LocalStorageService.getString('password') ?? '';
    _selectedRole = LocalStorageService.getString('role') ?? 'Admin';
    final savedCountry = LocalStorageService.getString('country') ?? 'India';
    if (_countries.contains(savedCountry)) {
      _selectedCountry = savedCountry;
      _currencyCtrl.text = _countryCurrencyMap[savedCountry] ?? '₹ INR';
    }
  }

  void _onCountryChanged(String? country) {
    if (country == null) return;
    setState(() {
      _selectedCountry = country;
      _currencyCtrl.text = _countryCurrencyMap[country] ?? '-';
    });
  }

  void _skipProfile() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      await LocalStorageService.setString('farmer_id', _farmerIdCtrl.text.trim());
      await LocalStorageService.setString('full_name', _fullNameCtrl.text.trim());
      await LocalStorageService.setString('mobile_number', _mobileCtrl.text.trim());
      await LocalStorageService.setString('email', _emailCtrl.text.trim());
      await LocalStorageService.setString('zip_code', _zipCtrl.text.trim());
      await LocalStorageService.setString('address', _addressCtrl.text.trim());
      await LocalStorageService.setString('country', _selectedCountry);
      await LocalStorageService.setString('currency', _currencyCtrl.text.trim());
      await LocalStorageService.setString('state', _stateCtrl.text.trim());
      await LocalStorageService.setString('farms', _farmsCtrl.text.trim());
      await LocalStorageService.setString('sheds', _shedsCtrl.text.trim());
      await LocalStorageService.setString('password', _passwordCtrl.text.trim());
      await LocalStorageService.setString('role', _selectedRole);
      await LocalStorageService.setString('device_id', _deviceIdCtrl.text.trim());
      await LocalStorageService.setString('session_id', 'dummy_session_id');
      await LocalStorageService.setInt('IsLogin', 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Optional fields skipped. Profile saved!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 1),
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        context.go('/');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill mandatory fields before skipping.'),
          backgroundColor: AppTheme.primaryRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      await LocalStorageService.setString('farmer_id', _farmerIdCtrl.text.trim());
      await LocalStorageService.setString('full_name', _fullNameCtrl.text.trim());
      await LocalStorageService.setString('mobile_number', _mobileCtrl.text.trim());
      await LocalStorageService.setString('email', _emailCtrl.text.trim());
      await LocalStorageService.setString('zip_code', _zipCtrl.text.trim());
      await LocalStorageService.setString('address', _addressCtrl.text.trim());
      await LocalStorageService.setString('country', _selectedCountry);
      await LocalStorageService.setString('currency', _currencyCtrl.text.trim());
      await LocalStorageService.setString('state', _stateCtrl.text.trim());
      await LocalStorageService.setString('farms', _farmsCtrl.text.trim());
      await LocalStorageService.setString('sheds', _shedsCtrl.text.trim());
      await LocalStorageService.setString('password', _passwordCtrl.text.trim());
      await LocalStorageService.setString('role', _selectedRole);
      await LocalStorageService.setString('device_id', _deviceIdCtrl.text.trim());
      await LocalStorageService.setString('session_id', 'dummy_session_id');
      await LocalStorageService.setInt('IsLogin', 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 1),
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        context.go('/');
      });
    }
  }

  @override
  void dispose() {
    _farmerIdCtrl.dispose();
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _zipCtrl.dispose();
    _addressCtrl.dispose();
    _stateCtrl.dispose();
    _farmsCtrl.dispose();
    _shedsCtrl.dispose();
    _passwordCtrl.dispose();
    _deviceIdCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  // ---- Helpers ----
  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.grey600, letterSpacing: 0.5)),
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
        prefixIcon: Icon(icon, color: disabled ? AppTheme.grey400 : AppTheme.primaryRed),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        filled: disabled,
        fillColor: disabled ? AppTheme.grey100 : null,
        labelStyle: TextStyle(color: disabled ? AppTheme.grey400 : null),
      ),
      style: TextStyle(color: disabled ? AppTheme.grey500 : null),
      validator: validator ?? (mandatory
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null),
    );
  }

  Widget _gridRow(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton.icon(
            onPressed: _skipProfile,
            icon: const Icon(Icons.skip_next_outlined, color: Colors.white),
            label: const Text('Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Column(children: [
                Icon(Icons.account_circle_outlined, size: 60, color: Colors.white),
                SizedBox(height: 10),
                Text('Setup Your Farm Profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Fields marked * are mandatory', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFFDE8E8))),
              ]),
            ),
            const SizedBox(height: 20),

            // Form card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                    // ── IDENTITY ──────────────────────────────
                    _sectionLabel('IDENTITY'),
                    _gridRow(
                      _field(ctrl: _farmerIdCtrl, label: 'Farmer ID', icon: Icons.vpn_key_outlined, disabled: true),
                      _field(
                        ctrl: _fullNameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _gridRow(
                      _field(
                        ctrl: _mobileCtrl,
                        label: 'Mobile Number',
                        icon: Icons.phone_android_outlined,
                        mandatory: true,
                        keyboard: TextInputType.phone,
                        prefixText: '+91 ',
                        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Mobile is required';
                          if (v.trim().length != 10) return 'Enter 10 digits';
                          return null;
                        },
                      ),
                      _field(
                        ctrl: _emailCtrl,
                        label: 'Email',
                        icon: Icons.mail_outline,
                        mandatory: true,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,4}").hasMatch(v.trim())) return 'Invalid email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _gridRow(
                      _field(
                        ctrl: _zipCtrl,
                        label: 'Zip Code',
                        icon: Icons.pin_drop_outlined,
                        mandatory: true,
                        keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        validator: (v) => v == null || v.trim().isEmpty ? 'Zip code is required' : null,
                      ),
                      // Role dropdown styled like a field
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryRed),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'Supervisor', child: Text('Supervisor')),
                            DropdownMenuItem(value: 'Farmer', child: Text('Farmer')),
                          ],
                          onChanged: (v) { if (v != null) setState(() => _selectedRole = v); },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Password (full width)
                    StatefulBuilder(
                      builder: (ctx, setSt) => _field(
                        ctrl: _passwordCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.grey500),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── LOCATION ─────────────────────────────
                    _sectionLabel('LOCATION'),
                    _field(ctrl: _addressCtrl, label: 'Address', icon: Icons.location_on_outlined, maxLines: 2),
                    const SizedBox(height: 14),
                    _gridRow(
                      // Country dropdown
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country *',
                          prefixIcon: Icon(Icons.public_outlined, color: AppTheme.primaryRed),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: _onCountryChanged,
                        validator: (v) => v == null ? 'Country is required' : null,
                      ),
                      _field(
                        ctrl: _currencyCtrl,
                        label: 'Currency',
                        icon: Icons.currency_exchange_outlined,
                        disabled: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(ctrl: _stateCtrl, label: 'State', icon: Icons.map_outlined),
                    const SizedBox(height: 22),

                    // ── FARM INFO ────────────────────────────
                    _sectionLabel('FARM DETAILS'),
                    _gridRow(
                      _field(
                        ctrl: _farmsCtrl,
                        label: 'Farms',
                        icon: Icons.agriculture_outlined,
                        keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      _field(
                        ctrl: _shedsCtrl,
                        label: 'Sheds',
                        icon: Icons.home_work_outlined,
                        keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── DEVICE ───────────────────────────────
                    _sectionLabel('DEVICE'),
                    _field(
                      ctrl: _deviceIdCtrl,
                      label: 'Device ID',
                      icon: Icons.smartphone_outlined,
                      disabled: true,
                    ),
                    const SizedBox(height: 28),

                    // Save button
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius12)),
                        elevation: 2,
                      ),
                      child: const Text('Save & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
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
