import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/api_constants.dart';

/// Client Dio unique, injecte automatiquement le ID token Firebase.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl, connectTimeout: Duration(seconds: 15)));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.post(path, data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.patch(path, data: data);
    return Map<String, dynamic>.from(res.data);
  }
}
