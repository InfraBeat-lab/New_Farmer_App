import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/core/widgets/powered_by_footer.widget.dart';

// -----------------------------------------------------------------------------
// USER MODEL
// -----------------------------------------------------------------------------
class FarmerUser {
  String name;
  String mobile;
  String email;
  String password;
  String role;
  String farmerId;
  String userCode;
  bool isAdmin;

  FarmerUser({
    required this.name,
    required this.mobile,
    required this.email,
    required this.password,
    required this.role,
    required this.farmerId,
    required this.userCode,
    this.isAdmin = false,
  });
}

// -----------------------------------------------------------------------------
// POULTRY BATCH MODEL
// -----------------------------------------------------------------------------
class PoultryBatch {
  String id;
  String batchName;
  String module; // 'Broiler', 'Layer', 'Breeder'
  String type;   // 'Own' or 'Contract'

  // Own batch
  String? linkedFarmerCode;
  String? linkedFarmerName;

  // Contract batch
  String? contractFarmerName;
  String? contractShedName;

  String breedName;
  DateTime date;
  DateTime firstDayDate;
  int stdLiftingAge;
  int chicksQuantity;
  double birdRate;

  PoultryBatch({
    required this.id,
    required this.batchName,
    required this.module,
    required this.type,
    this.linkedFarmerCode,
    this.linkedFarmerName,
    this.contractFarmerName,
    this.contractShedName,
    required this.breedName,
    required this.date,
    required this.firstDayDate,
    required this.stdLiftingAge,
    required this.chicksQuantity,
    required this.birdRate,
  });
}

// -----------------------------------------------------------------------------
// BATCH TRANSACTION MODEL
// -----------------------------------------------------------------------------
class BatchTransaction {
  final String id;
  final String batchId;
  final DateTime date;
  final int ageDays;
  final double bodyWeight;
  final Map<String, int> mortalityReasons;
  final Map<String, double> feedItems;
  final List<String> mediaPaths;
  final double fcr;
  final double stdConsumption;

  BatchTransaction({
    required this.id,
    required this.batchId,
    required this.date,
    required this.ageDays,
    required this.bodyWeight,
    required this.mortalityReasons,
    required this.feedItems,
    required this.mediaPaths,
    required this.fcr,
    required this.stdConsumption,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'batchId': batchId,
    'date': date.toIso8601String(),
    'ageDays': ageDays,
    'bodyWeight': bodyWeight,
    'mortalityReasons': mortalityReasons,
    'feedItems': feedItems,
    'mediaPaths': mediaPaths,
    'fcr': fcr,
    'stdConsumption': stdConsumption,
  };

  factory BatchTransaction.fromJson(Map<String, dynamic> json) => BatchTransaction(
    id: json['id'] as String,
    batchId: json['batchId'] as String,
    date: DateTime.parse(json['date'] as String),
    ageDays: json['ageDays'] as int,
    bodyWeight: (json['bodyWeight'] as num).toDouble(),
    mortalityReasons: Map<String, int>.from(json['mortalityReasons'] as Map),
    feedItems: Map<String, double>.from(json['feedItems'] as Map),
    mediaPaths: List<String>.from(json['mediaPaths'] as List),
    fcr: ((json['fcr'] ?? 0.0) as num).toDouble(),
    stdConsumption: ((json['stdConsumption'] ?? 0.0) as num).toDouble(),
  );
}

// -----------------------------------------------------------------------------
// DASHBOARD SCREEN
// -----------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _displayName = 'Farmer';
  bool _isAdmin = true;
  String _userCode = '';
  String _currencySymbol = '₹';

  bool _recharged = false;

  int _broilerBalance = 0;
  int _layerBalance = 0;
  int _breederBalance = 0;

  final List<FarmerUser> _users = [
    FarmerUser(
      name: 'Sagar Godbole (Admin)',
      mobile: '9876543210',
      email: 'sagar@logicaldna.com',
      password: 'adminpassword',
      role: 'Admin',
      farmerId: '1',
      userCode: 'SG-1001',
      isAdmin: true,
    )
  ];

