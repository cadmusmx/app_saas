class ServiceResponse<T> {
  final bool success;
  final int? statusCode;
  final T? data;
  final String? message;

  const ServiceResponse({required this.success, this.statusCode, this.data, this.message});

  factory ServiceResponse.ok(T data, {int? statusCode}) =>
      ServiceResponse(success: true, data: data, statusCode: statusCode);

  factory ServiceResponse.error(String message, {int? statusCode}) =>
      ServiceResponse(success: false, message: message, statusCode: statusCode);
}
