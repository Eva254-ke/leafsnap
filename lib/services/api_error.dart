import 'dart:io';

class ApiRateLimitException implements Exception {
  ApiRateLimitException([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'Request limit reached.';
}

bool isRateLimitError(Object error) {
  if (error is ApiRateLimitException) {
    return true;
  }
  if (error is HttpException) {
    return RegExp(r'\b429\b').hasMatch(error.message);
  }
  return false;
}

class ApiUnavailableException implements Exception {
  const ApiUnavailableException([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'Service unavailable.';
}

bool isNetworkApiError(Object error) {
  if (error is SocketException) {
    return true;
  }
  if (error is HttpException) {
    final message = error.message.toLowerCase();
    return message.contains('timed out') ||
        message.contains('failed host lookup') ||
        message.contains('connection') ||
        message.contains('network');
  }
  return false;
}