  final List<PoultryBatch> _batches = [];
  final List<BatchTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadUserRoleAndName();
  }

  void _handleTabSelection() {
    setState(() {});
    if (!_recharged && _tabController.index != 0) {
      setState(() => _tabController.index = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete a credit recharge to unlock User and Batch tabs!'),
          backgroundColor: AppTheme.primaryRed,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _loadUserRoleAndName() {
    final email = LocalStorageService.getString('email') ?? '';
    final userCode = LocalStorageService.getString('user_code') ?? 'SG-1001';
    final displayName = LocalStorageService.getString('display_name') ?? 'Sagar Godbole';
    final farmerId = LocalStorageService.getString('farmer_id') ?? '1';
    final country = LocalStorageService.getString('country') ?? 'India';
    final config = _countryPurchaseConfigs[country] ?? _countryPurchaseConfigs['India']!;

    setState(() {
      _isAdmin = (email == 'sagar@logicaldna.com');
      _userCode = userCode;
      _displayName = displayName;
      _currencySymbol = config.symbol;
    });

    _loadDataFromStorage();

    // If logged in user is admin, sync their details in the _users list
    if (_isAdmin) {
      final index = _users.indexWhere((u) => u.isAdmin);
      if (index != -1) {
        setState(() {
          _users[index].email = email;
          _users[index].name = displayName;
          _users[index].userCode = userCode;
          _users[index].farmerId = farmerId;
        });
        _saveUsersToStorage();
      }
    }
  }

  void _loadDataFromStorage() {
    // Load balances
    setState(() {
      _broilerBalance = LocalStorageService.getInt('broiler_balance') ?? 0;
      _layerBalance = LocalStorageService.getInt('layer_balance') ?? 0;
      _breederBalance = LocalStorageService.getInt('breeder_balance') ?? 0;
      _recharged = LocalStorageService.getBool('recharged') ?? false;
    });

    // Load users
    final usersJson = LocalStorageService.getString('users_list');
    if (usersJson != null && usersJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(usersJson) as List<dynamic>;
        setState(() {
          _users.clear();
          _users.addAll(decoded.map((u) => FarmerUser(
            name: u['name'] as String,
            mobile: u['mobile'] as String,
            email: u['email'] as String,
            password: u['password'] as String,
            role: u['role'] as String,
            farmerId: u['farmerId'] as String,
            userCode: u['userCode'] as String,
            isAdmin: u['isAdmin'] as bool? ?? false,
          )));
        });
      } catch (e) {
        debugPrint('Error loading users: $e');
      }
    } else {
      _saveUsersToStorage();
    }

    // Load batches
    final batchesJson = LocalStorageService.getString('batches_list');
    if (batchesJson != null && batchesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(batchesJson) as List<dynamic>;
        setState(() {
          _batches.clear();
          _batches.addAll(decoded.map((b) => PoultryBatch(
            id: b['id'] as String,
            batchName: b['batchName'] as String,
            module: b['module'] as String,
            type: b['type'] as String,
            linkedFarmerCode: b['linkedFarmerCode'] as String?,
            linkedFarmerName: b['linkedFarmerName'] as String?,
            contractFarmerName: b['contractFarmerName'] as String?,
            contractShedName: b['contractShedName'] as String?,
            breedName: b['breedName'] as String,
            date: DateTime.parse(b['date'] as String),
            firstDayDate: DateTime.parse(b['firstDayDate'] as String),
            stdLiftingAge: b['stdLiftingAge'] as int,
            chicksQuantity: b['chicksQuantity'] as int,
            birdRate: (b['birdRate'] as num).toDouble(),
          )));
        });
      } catch (e) {
        debugPrint('Error loading batches: $e');
      }
    }

    // Load transactions
    final txJson = LocalStorageService.getString('transactions_list');
    if (txJson != null && txJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(txJson) as List<dynamic>;
        setState(() {
          _transactions.clear();
          _transactions.addAll(decoded.map((t) => BatchTransaction.fromJson(t as Map<String, dynamic>)));
        });
      } catch (e) {
        debugPrint('Error loading transactions: $e');
      }
    }
  }

  void _saveTransactionsToStorage() async {
    final list = _transactions.map((t) => t.toJson()).toList();
    await LocalStorageService.setString('transactions_list', jsonEncode(list));
  }

  void _saveUsersToStorage() async {
    final list = _users.map((u) => {
      'name': u.name,
      'mobile': u.mobile,
      'email': u.email,
      'password': u.password,
      'role': u.role,
      'farmerId': u.farmerId,
      'userCode': u.userCode,
      'isAdmin': u.isAdmin,
    }).toList();
    await LocalStorageService.setString('users_list', jsonEncode(list));
  }

  void _saveBatchesToStorage() async {
    final list = _batches.map((b) => {
      'id': b.id,
      'batchName': b.batchName,
      'module': b.module,
      'type': b.type,
      'linkedFarmerCode': b.linkedFarmerCode,
      'linkedFarmerName': b.linkedFarmerName,
      'contractFarmerName': b.contractFarmerName,
      'contractShedName': b.contractShedName,
      'breedName': b.breedName,
      'date': b.date.toIso8601String(),
      'firstDayDate': b.firstDayDate.toIso8601String(),
      'stdLiftingAge': b.stdLiftingAge,
      'chicksQuantity': b.chicksQuantity,
      'birdRate': b.birdRate,
    }).toList();
    await LocalStorageService.setString('batches_list', jsonEncode(list));
  }

  void _saveBalancesToStorage() async {
    await LocalStorageService.setInt('broiler_balance', _broilerBalance);
    await LocalStorageService.setInt('layer_balance', _layerBalance);
    await LocalStorageService.setInt('breeder_balance', _breederBalance);
    await LocalStorageService.setBool('recharged', _recharged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _signOut() async {
    await LocalStorageService.remove('IsLogin');
    await LocalStorageService.remove('session_id');
    await LocalStorageService.remove('access_token');
    await LocalStorageService.remove('email');
    await LocalStorageService.remove('mobile');
    await LocalStorageService.remove('role');
    await LocalStorageService.remove('user_code');
    await LocalStorageService.remove('display_name');
    await LocalStorageService.remove('full_name');
    await LocalStorageService.remove('farmer_id');
    await LocalStorageService.remove('profile_completed');
    await LocalStorageService.remove('farm_name');
    await LocalStorageService.remove('address');
    await LocalStorageService.remove('city');
    await LocalStorageService.remove('pin_code');
    await LocalStorageService.remove('gst');
    await LocalStorageService.remove('pan');
    await LocalStorageService.remove('currency_code');
    await LocalStorageService.remove('language');
    await LocalStorageService.remove('timezone');
    await LocalStorageService.remove('country_id');
    await LocalStorageService.remove('country');

    if (!mounted) return;
    context.go('/login');
  }

  // ---- RECHARGE WIZARD ----
  void _showRechargeWizard() async {
    final result = await showDialog<List<CartItem>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RechargeWizardDialog(),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _recharged = true;
        for (var item in result) {
          if (item.module == 'Broiler') { _broilerBalance += item.count; }
          else if (item.module == 'Layer') { _layerBalance += item.count; }
          else if (item.module == 'Breeder') { _breederBalance += item.count; }
        }
      });
      _saveBalancesToStorage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${result.length} item(s)! User & Batch tabs unlocked.'),
          backgroundColor: AppTheme.primaryRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ---- USER FORM ----
  void _showUserForm({FarmerUser? user, int? index}) {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final mobileCtrl = TextEditingController(text: user?.mobile ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final passwordCtrl = TextEditingController(text: user?.password ?? '');
    final loggedInFarmerId = LocalStorageService.getString('farmer_id') ?? '1';
    final farmerIdCtrl = TextEditingController(text: user?.farmerId ?? loggedInFarmerId);
    final userCodeCtrl = TextEditingController(text: user?.userCode ?? '');
    String selectedRole = user?.role ?? 'Supervisor';
    final formKey = GlobalKey<FormState>();

    if (!isEdit) {
      final rnd = Random().nextInt(9000) + 1000;
      nameCtrl.addListener(() {
        final initials = nameCtrl.text.trim().split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '').join('').toUpperCase();
        userCodeCtrl.text = '${initials.isNotEmpty ? initials : 'USR'}-$rnd';
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) {
          bool obscure = true;
          return StatefulBuilder(
            builder: (ctx2, setDS2) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
              title: Text(isEdit ? 'Edit User' : 'Create New User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_android_outlined), prefixText: '+91 '),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length != 10) return 'Enter 10 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,4}").hasMatch(v.trim())) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.grey500),
                            onPressed: () => setDS2(() => obscure = !obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.admin_panel_settings_outlined), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        items: const [
                          DropdownMenuItem(value: 'Supervisor', child: Text('Supervisor')),
                          DropdownMenuItem(value: 'Farmer', child: Text('Farmer')),
                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                        ],
                        onChanged: (v) { if (v != null) selectedRole = v; },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(controller: farmerIdCtrl, enabled: false, decoration: const InputDecoration(labelText: 'Farmer ID (Unique)', prefixIcon: Icon(Icons.vpn_key_outlined))),
                      const SizedBox(height: 14),
                      TextFormField(controller: userCodeCtrl, enabled: false, decoration: const InputDecoration(labelText: 'User Code (Auto)', prefixIcon: Icon(Icons.badge_outlined))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        final newUser = FarmerUser(
                          name: nameCtrl.text.trim(),
                          mobile: mobileCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          role: selectedRole,
                          farmerId: farmerIdCtrl.text.trim(),
                          userCode: userCodeCtrl.text.trim(),
                          isAdmin: user?.isAdmin ?? false,
                        );
                        if (isEdit && index != null) { _users[index] = newUser; }
                        else { _users.add(newUser); }
                      });
                      _saveUsersToStorage();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEdit ? 'User updated!' : 'User created!'),
                        backgroundColor: AppTheme.success,
                      ));
                    }
                  },
                  child: Text(isEdit ? 'Save' : 'Create', style: const TextStyle(color: AppTheme.primaryRed)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteUser(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${_users[index].name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() {
                _users.removeAt(index);
              });
              _saveUsersToStorage();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted.'), backgroundColor: AppTheme.success));
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ---- BATCH FORM ----
  // Helper: available balance for a module
  int _balanceFor(String module) {
    if (module == 'Broiler') return _broilerBalance;
    if (module == 'Layer') return _layerBalance;
    if (module == 'Breeder') return _breederBalance;
    return 0;
  }

  void _adjustBalance(String module, int delta) {
    setState(() {
      if (module == 'Broiler') { _broilerBalance += delta; }
      else if (module == 'Layer') { _layerBalance += delta; }
      else if (module == 'Breeder') { _breederBalance += delta; }
    });
    _saveBalancesToStorage();
  }

  void _showBatchForm({PoultryBatch? batch, int? index}) {
    final isEdit = batch != null;
    final batchNameCtrl = TextEditingController(text: batch?.batchName ?? '');
    final contractFarmerCtrl = TextEditingController(text: batch?.contractFarmerName ?? '');
    final contractShedCtrl = TextEditingController(text: batch?.contractShedName ?? '');
    final liftingAgeCtrl = TextEditingController(text: batch?.stdLiftingAge.toString() ?? '42');
    final chicksQtyCtrl = TextEditingController(text: batch?.chicksQuantity.toString() ?? '');
    final birdRateCtrl = TextEditingController(text: batch?.birdRate.toString() ?? '');

    String selectedModule = batch?.module ?? 'Broiler';
    String batchType = batch?.type ?? 'Own';
    String breedName = batch?.breedName ?? 'COBB 430';
    String? linkedFarmerCode = batch?.linkedFarmerCode;
    String? linkedFarmerName = batch?.linkedFarmerName;
    DateTime selectedDate = batch?.date ?? DateTime.now();
    DateTime firstDayDate = batch?.firstDayDate ?? DateTime.now();
    final formKey = GlobalKey<FormState>();

    // Non-admin farmers for Own selection
    final farmers = _users.where((u) => !u.isAdmin).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) {
          Future<void> pickDate(bool isFirst) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isFirst ? firstDayDate : selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setBS(() {
                if (isFirst) { firstDayDate = picked; }
                else { selectedDate = picked; }
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
            title: Text(isEdit ? 'Edit Batch' : 'Create New Batch'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Batch Name ----
                    TextFormField(
                      controller: batchNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch Name',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Batch name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ---- Module ----
                    const Text('Module', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedModule,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: ['Broiler', 'Layer', 'Breeder'].map((m) {
                        final bal = _balanceFor(m);
                        // When editing, don't count the current batch's module as consumed
                        final available = isEdit && batch.module == m ? bal + 1 : bal;
                        return DropdownMenuItem(
                          value: m,
                          enabled: isEdit ? true : available > 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m, style: TextStyle(color: (!isEdit && available == 0) ? AppTheme.grey300 : null)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: available > 0 ? AppTheme.successLight : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$available left',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: available > 0 ? AppTheme.successDark : AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) { if (v != null) { setBS(() => selectedModule = v); } },
                      validator: (v) {
                        if (v == null) { return 'Select a module'; }
                        final bal = _balanceFor(v);
                        final available = isEdit && batch.module == v ? bal + 1 : bal;
                        if (!isEdit && available <= 0) { return 'No credits left for $v. Please recharge.'; }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ---- Type ----
                    const Text('Type', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700, fontSize: 13)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Own', label: Text('Own'), icon: Icon(Icons.person_outline, size: 16)),
                        ButtonSegment(value: 'Contract', label: Text('Contract'), icon: Icon(Icons.handshake_outlined, size: 16)),
                      ],
                      selected: {batchType},
                      onSelectionChanged: (Set<String> selection) {
                        setBS(() {
                          batchType = selection.first;
                          linkedFarmerCode = null;
                          linkedFarmerName = null;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF0D8B60).withValues(alpha: 0.15);
                          }
                          return null;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF0D8B60);
                          }
                          return AppTheme.grey600;
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---- Own: pick from user list ----
                    if (batchType == 'Own') ...[
                      const Text('Select Farmer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700, fontSize: 13)),
                      const SizedBox(height: 6),
                      farmers.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: const Text('No farmers found. Please create a user first.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                            )
                          : DropdownButtonFormField<String>(
                              value: linkedFarmerCode,
                              hint: const Text('Choose a farmer'),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person_outlined),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: farmers.map((f) => DropdownMenuItem(
                                value: f.userCode,
                                child: Text('${f.name} (${f.userCode})'),
                              )).toList(),
                              onChanged: (v) => setBS(() {
                                linkedFarmerCode = v;
                                linkedFarmerName = farmers.firstWhere((f) => f.userCode == v).name;
                              }),
                              validator: (v) => v == null ? 'Please select a farmer' : null,
                            ),
                    ],

                    // ---- Contract: create farmer + shed on spot ----
                    if (batchType == 'Contract') ...[
                      TextFormField(
                        controller: contractFarmerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contract Farmer Name',
                          prefixIcon: Icon(Icons.person_add_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Farmer name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: contractShedCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Shed Name',
                          prefixIcon: Icon(Icons.home_work_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Shed name is required' : null,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ---- Breed Name ----
                    const Text('Breed Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: breedName,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.cruelty_free_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'COBB 430', child: Text('COBB 430')),
                        DropdownMenuItem(value: 'COBB 550', child: Text('COBB 550')),
                      ],
                      onChanged: (v) { if (v != null) setBS(() => breedName = v); },
                    ),
                    const SizedBox(height: 16),

                    // ---- Date ----
                    GestureDetector(
                      onTap: () => pickDate(false),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            hintText: '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          ),
                          controller: TextEditingController(
                            text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---- First Day Date ----
                    GestureDetector(
                      onTap: () => pickDate(true),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'First Day Date',
                            prefixIcon: const Icon(Icons.event_outlined),
                            hintText: '${firstDayDate.day}/${firstDayDate.month}/${firstDayDate.year}',
                          ),
                          controller: TextEditingController(
                            text: '${firstDayDate.day.toString().padLeft(2, '0')}/${firstDayDate.month.toString().padLeft(2, '0')}/${firstDayDate.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---- Std. Lifting Age ----
                    TextFormField(
                      controller: liftingAgeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Std. Lifting Age (days)',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // ---- Chicks Quantity ----
                    TextFormField(
                      controller: chicksQtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Chicks Quantity',
                        prefixIcon: Icon(Icons.egg_alt_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // ---- Bird Rate ----
                    TextFormField(
                      controller: birdRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Bird Rate ($_currencySymbol)',
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final newBatch = PoultryBatch(
                      id: isEdit ? batch.id : 'BCH-${Random().nextInt(90000) + 10000}',
                      batchName: batchNameCtrl.text.trim(),
                      module: selectedModule,
                      type: batchType,
                      linkedFarmerCode: batchType == 'Own' ? linkedFarmerCode : null,
                      linkedFarmerName: batchType == 'Own' ? linkedFarmerName : null,
                      contractFarmerName: batchType == 'Contract' ? contractFarmerCtrl.text.trim() : null,
                      contractShedName: batchType == 'Contract' ? contractShedCtrl.text.trim() : null,
                      breedName: breedName,
                      date: selectedDate,
                      firstDayDate: firstDayDate,
                      stdLiftingAge: int.tryParse(liftingAgeCtrl.text.trim()) ?? 42,
                      chicksQuantity: int.tryParse(chicksQtyCtrl.text.trim()) ?? 0,
                      birdRate: double.tryParse(birdRateCtrl.text.trim()) ?? 0.0,
                    );
                    setState(() {
                      if (isEdit && index != null) {
                        // Restore old module credit, deduct new module credit
                        if (batch.module != selectedModule) {
                          _adjustBalance(batch.module, 1);   // restore old
                          _adjustBalance(selectedModule, -1); // deduct new
                        }
                        _batches[index] = newBatch;
                      } else {
                        _adjustBalance(selectedModule, -1); // deduct on create
                        _batches.add(newBatch);
                      }
                    });
                    _saveBatchesToStorage();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEdit ? 'Batch updated!' : 'Batch "${newBatch.batchName}" created!'),
                      backgroundColor: AppTheme.success,
                    ));
                  }
                },
                child: Text(isEdit ? 'Save Changes' : 'Create Batch', style: const TextStyle(color: AppTheme.primaryRed)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteBatch(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text('Delete batch "${_batches[index].batchName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final deletedModule = _batches[index].module;
              setState(() {
                _batches.removeAt(index);
                _adjustBalance(deletedModule, 1); // restore credit on delete
              });
              _saveBatchesToStorage();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted. Credit restored.'), backgroundColor: AppTheme.success));
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ---- NOTIFICATION ----
  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
        title: const Row(children: [
          Icon(Icons.notifications_active_outlined, color: AppTheme.primaryRed),
          SizedBox(width: 10),
          Text('Notifications'),
        ]),
        content: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline, color: AppTheme.info),
          title: Text('Welcome to PoultryOS!'),
          subtitle: Text('Setup complete. Manage your modules and balances.'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: AppTheme.primaryRed)))],
      ),
    );
  }

  // ---- BUILD ----
  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return _buildFarmerDashboard();
    }
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        titleSpacing: 16,
        title: PopupMenuButton<String>(
          offset: const Offset(0, 48),
          tooltip: 'Account Menu',
          onSelected: (val) {
            if (val == 'profile') {
              context.push('/profile').then((_) => _loadUserRoleAndName());
            } else if (val == 'logout') {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () { Navigator.pop(ctx); _signOut(); }, child: const Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed))),
                  ],
                ),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, color: AppTheme.grey700),
                  SizedBox(width: 8),
                  Text('My Account'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_outlined, color: AppTheme.primaryRed),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed)),
                ],
              ),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Welcome back,', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 26), onPressed: _showNotificationDialog),
            Positioned(
              right: 8, top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                child: const Text('1', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
          ]),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white, size: 24),
            tooltip: 'Sign Out',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                  TextButton(onPressed: () { Navigator.pop(ctx); _signOut(); }, child: const Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) return Colors.white.withValues(alpha: 0.15);
                if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: 0.25);
                return null;
              }),
              tabs: [
                const Tab(text: 'Account'),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('User'),
                  if (!_recharged) ...[const SizedBox(width: 4), const Icon(Icons.lock_outline, size: 13, color: Colors.white70)],
                ])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Batch'),
                  if (!_recharged) ...[const SizedBox(width: 4), const Icon(Icons.lock_outline, size: 13, color: Colors.white70)],
                ])),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAccountsTab(), _buildUserTab(), _buildBatchTab()],
      ),
      floatingActionButton: _recharged
          ? (_tabController.index == 1
              ? FloatingActionButton(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  tooltip: 'Add User',
                  onPressed: () => _showUserForm(),
                  child: const Icon(Icons.person_add_outlined),
                )
              : _tabController.index == 2
                  ? FloatingActionButton(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      tooltip: 'Create Batch',
                      onPressed: () => _showBatchForm(),
                      child: const Icon(Icons.add),
                    )
                  : null)
          : null,
    );
  }

  // ---- ACCOUNT TAB ----
  Widget _buildAccountsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              gradient: const LinearGradient(colors: [Colors.white, AppTheme.grey100], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryRed),
                    SizedBox(width: 8),
                    Text('Credit Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Active', style: TextStyle(color: AppTheme.successDark, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const Divider(height: 24, thickness: 1),
                Row(children: [
                  Expanded(child: _buildBalanceItem(icon: Icons.cruelty_free_outlined, iconColor: Colors.orange, title: 'Broiler', value: '$_broilerBalance')),
                  Container(height: 40, width: 1, color: AppTheme.grey200),
                  Expanded(child: _buildBalanceItem(icon: Icons.egg_outlined, iconColor: Colors.amber, title: 'Layer', value: '$_layerBalance')),
                  Container(height: 40, width: 1, color: AppTheme.grey200),
                  Expanded(child: _buildBalanceItem(icon: Icons.egg_alt_outlined, iconColor: Colors.redAccent, title: 'Breeder', value: '$_breederBalance')),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text('Manage Credits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showRechargeWizard,
          icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
          label: const Text('Recharge Accounts / Buy Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius12)),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 24),
        const PoweredByFooter(),
      ]),
    );
  }

  Widget _buildBalanceItem({required IconData icon, required Color iconColor, required String title, required String value}) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.grey500, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
    ]);
  }

  // ---- USER TAB ----
  Widget _buildUserTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('User Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${_users.length} Users', style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final initials = user.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join('').toUpperCase();
            final roleColor = user.isAdmin
                ? AppTheme.primaryRed
                : (user.role == 'Supervisor' ? Colors.blue : Colors.green);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(color: roleColor, width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [roleColor.withValues(alpha: 0.18), roleColor.withValues(alpha: 0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'U',
                        style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(user.role, style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('ID: ${user.farmerId}  •  Code: ${user.userCode}', style: const TextStyle(color: AppTheme.grey500, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('Password: ••••••••', style: const TextStyle(color: AppTheme.grey400, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.phone_android_outlined, size: 12, color: AppTheme.grey400),
                      const SizedBox(width: 3),
                      Text('+91 ${user.mobile}', style: const TextStyle(color: AppTheme.grey500, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.mail_outline, size: 12, color: AppTheme.grey400),
                      const SizedBox(width: 3),
                      Flexible(child: Text(user.email, style: const TextStyle(color: AppTheme.grey500, fontSize: 11))),
                    ]),
                  ])),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryRed, size: 20),
                      onPressed: () => _showUserForm(user: user, index: index),
                      tooltip: 'Edit',
                    ),
                    if (!user.isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                        onPressed: () => _confirmDeleteUser(index),
                        tooltip: 'Delete',
                      ),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ---- BATCH TAB ----
  Widget _buildBatchTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Batch Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(8)),
            child: Text('${_batches.length} Batches', style: const TextStyle(color: AppTheme.successDark, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _batches.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.layers_clear_outlined, size: 56, color: AppTheme.grey300),
                  const SizedBox(height: 14),
                  const Text('No batches created yet', style: TextStyle(color: AppTheme.grey500, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('Tap + to create your first batch', style: TextStyle(color: AppTheme.grey400, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showBatchForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Batch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _batches.length,
                itemBuilder: (context, index) {
                  final b = _batches[index];
                  final isContract = b.type == 'Contract';
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Header row
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.layers, color: AppTheme.primaryRed, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.grey800)),
                            Text('ID: ${b.id}', style: const TextStyle(color: AppTheme.grey400, fontSize: 11)),
                          ])),
                          // Module badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.module == 'Broiler'
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : b.module == 'Layer'
                                      ? Colors.amber.withValues(alpha: 0.12)
                                      : Colors.red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              b.module,
                              style: TextStyle(
                                color: b.module == 'Broiler'
                                    ? Colors.orange.shade700
                                    : b.module == 'Layer'
                                        ? Colors.amber.shade800
                                        : Colors.redAccent.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Own/Contract badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isContract ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFF0D8B60).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(b.type, style: TextStyle(color: isContract ? Colors.blue : const Color(0xFF0D8B60), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          // Edit & Delete
                          IconButton(icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryRed, size: 20), onPressed: () => _showBatchForm(batch: b, index: index), tooltip: 'Edit'),
                          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), onPressed: () => _confirmDeleteBatch(index), tooltip: 'Delete'),
                        ]),
                        const Divider(height: 16),

                        // Farmer / Contract info
                        if (b.type == 'Own' && b.linkedFarmerName != null)
                          _batchInfoRow(Icons.person_outline, 'Farmer', '${b.linkedFarmerName} (${b.linkedFarmerCode})'),
                        if (b.type == 'Contract') ...[
                          _batchInfoRow(Icons.person_add_outlined, 'Contract Farmer', b.contractFarmerName ?? '-'),
                          _batchInfoRow(Icons.home_work_outlined, 'Shed', b.contractShedName ?? '-'),
                        ],

                        // Batch details grid
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _batchChip(Icons.category_outlined, b.module, b.module == 'Broiler' ? Colors.orange : b.module == 'Layer' ? Colors.amber.shade700 : Colors.redAccent),
                          _batchChip(Icons.cruelty_free_outlined, b.breedName, Colors.brown),
                          _batchChip(Icons.egg_alt_outlined, '${b.chicksQuantity} Chicks', Colors.teal),
                          _batchChip(Icons.payments_outlined, '$_currencySymbol${b.birdRate.toStringAsFixed(2)}/bird', Colors.green),
                          _batchChip(Icons.timer_outlined, 'Lift: ${b.stdLiftingAge}d', Colors.purple),
                          _batchChip(Icons.calendar_today_outlined, '${b.date.day}/${b.date.month}/${b.date.year}', Colors.blue),
                          _batchChip(Icons.event_outlined, 'Day 1: ${b.firstDayDate.day}/${b.firstDayDate.month}/${b.firstDayDate.year}', Colors.indigo),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _batchInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.grey500),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.grey500, fontWeight: FontWeight.w600)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.grey700))),
      ]),
    );
  }

  Widget _batchChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildFarmerDashboard() {
    final assignedBatches = _batches.where((b) => b.linkedFarmerCode == _userCode).toList();

    // Sum up chicks and transaction metrics
    int totalInitialChicks = assignedBatches.fold(0, (sum, b) => sum + b.chicksQuantity);
    int totalMortalityCount = 0;
    double totalFeedBags = 0.0;

    for (var b in assignedBatches) {
      final txs = _transactions.where((t) => t.batchId == b.id);
      for (var t in txs) {
        totalMortalityCount += t.mortalityReasons.values.fold(0, (sum, val) => sum + val);
        totalFeedBags += t.feedItems.values.fold(0.0, (sum, val) => sum + val);
      }
    }

    int totalLiveQuantity = totalInitialChicks - totalMortalityCount;
    double mortalityRate = totalInitialChicks > 0 ? (totalMortalityCount / totalInitialChicks) * 100 : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        titleSpacing: 16,
        title: PopupMenuButton<String>(
          offset: const Offset(0, 48),
          tooltip: 'Account Menu',
          onSelected: (val) {
            if (val == 'profile') {
              context.push('/profile').then((_) => _loadUserRoleAndName());
            } else if (val == 'logout') {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () { Navigator.pop(ctx); _signOut(); }, child: const Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed))),
                  ],
                ),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, color: AppTheme.grey700),
                  SizedBox(width: 8),
                  Text('My Account'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_outlined, color: AppTheme.primaryRed),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed)),
                ],
              ),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Welcome back,', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 26), onPressed: _showNotificationDialog),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white, size: 24),
            tooltip: 'Sign Out',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                  TextButton(onPressed: () { Navigator.pop(ctx); _signOut(); }, child: const Text('Sign Out', style: TextStyle(color: AppTheme.primaryRed))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Farmer info header card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D8B60), Color(0xFF0A6F4C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: Row(
                    children: [
                      const Icon(Icons.agriculture_outlined, color: Colors.white, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Farmer Dashboard',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'User Code: $_userCode • Role: Farmer',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Three Tiles: Mortality, Feed, Live Quantity
            Row(
              children: [
                Expanded(
                  child: _buildFarmerMetricCard(
                    title: 'Live Qty',
                    value: '$totalLiveQuantity',
                    subtitle: 'Birds active',
                    icon: Icons.egg_alt_outlined,
                    iconColor: Colors.green,
                    bgColor: Colors.green.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFarmerMetricCard(
                    title: 'Feed Used',
                    value: '${totalFeedBags.toStringAsFixed(1)} KG',
                    subtitle: 'KG',
                    icon: Icons.grass_outlined,
                    iconColor: Colors.orange,
                    bgColor: Colors.orange.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFarmerMetricCard(
                    title: 'Mortality',
                    value: '$totalMortalityCount',
                    subtitle: '${mortalityRate.toStringAsFixed(2)}%',
                    icon: Icons.query_stats_outlined,
                    iconColor: AppTheme.primaryRed,
                    bgColor: AppTheme.primaryRed.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Insights & Reports Section
            const Text('Insights & Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => _showReportsScreen(context, assignedBatches),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.assignment_outlined, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
                                  SizedBox(height: 2),
                                  Text('Daily updates history', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.grey400, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => _showAnalyticsScreen(context, assignedBatches),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.bar_chart_outlined, color: Colors.purple, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
                                  SizedBox(height: 2),
                                  Text('FCR & feed graphs', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.grey400, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Assigned Batches list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Assigned Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0D8B60).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${assignedBatches.length} Active',
                    style: const TextStyle(color: Color(0xFF0D8B60), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (assignedBatches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Icon(Icons.layers_clear_outlined, size: 56, color: AppTheme.grey300),
                    const SizedBox(height: 14),
                    const Text('No batches assigned to you yet', style: TextStyle(color: AppTheme.grey500, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Contact Admin to link you to a batch.', style: TextStyle(color: AppTheme.grey400, fontSize: 12)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignedBatches.length,
                itemBuilder: (context, index) {
                  final b = assignedBatches[index];
                  // Compute local metrics for this specific batch
                  final bTxs = _transactions.where((t) => t.batchId == b.id).toList();
                  int bMortality = bTxs.fold(0, (sum, t) => sum + t.mortalityReasons.values.fold(0, (s, val) => s + val));
                  double bFeed = bTxs.fold(0.0, (sum, t) => sum + t.feedItems.values.fold(0.0, (s, val) => s + val));
                  int bLiveQty = b.chicksQuantity - bMortality;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => BatchTransactionsScreen(
                            batch: b,
                            transactions: _transactions,
                            displayName: _displayName,
                            onSaveTransaction: (tx, {isEdit = false}) {
                              setState(() {
                                if (isEdit) {
                                  final idx = _transactions.indexWhere((t) => t.id == tx.id);
                                  if (idx != -1) {
                                    _transactions[idx] = tx;
                                  }
                                } else {
                                  _transactions.add(tx);
                                }
                              });
                              _saveTransactionsToStorage();
                            },
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.layers, color: AppTheme.primaryRed, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.grey800)),
                                      Text('ID: ${b.id}', style: const TextStyle(color: AppTheme.grey400, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                // Module badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: b.module == 'Broiler'
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : b.module == 'Layer'
                                            ? Colors.amber.withValues(alpha: 0.12)
                                            : Colors.red.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    b.module,
                                    style: TextStyle(
                                      color: b.module == 'Broiler'
                                          ? Colors.orange.shade700
                                          : b.module == 'Layer'
                                              ? Colors.amber.shade800
                                              : Colors.redAccent.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _batchChip(Icons.category_outlined, b.module, b.module == 'Broiler' ? Colors.orange : b.module == 'Layer' ? Colors.amber.shade700 : Colors.redAccent),
                                _batchChip(Icons.cruelty_free_outlined, b.breedName, Colors.brown),
                                _batchChip(Icons.egg_alt_outlined, '$bLiveQty Live Birds', Colors.teal),
                                _batchChip(Icons.heart_broken_outlined, '$bMortality Dead', AppTheme.primaryRed),
                                _batchChip(Icons.grass_outlined, '${bFeed.toStringAsFixed(1)} KG Feed', Colors.orange),
                                _batchChip(Icons.timer_outlined, 'Lift: ${b.stdLiftingAge}d', Colors.purple),
                                _batchChip(Icons.calendar_today_outlined, '${b.date.day}/${b.date.month}/${b.date.year}', Colors.blue),
                                _batchChip(Icons.event_outlined, 'Day 1: ${b.firstDayDate.day}/${b.firstDayDate.month}/${b.firstDayDate.year}', Colors.indigo),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.grey500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: AppTheme.grey400)),
          ],
        ),
      ),
    );
  }

  void _showReportsScreen(BuildContext context, List<PoultryBatch> assignedBatches) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DailyTransactionReportScreen(
          batches: assignedBatches,
          transactions: _transactions,
        ),
      ),
    );
  }

  void _showAnalyticsScreen(BuildContext context, List<PoultryBatch> assignedBatches) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AnalyticsScreen(
          batches: assignedBatches,
          transactions: _transactions,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CART ITEM MODEL
// -----------------------------------------------------------------------------
class CartItem {
  final String module;
  final int count;
  final double pricePerBatch;

  CartItem({required this.module, required this.count, this.pricePerBatch = 500.0});

  double get subtotal => count * pricePerBatch;
}

// -----------------------------------------------------------------------------
// COUNTRY PURCHASE CONFIG
// -----------------------------------------------------------------------------
class CountryPurchaseConfig {
  final String symbol;      // Currency symbol (e.g. '₹')
  final double pricePerBatch; // Price per batch (e.g. 500.0)
  final double flatDiscount;  // FLAT coupon discount (e.g. 500.0 for FREESHED)
  final String flatDiscountText; // Text description (e.g. 'Flat ₹500 discount')

  const CountryPurchaseConfig({
    required this.symbol,
    required this.pricePerBatch,
    required this.flatDiscount,
    required this.flatDiscountText,
  });
}

const Map<String, CountryPurchaseConfig> _countryPurchaseConfigs = {
  'India': CountryPurchaseConfig(symbol: '₹', pricePerBatch: 500.0, flatDiscount: 500.0, flatDiscountText: 'Flat ₹500 discount'),
  'United States': CountryPurchaseConfig(symbol: '\$', pricePerBatch: 10.0, flatDiscount: 10.0, flatDiscountText: 'Flat \$10 discount'),
  'United Kingdom': CountryPurchaseConfig(symbol: '£', pricePerBatch: 8.0, flatDiscount: 8.0, flatDiscountText: 'Flat £8 discount'),
  'Australia': CountryPurchaseConfig(symbol: 'A\$', pricePerBatch: 15.0, flatDiscount: 15.0, flatDiscountText: 'Flat A\$15 discount'),
  'Canada': CountryPurchaseConfig(symbol: 'C\$', pricePerBatch: 15.0, flatDiscount: 15.0, flatDiscountText: 'Flat C\$15 discount'),
  'Germany': CountryPurchaseConfig(symbol: '€', pricePerBatch: 10.0, flatDiscount: 10.0, flatDiscountText: 'Flat €10 discount'),
  'France': CountryPurchaseConfig(symbol: '€', pricePerBatch: 10.0, flatDiscount: 10.0, flatDiscountText: 'Flat €10 discount'),
  'Japan': CountryPurchaseConfig(symbol: '¥', pricePerBatch: 1500.0, flatDiscount: 1500.0, flatDiscountText: 'Flat ¥1500 discount'),
  'China': CountryPurchaseConfig(symbol: '¥', pricePerBatch: 70.0, flatDiscount: 70.0, flatDiscountText: 'Flat ¥70 discount'),
  'UAE': CountryPurchaseConfig(symbol: 'AED ', pricePerBatch: 40.0, flatDiscount: 40.0, flatDiscountText: 'Flat AED 40 discount'),
  'Saudi Arabia': CountryPurchaseConfig(symbol: 'SAR ', pricePerBatch: 40.0, flatDiscount: 40.0, flatDiscountText: 'Flat SAR 40 discount'),
  'Singapore': CountryPurchaseConfig(symbol: 'S\$', pricePerBatch: 15.0, flatDiscount: 15.0, flatDiscountText: 'Flat S\$15 discount'),
  'South Africa': CountryPurchaseConfig(symbol: 'R', pricePerBatch: 180.0, flatDiscount: 180.0, flatDiscountText: 'Flat R 180 discount'),
  'Brazil': CountryPurchaseConfig(symbol: 'R\$', pricePerBatch: 50.0, flatDiscount: 50.0, flatDiscountText: 'Flat R\$50 discount'),
  'Mexico': CountryPurchaseConfig(symbol: 'Mex\$', pricePerBatch: 180.0, flatDiscount: 180.0, flatDiscountText: 'Flat Mex\$180 discount'),
};

// -----------------------------------------------------------------------------
// RECHARGE WIZARD DIALOG
// -----------------------------------------------------------------------------
class RechargeWizardDialog extends StatefulWidget {
  const RechargeWizardDialog({super.key});

  @override
  State<RechargeWizardDialog> createState() => _RechargeWizardDialogState();
}

class _RechargeWizardDialogState extends State<RechargeWizardDialog> {
  int _step = 0;
  String _selectedModule = 'Breeder';
  final _countCtrl = TextEditingController(text: '5');
  final _formKey = GlobalKey<FormState>();
  final List<CartItem> _cart = [];
  late String _txnId;
  bool _processing = true;
  bool _isInterstate = false;
  late double _pricePerBatch;
  late String _currencySymbol;
  late double _flatDiscountAmount;
  late String _flatDiscountText;

  String? _appliedCoupon;
  double _discountAmount = 0.0;
  final _couponCtrl = TextEditingController();
  String? _couponError;
  String? _couponSuccess;

  @override
  void initState() {
    super.initState();
    final n = Random().nextInt(90000000) + 10000000;
    _txnId = 'TXN-POULTRY-$n';

    final country = LocalStorageService.getString('country') ?? 'India';
    final config = _countryPurchaseConfigs[country] ?? _countryPurchaseConfigs['India']!;
    _pricePerBatch = config.pricePerBatch;
    _currencySymbol = config.symbol;
    _flatDiscountAmount = config.flatDiscount;
    _flatDiscountText = config.flatDiscountText;
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  void _applyCoupon(String code) {
    code = code.trim().toUpperCase();
    double discount = 0.0;
    String? successMsg;
    String? errorMsg;

    if (code == 'FARMER50') {
      discount = _subtotal * 0.5;
      successMsg = 'FARMER50 applied! 50% discount';
    } else if (code == 'WELCOME10') {
      discount = _subtotal * 0.1;
      successMsg = 'WELCOME10 applied! 10% discount';
    } else if (code == 'FREESHED') {
      discount = min(_flatDiscountAmount, _subtotal);
      successMsg = 'FREESHED applied! $_flatDiscountText';
    } else if (code == 'POULTRYOS') {
      discount = _subtotal * 0.2;
      successMsg = 'POULTRYOS applied! 20% discount';
    } else {
      errorMsg = 'Invalid Coupon Code';
    }

    setState(() {
      if (errorMsg != null) {
        _couponError = errorMsg;
        _couponSuccess = null;
        _appliedCoupon = null;
        _discountAmount = 0.0;
      } else {
        _couponError = null;
        _couponSuccess = successMsg;
        _appliedCoupon = code;
        _discountAmount = discount;
        _couponCtrl.text = code;
      }
    });
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discountAmount = 0.0;
      _couponCtrl.clear();
      _couponError = null;
      _couponSuccess = null;
    });
  }

  Widget _buildCouponCard(String code, String label, String desc) {
    final isSelected = _appliedCoupon == code;
    return GestureDetector(
      onTap: () => _applyCoupon(code),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.successLight.withValues(alpha: 0.5) : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.success : AppTheme.grey300,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 12, color: AppTheme.primaryRed),
                const SizedBox(width: 4),
                Text(
                  code,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppTheme.grey500),
            ),
          ],
        ),
      ),
    );
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  void _startPayment() async {
    setState(() { _step = 3; _processing = true; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 420,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            child: [_buildSelect(), _buildCart(), _buildInvoice(), _buildPayment()][_step],
          ),
        ),
      ),
    );
  }

  Widget _buildSelect() {
    return Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Select Module & Batches', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Select Module', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedModule,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primaryRed), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          items: const [
            DropdownMenuItem(value: 'Broiler', child: Text('Broiler')),
            DropdownMenuItem(value: 'Layer', child: Text('Layer')),
            DropdownMenuItem(value: 'Breeder', child: Text('Breeder')),
          ],
          onChanged: (v) { if (v != null) setState(() => _selectedModule = v); },
        ),
        const SizedBox(height: 16),
        const Text('Batch Count', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _countCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixIcon: Icon(Icons.numbers_outlined, color: AppTheme.primaryRed), hintText: 'e.g. 5', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            final n = int.tryParse(v);
            if (n == null || n <= 0) return 'Must be > 0';
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              setState(() {
                _cart.add(CartItem(module: _selectedModule, count: int.parse(_countCtrl.text), pricePerBatch: _pricePerBatch));
                _step = 1;
              });
            }
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Add to Cart'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
        if (_cart.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => setState(() => _step = 1), child: Text('View Cart (${_cart.length})')),
        ],
      ]),
    );
  }

  Widget _buildCart() {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [const Icon(Icons.shopping_cart, color: AppTheme.primaryRed), const SizedBox(width: 8), Text('Cart (${_cart.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.grey800))]),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ]),
      const Divider(height: 12),
      if (_cart.isEmpty) ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text('Cart is empty!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.grey500, fontSize: 16))),
        ElevatedButton(onPressed: () => setState(() => _step = 0), child: const Text('Add Items')),
      ] else ...[
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cart.length,
            itemBuilder: (_, i) {
              final item = _cart[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.grey100,
                elevation: 0,
                shape: RoundedRectangleBorder(side: const BorderSide(color: AppTheme.grey200), borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text('${item.module} Module', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${item.count} Batches @ $_currencySymbol${_pricePerBatch.toStringAsFixed(0)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$_currencySymbol${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18), onPressed: () => setState(() => _cart.removeAt(i))),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text('$_currencySymbol${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _step = 0), icon: const Icon(Icons.add), label: const Text('Add More'), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryRed), foregroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 14)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: () => setState(() => _step = 2), icon: const Icon(Icons.receipt_long), label: const Text('Checkout'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)))),
        ]),
      ],
    ]);
  }

  Widget _buildInvoice() {
    final discountedSubtotal = max(0.0, _subtotal - _discountAmount);
    final cgst = _isInterstate ? 0.0 : discountedSubtotal * 0.09;
    final sgst = _isInterstate ? 0.0 : discountedSubtotal * 0.09;
    final igst = _isInterstate ? discountedSubtotal * 0.18 : 0.0;
    final total = discountedSubtotal + cgst + sgst + igst;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Row(children: [Icon(Icons.receipt_long, color: AppTheme.primaryRed), SizedBox(width: 8), Text('Invoice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.grey800))]),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ]),
      const Divider(height: 12),
      
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('Inter-state (IGST)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('IGST 18% instead of CGST+SGST 9%+9%', style: TextStyle(fontSize: 11)),
                value: _isInterstate,
                activeThumbColor: AppTheme.primaryRed,
                activeTrackColor: AppTheme.primaryRed.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isInterstate = v),
              ),
              const SizedBox(height: 8),

              // --- Offers & Coupons Section (Zomato/Swiggy style) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_offer_outlined, color: AppTheme.primaryRed, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Offers & Coupons',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.grey800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextFormField(
                            controller: _couponCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Enter coupon code',
                              hintStyle: const TextStyle(fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              prefixIcon: const Icon(Icons.abc, color: AppTheme.grey500),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.grey300), borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.primaryRed), borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_appliedCoupon != null) {
                              _removeCoupon();
                            } else {
                              if (_couponCtrl.text.isNotEmpty) {
                                  _applyCoupon(_couponCtrl.text);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _appliedCoupon != null ? Colors.grey[700] : AppTheme.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_appliedCoupon != null ? 'Remove' : 'Apply', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  if (_couponError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _couponError!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (_couponSuccess != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _couponSuccess!,
                      style: const TextStyle(color: AppTheme.successDark, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Horizontal coupon list
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCouponCard('FARMER50', '50% OFF', 'Save 50% on all licenses'),
                        _buildCouponCard('FREESHED', '$_currencySymbol${_flatDiscountAmount.toStringAsFixed(0)} OFF', _flatDiscountText),
                        _buildCouponCard('POULTRYOS', '20% OFF', 'Flat 20% discount on total cost'),
                        _buildCouponCard('WELCOME10', '10% OFF', 'Flat 10% discount for first recharge'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.grey200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Price Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey500, fontSize: 11, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  ..._cart.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${item.module} (${item.count} Batches)', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      Text('$_currencySymbol${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                    ]),
                  )),
                  const Divider(height: 14),
                  _invoiceRow('Subtotal', '$_currencySymbol${_subtotal.toStringAsFixed(2)}'),
                  if (_appliedCoupon != null)
                    _invoiceRow('Coupon Discount ($_appliedCoupon)', '-$_currencySymbol${_discountAmount.toStringAsFixed(2)}', isDiscount: true),
                  _invoiceRow('CGST (9%)', '$_currencySymbol${cgst.toStringAsFixed(2)}', dim: _isInterstate),
                  _invoiceRow('SGST (9%)', '$_currencySymbol${sgst.toStringAsFixed(2)}', dim: _isInterstate),
                  _invoiceRow('IGST (18%)', '$_currencySymbol${igst.toStringAsFixed(2)}', dim: !_isInterstate),
                  const Divider(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$_currencySymbol${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryRed)),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.grey400), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Back to Cart'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: _startPayment, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Pay Now'))),
      ]),
    ]);
  }

  Widget _invoiceRow(String label, String value, {bool dim = false, bool isDiscount = false}) {
    Color textColor = dim ? AppTheme.grey300 : AppTheme.grey600;
    Color valColor = dim ? AppTheme.grey300 : AppTheme.grey700;
    
    if (isDiscount) {
      textColor = AppTheme.successDark;
      valColor = AppTheme.successDark;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: isDiscount ? FontWeight.w600 : null)),
        Text(value, style: TextStyle(fontSize: 12, color: valColor, fontWeight: isDiscount ? FontWeight.w600 : null)),
      ]),
    );
  }

  Widget _buildPayment() {
    final discountedSubtotal = max(0.0, _subtotal - _discountAmount);
    final cgst = _isInterstate ? 0.0 : discountedSubtotal * 0.09;
    final sgst = _isInterstate ? 0.0 : discountedSubtotal * 0.09;
    final igst = _isInterstate ? discountedSubtotal * 0.18 : 0.0;
    final total = discountedSubtotal + cgst + sgst + igst;

    if (_processing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryRed)),
          SizedBox(height: 20),
          Text('Processing secure payment...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          SizedBox(height: 6),
          Text('Please do not close this window', style: TextStyle(color: AppTheme.grey500, fontSize: 12)),
        ]),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.check_circle_outline_rounded, size: 70, color: AppTheme.primaryRed),
      const SizedBox(height: 14),
      const Center(child: Text('Payment Successful!', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppTheme.primaryRed))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          _receiptRow('Transaction ID', _txnId, bold: true),
          const Divider(height: 14),
          ..._cart.map((item) => _receiptRow('${item.module} License', '${item.count} Batches')),
          const Divider(height: 10),
          _receiptRow('Subtotal', '$_currencySymbol${_subtotal.toStringAsFixed(2)}'),
          if (_appliedCoupon != null)
            _receiptRow('Coupon Discount ($_appliedCoupon)', '-$_currencySymbol${_discountAmount.toStringAsFixed(2)}'),
          if (!_isInterstate) ...[
            _receiptRow('CGST (9%)', '$_currencySymbol${cgst.toStringAsFixed(2)}'),
            _receiptRow('SGST (9%)', '$_currencySymbol${sgst.toStringAsFixed(2)}'),
          ] else _receiptRow('IGST (18%)', '$_currencySymbol${igst.toStringAsFixed(2)}'),
          const Divider(height: 10),
          _receiptRow('Total Paid', '$_currencySymbol${total.toStringAsFixed(2)}', bold: true),
        ]),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, _cart),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Success', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: AppTheme.grey800)),
      ]),
    );
  }
}

class ViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);

    final cornerPaint = Paint()
      ..color = const Color(0xFF0D8B60)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final double len = 20.0;
    final double pad = 40.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(pad, pad + len)
        ..lineTo(pad, pad)
        ..lineTo(pad + len, pad),
      cornerPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad, pad + len)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad - len, pad),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(pad, size.height - pad - len)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad + len, size.height - pad),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad, size.height - pad - len)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad - len, size.height - pad),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// STANDARD POULTRY CHART LOOKUP HELPERS
// -----------------------------------------------------------------------------
double getStandardFCR(int ageDays) {
  if (ageDays <= 0) return 0.0;
  if (ageDays <= 7) return 0.8 + (ageDays / 7.0) * 0.1; // 0.8 -> 0.9
  if (ageDays <= 14) return 0.9 + ((ageDays - 7) / 7.0) * 0.25; // 0.9 -> 1.15
  if (ageDays <= 21) return 1.15 + ((ageDays - 14) / 7.0) * 0.15; // 1.15 -> 1.30
  if (ageDays <= 28) return 1.30 + ((ageDays - 21) / 7.0) * 0.15; // 1.30 -> 1.45
  if (ageDays <= 35) return 1.45 + ((ageDays - 28) / 7.0) * 0.15; // 1.45 -> 1.60
  return 1.60 + ((ageDays - 35) / 7.0) * 0.15; // 1.60 -> 1.75
}

