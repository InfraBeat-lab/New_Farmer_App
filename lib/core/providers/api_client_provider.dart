import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poultryos_farmer_app/features/flock_placement/infrastructure/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});