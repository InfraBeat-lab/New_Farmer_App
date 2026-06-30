import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/health_check_service.dart';

import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/features/home/data/api_status.model.dart';

class ServerDownScreen extends StatefulWidget {
  final List<ApiStatus> failedApis;

  const ServerDownScreen({
    super.key,
    required this.failedApis,
  });

  @override
  State<ServerDownScreen> createState() => _ServerDownScreenState();
}

class _ServerDownScreenState extends State<ServerDownScreen> {
  bool _isRetrying = false;
  List<ApiStatus> _failedApis = [];

  @override
  void initState() {
    super.initState();
    _failedApis = widget.failedApis;
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);

    try {
      final apiResults = await HealthCheckService.checkApis();

      final failedApis = apiResults.where((e) => !e.isUp).toList();

      if (!mounted) return;

      // Still failing
      if (failedApis.isNotEmpty) {
        setState(() {
          _failedApis = failedApis;
        });

        return;
      }

      // APIs are UP
      final isLogin = LocalStorageService.getInt('IsLogin') ?? 0;
      final sessionId = LocalStorageService.getString('session_id');

      if (!mounted) return;

      if (isLogin == 1 && sessionId != null && sessionId.isNotEmpty) {
        context.go('/');
      } else {
        await LocalStorageService.remove('IsLogin');
        await LocalStorageService.remove('session_id');

        if (!mounted) return;

        context.go('/login');
      }
    } catch (e) {
      debugPrint('Retry Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Some services are unavailable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ..._failedApis.map(
                (api) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.error,
                      color: Colors.red,
                    ),
                    title: Text(api.name),
                    subtitle: Text(
                      api.error ?? 'Unavailable',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isRetrying
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _handleRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