double getStandardDailyFeedPerBirdGrams(int ageDays) {
  if (ageDays <= 0) return 10.0;
  if (ageDays <= 7) return 10.0 + ageDays * 3.0; // 10 -> 31g
  if (ageDays <= 14) return 31.0 + (ageDays - 7) * 5.0; // 31 -> 66g
  if (ageDays <= 21) return 66.0 + (ageDays - 14) * 6.0; // 66 -> 108g
  if (ageDays <= 28) return 108.0 + (ageDays - 21) * 7.0; // 108 -> 157g
  if (ageDays <= 35) return 157.0 + (ageDays - 28) * 8.0; // 157 -> 213g
  return 213.0 + (ageDays - 35) * 6.0; // 213 -> 255g
}

// -----------------------------------------------------------------------------
// BATCH TRANSACTIONS SCREEN
// -----------------------------------------------------------------------------
class BatchTransactionsScreen extends StatefulWidget {
  final PoultryBatch batch;
  final List<BatchTransaction> transactions;
  final String displayName;
  final Function(BatchTransaction, {bool isEdit}) onSaveTransaction;

  const BatchTransactionsScreen({
    super.key,
    required this.batch,
    required this.transactions,
    required this.displayName,
    required this.onSaveTransaction,
  });

  @override
  State<BatchTransactionsScreen> createState() => _BatchTransactionsScreenState();
}

