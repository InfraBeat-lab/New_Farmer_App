class ApiStatus {
  final String name;
  final String url;
  final bool isUp;
  final String? error;
  final int? statusCode;

  ApiStatus({
    required this.name,
    required this.url,
    required this.isUp,
    this.error,
    this.statusCode,
  });
}
