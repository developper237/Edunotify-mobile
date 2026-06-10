import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  // IP Actuelle (AGL / Point d'accès PC)
  static const _baseUrl         = 'http://172.20.10.3:3001';
  static const _presenceBaseUrl = 'http://172.20.10.3:3004';
  static const _notifBaseUrl    = 'http://172.20.10.3:3003';
  static const _academicBaseUrl = 'http://172.20.10.3:3005';

  static final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ))..interceptors.add(_AuthInterceptor());

  static final _dioPresence = Dio(BaseOptions(baseUrl: _presenceBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioNotif    = Dio(BaseOptions(baseUrl: _notifBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioAcademic = Dio(BaseOptions(baseUrl: _academicBaseUrl))..interceptors.add(_AuthInterceptor());

  static Future<bool> isLoggedIn() async {
    final token = await Storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── AUTH SERVICE METHODS ──
  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final resp = await _dio.get(path, queryParameters: params);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final resp = await _dio.post(path, data: data);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    try {
      final resp = await _dio.patch(path, data: data);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    try {
      final resp = await _dio.put(path, data: data);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? params}) async {
    try {
      final resp = await _dio.delete(path, queryParameters: params);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // Utilisé par classe_delegue_screen.dart
  static Future<Map<String, dynamic>> postFormData(String path, {required String csvContent, required String filename}) async {
    try {
      final formData = FormData.fromMap({
        'fichier': MultipartFile.fromString(csvContent, filename: filename, contentType: DioMediaType('text', 'csv')),
      });
      final resp = await _dio.post(path, data: formData);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── PRESENCE SERVICE ──
  static Future<Map<String, dynamic>> postPresence(String path, {Map<String, dynamic>? data, required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.post(path, data: data, options: Options(headers: {'x-user-id': userId, 'x-user-role': role, 'x-classe-id': classeId ?? ''}));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> getPresence(String path, {required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.get(path, options: Options(headers: {'x-user-id': userId, 'x-user-role': role, 'x-classe-id': classeId ?? ''}));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> deletePresence(String path, {required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.delete(path, options: Options(headers: {'x-user-id': userId, 'x-user-role': role, 'x-classe-id': classeId ?? ''}));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── NOTIFICATION SERVICE ──
  static Future<Map<String, dynamic>> getNotif(String path, {required String userId, required String role, String? etablissementId, String? departementId, String? classeId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioNotif.get(path, queryParameters: params, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-etab-id': etablissementId ?? '',
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postNotif(String path, {Map<String, dynamic>? data, required String userId, required String role, String? etablissementId, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioNotif.post(path, data: data, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-etab-id': etablissementId ?? '',
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> putNotif(String path, {Map<String, dynamic>? data, required String userId, required String role, String? etablissementId, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioNotif.put(path, data: data, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-etab-id': etablissementId ?? '',
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── ACADEMIC SERVICE ──
  static Future<Map<String, dynamic>> getAcademic(String path, {required String userId, required String role, String? departementId, String? classeId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioAcademic.get(path, queryParameters: params, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postAcademic(String path, {Map<String, dynamic>? data, required String userId, required String role, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioAcademic.post(path, data: data, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> patchAcademic(String path, {Map<String, dynamic>? data, required String userId, required String role, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioAcademic.patch(path, data: data, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postAcademicFormData(String path, {required List<int> fileBytes, required String filename, required Map<String, String> fields, required String userId, required String role, String? departementId, String? classeId}) async {
    try {
      final formData = FormData.fromMap({
        'fichier': MultipartFile.fromBytes(fileBytes, filename: filename),
        ...fields,
      });
      final resp = await _dioAcademic.post(path, data: formData, options: Options(headers: {
        'x-user-id': userId,
        'x-user-role': role,
        'x-dept-id': departementId ?? '',
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── HELPERS ──
  static Future<String?> _refreshToken() async {
    try {
      final refresh = await Storage.getRefreshToken();
      if (refresh == null) return null;
      final dio = Dio(BaseOptions(baseUrl: _baseUrl));
      final resp = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
      final newToken = resp.data['accessToken'] ?? resp.data['data']?['accessToken'];
      if (newToken != null) await Storage.saveTokens(accessToken: newToken, refreshToken: refresh);
      return newToken;
    } catch (_) { return null; }
  }

  static ApiException _handle(DioException e) {
    final data = e.response?.data;
    final msg = data is Map ? (data['message'] ?? data['error'] ?? 'Erreur') : 'Erreur réseau';
    return ApiException(msg.toString(), statusCode: e.response?.statusCode);
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await Storage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/login')) {
      final newToken = await ApiClient._refreshToken();
      if (newToken != null) {
        final options = Options(method: err.requestOptions.method, headers: {...err.requestOptions.headers, 'Authorization': 'Bearer $newToken'});
        final clone = await Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl)).request(err.requestOptions.path, data: err.requestOptions.data, queryParameters: err.requestOptions.queryParameters, options: options);
        return handler.resolve(clone);
      }
    }
    handler.next(err);
  }
}