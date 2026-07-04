import 'package:dio/dio.dart';

class ApiService {
  static String get _host {
    final host = Uri.base.host;
    return host.isNotEmpty ? host : "127.0.0.1";
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://$_host:5000/api",
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
}