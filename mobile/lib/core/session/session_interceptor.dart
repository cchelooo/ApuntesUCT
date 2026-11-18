import 'package:dio/dio.dart';

import 'session_controller.dart';

class SessionInterceptor extends Interceptor {
  SessionInterceptor(this.session, this.gateway);
  final SessionController session;
  final Uri gateway;
  static const _credential = 'apuntes.session.credential';
  static const _publicAuth = {
    '/auth/login',
    '/auth/register',
    '/auth/forgot-password',
    '/auth/reset-password',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (!uri.hasScheme || !gateway.hasScheme) {
      handler.next(options);
      return;
    }
    final prefix = gateway.path.replaceFirst(RegExp(r'/$'), '');
    final isGateway =
        uri.origin == gateway.origin &&
        (uri.path == prefix || uri.path.startsWith('$prefix/'));
    final path = isGateway ? uri.path.substring(prefix.length) : '';
    if (!isGateway || _publicAuth.contains(path)) {
      options.headers.removeWhere(
        (key, _) => key.toLowerCase() == 'authorization',
      );
    } else {
      final current = session.current;
      if (current != null) {
        options.headers['Authorization'] = 'Bearer ${current.accessToken}';
        options.extra[_credential] = current.accessToken;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final credential = err.requestOptions.extra[_credential];
    if (err.response?.statusCode == 401 && credential is String) {
      try {
        await session.rejectCredential(credential);
      } on Object {
        /* memory already cleared */
      }
    }
    handler.next(err);
  }
}
