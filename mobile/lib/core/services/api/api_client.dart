import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/api_constants.dart';

/// Client Dio unique, injecte automatiquement le ID token Firebase.
/// Toute erreur HTTP est retransformée en Exception avec le VRAI message
/// renvoyé par le backend (`{ error: "..." }`), au lieu du texte générique
/// "DioException [bad response]..." qui ne veut rien dire pour l'utilisateur
/// ni pour le débogage.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl, connectTimeout: const Duration(seconds: 15)));
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

  Exception _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return Exception(data['error'].toString());
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return Exception('délai dépassé, vérifiez votre connexion');
    }
    if (e.type == DioExceptionType.connectionError) {
      return Exception('pas de connexion réseau');
    }
    return Exception(e.message ?? 'erreur réseau');
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await _dio.post(path, data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await _dio.patch(path, data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await _dio.delete(path, data: data);
      return res.data is Map ? Map<String, dynamic>.from(res.data) : {};
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }
}
