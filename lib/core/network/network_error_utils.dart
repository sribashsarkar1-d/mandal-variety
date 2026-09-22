import 'dart:io';

const String kNetworkErrorMessage =
    'No internet connection. Please check your network and try again.';

bool isNetworkError(Object? error) {
  if (error == null) return false;
  if (error is SocketException) return true;
  
  final msg = error.toString().toLowerCase();
  
  // Be strict. Do not match 'timeout' or general 'internet' substrings which could yield false positives.
  return msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('no internet connection');
}