class _BatchTransactionsScreenState extends State<BatchTransactionsScreen> {
  late List<BatchTransaction> _localTxs;

  @override
  void initState() {
    super.initState();
    _localTxs = widget.transactions.where((t) => t.batchId == widget.batch.id).toList();
  }

  void _refreshTransactions() {
    setState(() {
      _localTxs = widget.transactions.where((t) => t.batchId == widget.batch.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Notifications'),
                  content: const Text('No new alerts or notifications for this batch.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_localTxs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      const Icon(Icons.history_outlined, size: 56, color: AppTheme.grey300),
                      const SizedBox(height: 14),
                      const Text('No transactions recorded yet', style: TextStyle(color: AppTheme.grey500, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Click the + button below to add today\'s update.', style: TextStyle(color: AppTheme.grey400, fontSize: 12)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _localTxs.length,
                  itemBuilder: (ctx, idx) {
                    final tx = _localTxs[idx];
                    final txMortality = tx.mortalityReasons.values.fold(0, (sum, val) => sum + val);
                    final txFeed = tx.feedItems.values.fold(0.0, (sum, val) => sum + val);

                    return Card(
                      elevation: 1.0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Batch: ${widget.batch.batchName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('${tx.date.day}/${tx.date.month}/${tx.date.year}', style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
                                      const SizedBox(width: 8),
                                      Text('•   Age: ${tx.ageDays} Days', style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Feed: ${txFeed.toStringAsFixed(1)} KG',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Mortality: $txMortality Birds',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryRed, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.grey50),
                                  iconColor: AppTheme.grey500,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 100),
                                  onSelected: (val) {
                                    if (val == 'view') {
                                      _showBatchLoggingDialog(widget.batch, existingTx: tx, readOnly: true);
                                    } else if (val == 'edit') {
                                      _showBatchLoggingDialog(widget.batch, existingTx: tx, readOnly: false);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility_outlined, size: 16, color: AppTheme.grey700),
                                          SizedBox(width: 8),
                                          Text('View', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16, color: AppTheme.grey700),
                                          SizedBox(width: 8),
                                          Text('Edit', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBatchLoggingDialog(widget.batch),
        backgroundColor: const Color(0xFF0D8B60),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---- DYNAMIC LOGGING DIALOG WITH LIVE CALCULATIONS AND LAYOUT REFINEMENTS ----
  void _showBatchLoggingDialog(PoultryBatch batch, {BatchTransaction? existingTx, bool readOnly = false}) {
    DateTime txDate = existingTx != null ? existingTx.date : DateTime.now();
    final bodyWeightCtrl = TextEditingController(text: existingTx != null ? existingTx.bodyWeight.toStringAsFixed(0) : '');
    final formKey = GlobalKey<FormState>();

    // Calculate initial metrics
    final bTxs = widget.transactions.where((t) => t.batchId == batch.id).toList();
    int totalPrevMortality = bTxs.fold(0, (sum, t) => sum + t.mortalityReasons.values.fold(0, (s, val) => s + val));
    
    // If editing existing, adjust prev mortality to not double count this txn
    if (existingTx != null) {
      totalPrevMortality -= existingTx.mortalityReasons.values.fold(0, (sum, val) => sum + val);
    }
    
    int currentLiveQty = batch.chicksQuantity - totalPrevMortality;

    final mortalityReasons = ['Disease', 'Heat Stroke', 'Weakness', 'Accident', 'Other'];
    final feedItems = ['Pre-starter (KG)', 'Starter (KG)', 'Finisher (KG)'];

    // Helper to get feed value from old (Bags) or new (KG) keys
    double getFeedValue(String key) {
      if (existingTx == null) return 0.0;
      final prefix = key.split(' ')[0]; // e.g. "Pre-starter"
      for (var entry in existingTx.feedItems.entries) {
        if (entry.key.startsWith(prefix)) {
          return entry.value;
        }
      }
      return 0.0;
    }

    final Map<String, TextEditingController> mortCtrls = {
      for (var r in mortalityReasons) r: TextEditingController(text: existingTx != null ? (existingTx.mortalityReasons[r] ?? 0).toString() : '0')
    };
    final Map<String, TextEditingController> feedCtrls = {
      for (var f in feedItems) f: TextEditingController(text: getFeedValue(f).toStringAsFixed(1))
    };

    List<String> capturedMedia = existingTx != null ? List<String>.from(existingTx.mediaPaths) : [];
    bool isCameraOpen = false;
    bool isCapturingVideo = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          int ageDays = txDate.difference(batch.firstDayDate).inDays;
          if (ageDays < 0) ageDays = 0;

          // Standard curves calculation
          double stdFcr = getStandardFCR(ageDays);
          double stdFeedPerBird = getStandardDailyFeedPerBirdGrams(ageDays);
          double stdConsumptionKg = (stdFeedPerBird * currentLiveQty) / 1000.0;

          // Calculate actual FCR dynamically
          double totalFeedKgToday = 0.0;
          feedCtrls.forEach((key, ctrl) {
            totalFeedKgToday += double.tryParse(ctrl.text) ?? 0.0;
          });
          double avgWeightG = double.tryParse(bodyWeightCtrl.text) ?? 0.0;
          double biomassKg = currentLiveQty * (avgWeightG / 1000.0);
          double actualFcr = biomassKg > 0 ? totalFeedKgToday / biomassKg : 0.0;

          // Set up dynamic listeners for calculations on first build
          bodyWeightCtrl.addListener(() {
            setDlgState(() {});
          });
          for (var ctrl in feedCtrls.values) {
            ctrl.addListener(() {
              setDlgState(() {});
            });
          }

          // Camera Mock Overlay View
          if (isCameraOpen) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 480,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFF1E1E1E),
                          child: CustomPaint(
                            painter: ViewfinderGridPainter(),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.3), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              isCapturingVideo ? 'RECORDING POULTRY VIDEO' : 'ALIGN CAMERA WITH POULTRY FLOCK',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Live Shutter Only • Upload from Gallery Disabled',
                              style: TextStyle(color: Colors.redAccent.shade100, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 16, left: 16, right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isCapturingVideo ? 'REC 00:03' : 'LIVE HD 1080P',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.flash_off, color: Colors.white70, size: 18),
                                SizedBox(width: 12),
                                Icon(Icons.battery_4_bar_outlined, color: Colors.white70, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 24, left: 24, right: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton(
                              onPressed: () {
                                setDlgState(() => isCameraOpen = false);
                              },
                              child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ),
                            GestureDetector(
                              onTap: () {
                                final mockUrl = isCapturingVideo
                                    ? 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'
                                    : 'https://picsum.photos/id/${100 + Random().nextInt(50)}/400/300';
                                
                                setDlgState(() {
                                  capturedMedia.add(mockUrl);
                                  isCameraOpen = false;
                                  isCapturingVideo = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mock Live Capture Successful!'),
                                    backgroundColor: AppTheme.success,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: Container(
                                  width: 54, height: 54,
                                  decoration: BoxDecoration(
                                    color: isCapturingVideo ? Colors.red : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCapturingVideo ? Icons.stop : Icons.camera_alt,
                                    color: isCapturingVideo ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isCapturingVideo ? Icons.camera_alt_outlined : Icons.videocam_outlined,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setDlgState(() => isCapturingVideo = !isCapturingVideo);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Main Form Dialog View
          return DefaultTabController(
            length: 3,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(readOnly ? 'View Daily Log' : (existingTx != null ? 'Edit Daily Log' : 'Daily Batch Update'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Batch: ${batch.batchName}', style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 480, // Expand width slightly to prevent input label clippings
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ---- Info and Date Picker ----
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Batch Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: batch.batchName,
                                    enabled: false,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.layers_outlined),
                                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: readOnly ? null : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: txDate,
                                    firstDate: batch.firstDayDate,
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDlgState(() => txDate = picked);
                                  }
                                },
                                child: AbsorbPointer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(Icons.calendar_today_outlined),
                                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        ),
                                        controller: TextEditingController(
                                          text: '${txDate.day}/${txDate.month}/${txDate.year}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ---- Age & Live Birds (Pre-filled / Auto) ----
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Age (Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.timer_outlined),
                                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    ),
                                    enabled: false,
                                    controller: TextEditingController(text: '$ageDays Days'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Live Birds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.egg_alt_outlined),
                                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    ),
                                    enabled: false,
                                    controller: TextEditingController(text: '$currentLiveQty Birds'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ---- Body Weight (g) Input ----
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Avg Body Weight (grams) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: bodyWeightCtrl,
                              enabled: !readOnly,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                                hintText: 'e.g. 450',
                                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Body weight is required';
                                if (double.tryParse(v) == null) return 'Enter a valid number';
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ---- FCR & STANDARD CONSUMPTION LABELS ----
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.grey50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.grey200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Actual FCR', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
                                    const SizedBox(height: 2),
                                    Text(actualFcr > 0 ? actualFcr.toStringAsFixed(2) : '--', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: AppTheme.grey300),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Std. FCR', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
                                    const SizedBox(height: 2),
                                    Text(stdFcr.toStringAsFixed(2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: AppTheme.grey300),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Std. Feed', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
                                    const SizedBox(height: 2),
                                    Text('${stdConsumptionKg.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ---- Tab Bar ----
                        const TabBar(
                          labelColor: Color(0xFF0D8B60),
                          unselectedLabelColor: AppTheme.grey500,
                          indicatorColor: Color(0xFF0D8B60),
                          tabs: [
                            Tab(text: 'Mortality'),
                            Tab(text: 'Feed Info'),
                            Tab(text: 'Media log'),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ---- Tab Content ----
                        SizedBox(
                          height: 240, // Height expanded to avoid textboxes overflow
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // Mortality Tab with padding to prevent scrollbar overlap
                              Padding(
                                padding: const EdgeInsets.only(left: 12, right: 24, top: 8, bottom: 8),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: mortalityReasons.length,
                                  itemBuilder: (ctx, i) {
                                    final reason = mortalityReasons[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.grey700)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: SizedBox(
                                              height: 38,
                                              child: TextFormField(
                                                controller: mortCtrls[reason],
                                                enabled: !readOnly,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                textAlign: TextAlign.center,
                                                decoration: const InputDecoration(
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Feed Tab with padding to prevent scrollbar overlap
                              Padding(
                                padding: const EdgeInsets.only(left: 12, right: 24, top: 8, bottom: 8),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: feedItems.length,
                                  itemBuilder: (ctx, i) {
                                    final item = feedItems[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.grey700)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: SizedBox(
                                              height: 38,
                                              child: TextFormField(
                                                controller: feedCtrls[item],
                                                enabled: !readOnly,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                                textAlign: TextAlign.center,
                                                decoration: const InputDecoration(
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Camera/Media Tab
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setDlgState(() => isCameraOpen = true);
                                      },
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Capture Live (Camera Only)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D8B60),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: capturedMedia.isEmpty
                                          ? const Center(
                                              child: Text('No photos/videos captured today', style: TextStyle(color: AppTheme.grey400, fontSize: 11)),
                                            )
                                          : GridView.builder(
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                crossAxisSpacing: 6,
                                                mainAxisSpacing: 6,
                                              ),
                                              itemCount: capturedMedia.length,
                                              itemBuilder: (ctx, idx) {
                                                final media = capturedMedia[idx];
                                                final isVideo = media.endsWith('.mp4');
                                                final double fileLat = 18.5204 + (idx * 0.002);
                                                final double fileLng = 73.8567 + (idx * 0.003);
                                                final fileTimeStr = "${txDate.day}/${txDate.month}/${txDate.year} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

                                                return Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Stack(
                                                          children: [
                                                            Positioned.fill(
                                                              child: isVideo
                                                                  ? Container(
                                                                      color: Colors.black87,
                                                                      child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                                                                    )
                                                                  : Image.network(media, fit: BoxFit.cover),
                                                            ),
                                                            Positioned(
                                                              bottom: 0, left: 0, right: 0,
                                                              child: Container(
                                                                color: Colors.black54,
                                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text('BY: ${widget.displayName}', style: const TextStyle(color: Colors.orange, fontSize: 5.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                    Text('LOC: Pune, MH', style: const TextStyle(color: Colors.white, fontSize: 5, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                    Text('GPS: ${fileLat.toStringAsFixed(4)}, ${fileLng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 5, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                    Text(fileTimeStr, style: const TextStyle(color: Colors.white70, fontSize: 5, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (!readOnly)
                                                      Positioned(
                                                        top: 2, right: 2,
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            setDlgState(() => capturedMedia.removeAt(idx));
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.all(2),
                                                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (readOnly)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final bodyWeight = double.tryParse(bodyWeightCtrl.text) ?? 0.0;
                        final mortVals = mortCtrls.map((k, v) => MapEntry(k, int.tryParse(v.text) ?? 0));
                        final feedVals = feedCtrls.map((k, v) => MapEntry(k, double.tryParse(v.text) ?? 0.0));

                        final transaction = BatchTransaction(
                          id: existingTx != null ? existingTx.id : 'TXN-${Random().nextInt(900000) + 100000}',
                          batchId: batch.id,
                          date: txDate,
                          ageDays: ageDays,
                          bodyWeight: bodyWeight,
                          mortalityReasons: mortVals,
                          feedItems: feedVals,
                          mediaPaths: capturedMedia,
                          fcr: actualFcr,
                          stdConsumption: stdConsumptionKg,
                        );

                        widget.onSaveTransaction(transaction, isEdit: existingTx != null);
                        _refreshTransactions();

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(existingTx != null ? 'Daily log updated!' : 'Daily log saved successfully!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                    child: const Text('Save log', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DAILY TRANSACTION REPORT SCREEN
// -----------------------------------------------------------------------------
class DailyTransactionReportScreen extends StatefulWidget {
  final List<PoultryBatch> batches;
  final List<BatchTransaction> transactions;

  const DailyTransactionReportScreen({
    super.key,
    required this.batches,
    required this.transactions,
  });

  @override
  State<DailyTransactionReportScreen> createState() => _DailyTransactionReportScreenState();
}

class _DailyTransactionReportScreenState extends State<DailyTransactionReportScreen> {
  String? _selectedBatchId; // null means 'All'

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    final filteredTxs = widget.transactions.where((t) {
      if (_selectedBatchId == null) {
        // Only show for farmer's linked batches
        return widget.batches.any((b) => b.id == t.batchId);
      }
      return t.batchId == _selectedBatchId;
    }).toList();

    // Sort by date descending
    filteredTxs.sort((a, b) => b.date.compareTo(a.date));

    // Totals
    final totalMortality = filteredTxs.fold(0, (sum, t) => sum + t.mortalityReasons.values.fold(0, (s, val) => s + val));
    final totalFeedKg = filteredTxs.fold(0.0, (sum, t) => sum + t.feedItems.values.fold(0.0, (s, val) => s + val));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Daily Transaction Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Export CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report exported to Downloads folder!'), backgroundColor: AppTheme.success),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter card
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: AppTheme.grey600, size: 20),
                  const SizedBox(width: 12),
                  const Text('Filter Batch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedBatchId,
                        hint: const Text('All Batches', style: TextStyle(fontSize: 14)),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Batches', style: TextStyle(fontSize: 14)),
                          ),
                          ...widget.batches.map((b) => DropdownMenuItem<String?>(
                                value: b.id,
                                child: Text(b.batchName, style: const TextStyle(fontSize: 14)),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedBatchId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('Mortality Count', '$totalMortality Birds', AppTheme.primaryRed),
                  Container(width: 1, height: 28, color: AppTheme.grey300),
                  _summaryItem('Feed Intake', '${totalFeedKg.toStringAsFixed(1)} KG', Colors.orange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700))),
                  Expanded(flex: 2, child: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700))),
                  Expanded(flex: 1, child: Text('Age', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Mort', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('FCR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.grey700), textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),

          // Table body
          Expanded(
            child: filteredTxs.isEmpty
                ? const Center(child: Text('No daily logs found matching selection', style: TextStyle(color: AppTheme.grey500)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    itemCount: filteredTxs.length,
                    itemBuilder: (ctx, idx) {
                      final tx = filteredTxs[idx];
                      final b = widget.batches.firstWhere((batch) => batch.id == tx.batchId, orElse: () => PoultryBatch(id: '', batchName: 'Unknown', module: '', type: '', breedName: '', date: DateTime.now(), firstDayDate: DateTime.now(), stdLiftingAge: 42, chicksQuantity: 0, birdRate: 0.0));
                      final mort = tx.mortalityReasons.values.fold(0, (sum, val) => sum + val);
                      final feed = tx.feedItems.values.fold(0.0, (sum, val) => sum + val);

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: AppTheme.grey200, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text('${tx.date.day}/${tx.date.month}', style: const TextStyle(fontSize: 12, color: AppTheme.grey800))),
                            Expanded(flex: 2, child: Text(b.batchName, style: const TextStyle(fontSize: 12, color: AppTheme.grey800, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 1, child: Text('${tx.ageDays}d', style: const TextStyle(fontSize: 12, color: AppTheme.grey600), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('${tx.bodyWeight.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 12, color: AppTheme.grey600), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text('$mort', style: const TextStyle(fontSize: 12, color: AppTheme.primaryRed, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('${feed.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text(tx.fcr > 0 ? tx.fcr.toStringAsFixed(2) : '--', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ANALYTICS SCREEN WITH HIGH FIDELITY WIDGET CHARTS
// -----------------------------------------------------------------------------
class AnalyticsScreen extends StatefulWidget {
  final List<PoultryBatch> batches;
  final List<BatchTransaction> transactions;

  const AnalyticsScreen({
    super.key,
    required this.batches,
    required this.transactions,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _selectedBatchId; // null means 'All'

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    final filteredTxs = widget.transactions.where((t) {
      if (_selectedBatchId == null) {
        return widget.batches.any((b) => b.id == t.batchId);
      }
      return t.batchId == _selectedBatchId;
    }).toList();

    // Sort by date ascending for trend graphs
    filteredTxs.sort((a, b) => a.date.compareTo(b.date));

    // Calculate Feed Consumption Trends
    // Show last 7 days of logs
    final chartTxs = filteredTxs.length > 7 ? filteredTxs.sublist(filteredTxs.length - 7) : filteredTxs;

    // Calculate Mortality Breakdown Reasons
    int diseaseCount = 0;
    int heatCount = 0;
    int weaknessCount = 0;
    int accidentCount = 0;
    int otherCount = 0;

    for (var tx in filteredTxs) {
      diseaseCount += tx.mortalityReasons['Disease'] ?? 0;
      heatCount += tx.mortalityReasons['Heat Stroke'] ?? 0;
      weaknessCount += tx.mortalityReasons['Weakness'] ?? 0;
      accidentCount += tx.mortalityReasons['Accident'] ?? 0;
      otherCount += tx.mortalityReasons['Other'] ?? 0;
    }
    final int totalMortality = diseaseCount + heatCount + weaknessCount + accidentCount + otherCount;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Performance Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter dropdown card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppTheme.grey600, size: 20),
                    const SizedBox(width: 12),
                    const Text('View Batch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedBatchId,
                          hint: const Text('All Batches', style: TextStyle(fontSize: 14)),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Batches', style: TextStyle(fontSize: 14)),
                            ),
                            ...widget.batches.map((b) => DropdownMenuItem<String?>(
                                  value: b.id,
                                  child: Text(b.batchName, style: const TextStyle(fontSize: 14)),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedBatchId = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // CHART 1: Daily Feed Consumed (KG)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Feed Consumed (KG) — Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800)),
                    const SizedBox(height: 4),
                    const Text('Shows feed logs of last 7 entries', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                    const SizedBox(height: 20),
                    if (chartTxs.isEmpty)
                      const SizedBox(height: 120, child: Center(child: Text('No logging entries yet', style: TextStyle(fontSize: 12, color: AppTheme.grey400))))
                    else
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: chartTxs.map((tx) {
                            final double dailyFeedKg = tx.feedItems.values.fold(0.0, (sum, val) => sum + val);
                            // Max feed for height calculation
                            double maxFeed = chartTxs.fold(1.0, (maxVal, t) {
                              double fVal = t.feedItems.values.fold(0.0, (s, v) => s + v);
                              return fVal > maxVal ? fVal : maxVal;
                            });
                            double fillPercent = dailyFeedKg / maxFeed;
                            if (fillPercent < 0.05) fillPercent = 0.05; // min height
                            
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${dailyFeedKg.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                                const SizedBox(height: 4),
                                Container(
                                  width: 24,
                                  height: fillPercent * 100,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.orange, Colors.orangeAccent],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('${tx.date.day}/${tx.date.month}', style: const TextStyle(fontSize: 9, color: AppTheme.grey500)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // CHART 2: FCR Comparison (Actual vs Standard Curve)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Actual FCR vs. Cobb Standard FCR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800)),
                    const SizedBox(height: 4),
                    const Text('Green represents actual FCR, Blue standard Cobb curves', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                    const SizedBox(height: 20),
                    if (chartTxs.isEmpty)
                      const SizedBox(height: 120, child: Center(child: Text('No logging entries yet', style: TextStyle(fontSize: 12, color: AppTheme.grey400))))
                    else
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: chartTxs.map((tx) {
                            double actualFcr = tx.fcr;
                            double stdFcr = getStandardFCR(tx.ageDays);

                            // Calculate heights
                            double maxFcr = 2.5; // typical limit
                            double actualFill = (actualFcr / maxFcr).clamp(0.05, 1.0);
                            double stdFill = (stdFcr / maxFcr).clamp(0.05, 1.0);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Text(actualFcr > 0 ? actualFcr.toStringAsFixed(2) : '--', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                                    const SizedBox(width: 4),
                                    Text(stdFcr.toStringAsFixed(2), style: const TextStyle(fontSize: 8, color: Colors.blue)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Actual FCR Bar
                                    Container(
                                      width: 12,
                                      height: actualFill * 90,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    // Standard FCR Bar
                                    Container(
                                      width: 12,
                                      height: stdFill * 90,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Age: ${tx.ageDays}d', style: const TextStyle(fontSize: 9, color: AppTheme.grey500)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // CHART 3: Mortality Reasons Breakdown (Horizontal Stack/Bars)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mortality Analysis — Reason Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800)),
                    const SizedBox(height: 4),
                    Text('Total dead birds linked: $totalMortality', style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
                    const SizedBox(height: 20),
                    if (totalMortality == 0)
                      const SizedBox(height: 100, child: Center(child: Text('0 mortality reported', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))))
                    else ...[
                      _mortReasonRow('Disease', diseaseCount, totalMortality, Colors.red),
                      _mortReasonRow('Heat Stroke', heatCount, totalMortality, Colors.amber),
                      _mortReasonRow('Weakness', weaknessCount, totalMortality, Colors.orange),
                      _mortReasonRow('Accident', accidentCount, totalMortality, Colors.brown),
                      _mortReasonRow('Other', otherCount, totalMortality, Colors.grey),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _mortReasonRow(String reason, int count, int total, Color barColor) {
    double percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(reason, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey700)),
              Text('$count Birds (${(percent * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: AppTheme.grey100,
              child: Row(
                children: [
                  Expanded(
                    flex: (percent * 100).round(),
                    child: Container(color: barColor),
                  ),
                  Expanded(
                    flex: ((1 - percent) * 100).round(),
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
