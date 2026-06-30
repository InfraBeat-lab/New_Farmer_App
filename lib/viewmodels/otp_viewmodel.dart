// lib/viewmodels/otp_viewmodel.dart
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poultryos_farmer_app/features/flock_placement/infrastructure/api_client.dart';
import 'package:poultryos_farmer_app/features/services/otp_service.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ---------------------------------------------------------------------------
// Shared enums / constants
// ---------------------------------------------------------------------------

enum OtpViewState { initial, loading, success, error }

String get _kServerLink =>
    dotenv.env['SERVER_LINK'] ?? 'http://otp.poultryos.in/api/v1';
int get _kCompanyCode => 6;
String get _kAppVersion => dotenv.env['APP_VERSION'] ?? '4.0.2';

// ---------------------------------------------------------------------------
// OtpService provider
// ---------------------------------------------------------------------------

final otpServiceProvider = Provider<OtpService>((_) {
  return OtpService(serverLink: _kServerLink, companyCode: _kCompanyCode);
});

// ---------------------------------------------------------------------------
// GenerateOtpViewModel
// ---------------------------------------------------------------------------

class GenerateOtpState {
  final OtpViewState status;
  final String errorMessage;

  const GenerateOtpState({
    this.status = OtpViewState.initial,
    this.errorMessage = '',
  });

  GenerateOtpState copyWith({OtpViewState? status, String? errorMessage}) {
    return GenerateOtpState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GenerateOtpNotifier extends Notifier<GenerateOtpState> {
  final Connectivity _connectivity = Connectivity();

  @override
  GenerateOtpState build() {
    return const GenerateOtpState();
  }

  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<String> _getDeviceId() async {
    final stored = LocalStorageService.getString('IMEI');
    if (stored != null && stored.isNotEmpty) return stored;

    String deviceId = 'unknown-device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'ios-device';
      } else {
        // Web / desktop fallback
        deviceId = 'web-device-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (_) {
      deviceId = 'fallback-device-id';
    }

    LocalStorageService.setString('IMEI', deviceId);
    return deviceId;
  }

  Future<void> generateOtp(String mobileNumber) async {
    if (mobileNumber.isEmpty ||
        mobileNumber.length != 10 ||
        !RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobileNumber)) {
      state = state.copyWith(
        status: OtpViewState.error,
        errorMessage: 'Please enter a valid 10-digit mobile number.',
      );
      return;
    }

    if (!await _isConnected()) {
      state = state.copyWith(
        status: OtpViewState.error,
        errorMessage: 'No internet connection. Please turn on internet.',
      );
      return;
    }

    state = state.copyWith(status: OtpViewState.loading, errorMessage: '');

    try {
      final imeiNo = await _getDeviceId();
      await ref.read(otpServiceProvider).generateOtp(mobileNumber, imeiNo);

      await LocalStorageService.setString('UserMobile', mobileNumber);
      await LocalStorageService.setString('IMEI', imeiNo);

      state = state.copyWith(status: OtpViewState.success);
    } catch (e) {
      state = state.copyWith(
        status: OtpViewState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void resetState() {
    state = const GenerateOtpState();
  }
}

final generateOtpProvider =
    NotifierProvider<GenerateOtpNotifier, GenerateOtpState>(() {
  return GenerateOtpNotifier();
});

// ---------------------------------------------------------------------------
// VerifyOtpViewModel
// ---------------------------------------------------------------------------

enum VerifyOtpStatus { initial, loading, success, error, updateRequired }

class VerifyOtpState {
  final VerifyOtpStatus status;
  final String errorMessage;
  final int resendCounter;
  final bool canResend;

  const VerifyOtpState({
    this.status = VerifyOtpStatus.initial,
    this.errorMessage = '',
    this.resendCounter = 30,
    this.canResend = false,
  });

  VerifyOtpState copyWith({
    VerifyOtpStatus? status,
    String? errorMessage,
    int? resendCounter,
    bool? canResend,
  }) {
    return VerifyOtpState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      resendCounter: resendCounter ?? this.resendCounter,
      canResend: canResend ?? this.canResend,
    );
  }
}

class VerifyOtpNotifier extends Notifier<VerifyOtpState> {
  final Connectivity _connectivity = Connectivity();
  bool _mounted = true;

  @override
  VerifyOtpState build() {
    _mounted = true;
    ref.onDispose(() => _mounted = false);

    // We defer startResendTimer slightly allowing build to complete
    Future.microtask(() => startResendTimer());
    return const VerifyOtpState();
  }

  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result.first != ConnectivityResult.none;
  }

  // -------------------------------------------------------------------------
  // Public: start / reset resend countdown (30 s)
  // -------------------------------------------------------------------------
  void startResendTimer() {
    state = state.copyWith(canResend: false, resendCounter: 30);
    _tickDown();
  }

  void _tickDown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_mounted) return;
      final next = state.resendCounter - 1;
      if (next <= 0) {
        state = state.copyWith(resendCounter: 0, canResend: true);
      } else {
        state = state.copyWith(resendCounter: next);
        _tickDown();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Verify OTP → then SAP Login
  // -------------------------------------------------------------------------
  Future<void> verifyOtp(String mobileNumber, String otp) async {
    if (otp.isEmpty || otp.length != 4 || !RegExp(r'^[0-9]+$').hasMatch(otp)) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'Please enter a valid 4-digit OTP.',
      );
      return;
    }

