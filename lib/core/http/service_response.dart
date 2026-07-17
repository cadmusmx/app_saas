class ServiceResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  const ServiceResponse(this.success, {this.statusCode, this.data, this.message = ''});

  factory ServiceResponse.ok(T data, {int? statusCode}) =>
      ServiceResponse(true, data: data, statusCode: statusCode);

  factory ServiceResponse.error(String message, {int? statusCode}) =>
      ServiceResponse(false, message: message, statusCode: statusCode);
}