    if (!await _isConnected()) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'No internet connection. Please turn on internet.',
      );
      return;
    }

    state = state.copyWith(status: VerifyOtpStatus.loading, errorMessage: '');

    try {
      final imeiNo = LocalStorageService.getString('IMEI') ?? '';
      final version = LocalStorageService.getString('version') ?? _kAppVersion;

      final response = await ref
          .read(otpServiceProvider)
          .verifyOtp(mobileNumber, otp, imeiNo, version);

      final statusMessage = response['status_message']?.toString() ?? '';
      print('[VerifyOtp] Status Message: $statusMessage');
      if (statusMessage == 'Authorized user') {
        // Save the temp server link returned by the OTP server
        final tempLink = response['data']?.toString() ?? '';
        await LocalStorageService.setString('tempLink', tempLink);
        await LocalStorageService.setString('mobile_number', mobileNumber);

        // Proceed to SAP B1 login
        await _callSapLogin();
      } else if (statusMessage.toLowerCase().contains('update')) {
        state = state.copyWith(status: VerifyOtpStatus.updateRequired);
      } else {
        state = state.copyWith(
          status: VerifyOtpStatus.error,
          errorMessage: statusMessage.isNotEmpty
              ? statusMessage
              : 'OTP verification failed. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _callSapLogin() async {
    try {
      final mobileNumber = LocalStorageService.getString('UserMobile') ?? '';

      // ✅ STEP 1: SAP LOGIN (creates session)
      final apiClient = ApiClient();
      await apiClient.login();

      debugPrint('[VerifyOtp] SAP Login successful');

      // ✅ STEP 2: FETCH USER FROM SAP
      final response = await apiClient.get(
        'view.svc/B1_LoginViewB1SLQuery',
        queryParameters: {
          r'$filter':
              "mobile eq '$mobileNumber' or pager eq '$mobileNumber' or homeTel eq '$mobileNumber'",
        },
      );

      final data = response.data;

      if (data['value'] == null || data['value'].isEmpty) {
        throw "No SAP user found";
      }

      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
        data['value'],
      );

      // ✅ STEP 3: PROCESS USER DATA (reuse existing logic)
      await _processSapUserData(users);

      await LocalStorageService.setBool('isOpenUser', false);
      await LocalStorageService.setInt('IsLogin', 1);

      state = state.copyWith(status: VerifyOtpStatus.success);
    } catch (e) {
      debugPrint('SAP Flow failed: $e');

      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _processSapUserData(
    List<Map<String, dynamic>> users,
  ) async {
    for (final user in users) {
      await LocalStorageService.setString(
          'profileImage', user['ProfilePicture'] ?? '');

      // ❗ AuthToken no longer used
      await LocalStorageService.setString('user_Id', user['UserID'] ?? '');

      final String resolvedName = (user['Name'] ??
                  user['UserName'] ??
                  user['userName'] ??
                  user['FullName'] ??
                  user['fullName'] ??
                  user['empName'] ??
                  user['EmpName'] ??
                  user['U_Name'] ??
                  user['U_UsrName'])
              ?.toString()
              .trim() ??
          '';

      final String roleRaw =
          (user['userRole'] ?? user['UserRole'] ?? '').toString().trim();

      var role = roleRaw.toLowerCase();
      role = role.replaceAll(RegExp(r'[\s]+'), '_');
      role = role.replaceAll(RegExp(r'_+'), '_');

      if (resolvedName.isNotEmpty) {
        await LocalStorageService.setString('UserSession', resolvedName);
      }

      switch (role) {
        case 'branch_manager':
          await LocalStorageService.setString('mangerID', user['UserID'] ?? '');
          await LocalStorageService.setString('empID', user['UserID'] ?? '');
          await LocalStorageService.setString('mangerName', resolvedName);
          break;

        case 'farmer':
          await LocalStorageService.setString('farmerID', user['UserID'] ?? '');
          await LocalStorageService.setString('farmerName', resolvedName);
          break;

        case 'line_supervisor':
          await LocalStorageService.setString(
              'supervisorID', user['UserID'] ?? '');
          await LocalStorageService.setString('empID', user['UserID'] ?? '');
          await LocalStorageService.setString('supervisorName', resolvedName);
          break;

        case 'doctor':
          await LocalStorageService.setString('doctorID', user['UserID'] ?? '');
          await LocalStorageService.setString('empID', user['UserID'] ?? '');
          await LocalStorageService.setString('doctorName', resolvedName);
          break;

        case 'management':
          await LocalStorageService.setString(
              'managementID', user['UserID'] ?? '');
          await LocalStorageService.setString('empID', user['UserID'] ?? '');
          await LocalStorageService.setString('managementName', resolvedName);
          break;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Resend OTP
  // -------------------------------------------------------------------------
  Future<void> resendOtp(String mobileNumber) async {
    if (!state.canResend) return;

    if (!await _isConnected()) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'No internet connection.',
      );
      return;
    }

    state = state.copyWith(status: VerifyOtpStatus.loading, errorMessage: '');

    try {
      final imeiNo = LocalStorageService.getString('IMEI') ?? '';
      await ref.read(otpServiceProvider).resendOtp(mobileNumber, imeiNo);
      state = state.copyWith(status: VerifyOtpStatus.initial);
      startResendTimer();
    } catch (e) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void resetState() {
    state = const VerifyOtpState();
  }
}

final verifyOtpProvider = NotifierProvider<VerifyOtpNotifier, VerifyOtpState>(
  () {
    return VerifyOtpNotifier();
  },
);

// ---------------------------------------------------------------------------
// SignOut helper
// ---------------------------------------------------------------------------

/// Clears all auth-related data from SharedPreferences.
/// Call this before navigating to the login screen.
Future<void> signOut() async {
  await LocalStorageService.remove('IsLogin');
  await LocalStorageService.remove('session_id');
  await LocalStorageService.remove('UserMobile');
  await LocalStorageService.remove('mobile_number');
  await LocalStorageService.remove('IMEI');
  await LocalStorageService.remove('tempLink');
  await LocalStorageService.remove('getIds');
  await LocalStorageService.remove('AuthToken');
  await LocalStorageService.remove('UserSession');
  await LocalStorageService.remove('user_Id');
  await LocalStorageService.remove('profileImage');
  await LocalStorageService.remove('isOpenUser');
  await LocalStorageService.remove('mangerID');
  await LocalStorageService.remove('empID');
  await LocalStorageService.remove('mangerName');
  await LocalStorageService.remove('farmerID');
  await LocalStorageService.remove('farmerName');
  await LocalStorageService.remove('supervisorID');
  await LocalStorageService.remove('supervisorName');
  await LocalStorageService.remove('doctorID');
  await LocalStorageService.remove('doctorName');
  await LocalStorageService.remove('managementID');
  await LocalStorageService.remove('managementName');
}
