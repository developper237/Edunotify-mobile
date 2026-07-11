import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'storage.dart';
import 'dart:convert';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? body;
  ApiException(this.message, {this.statusCode, this.body});
  @override
  String toString() => message;
}

class ApiClient {
  // 💡 IP universelle issue de la carte réseau Wi-Fi active
  // Si non connecté au Wi-Fi,cette valeure peux être remplaceé par 'localhost'
  //static const String _devHost = '192.168.137.105';
  static const String _devHost = '192.168.43.252';

  // Définition dynamique des URLs de base pour s'adapter à toutes tes plateformes
  static String get _baseUrl         => 'http://$_devHost:3001';
  static String get _presenceBaseUrl => 'http://$_devHost:3004';
  static String get _notifBaseUrl    => 'http://$_devHost:3003';
  static String get _academicBaseUrl => 'http://$_devHost:3005';
  static String get _chatbotBaseUrl  => 'http://$_devHost:8085';

  // Initialisation des instances Dio basées sur les getters dynamiques
  static final _dio         = Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 60)))..interceptors.add(_AuthInterceptor());
  static final _dioPresence = Dio(BaseOptions(baseUrl: _presenceBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioNotif    = Dio(BaseOptions(baseUrl: _notifBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioAcademic = Dio(BaseOptions(baseUrl: _academicBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioChatbot  = Dio(BaseOptions(baseUrl: _chatbotBaseUrl))..interceptors.add(_AuthInterceptor());

  static Future<bool> isLoggedIn() async {
    final token = await Storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── AUTH SERVICE ──────────────────────────────────────────────
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

  static Future<Map<String, dynamic>> postFormData(String path, {required String csvContent, required String filename}) async {
    try {
      final formData = FormData.fromMap({
        'fichier': MultipartFile.fromString(csvContent, filename: filename, contentType: DioMediaType('text', 'csv')),
      });
      final resp = await _dio.post(path, data: formData);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── Upload du logo de l'établissement (admin uniquement, vérifié côté backend) ──
  static Future<Map<String, dynamic>> uploadLogoEtablissement({
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'logo': MultipartFile.fromBytes(fileBytes, filename: filename),
      });
      final resp = await _dio.patch('/auth/etablissement/logo', data: formData);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── PRESENCE SERVICE ──────────────────────────────────────────
  static Future<Map<String, dynamic>> postPresence(String path, {Map<String, dynamic>? data, required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.post(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> getPresence(String path, {required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.get(path, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> deletePresence(String path, {required String userId, required String role, String? classeId}) async {
    try {
      final resp = await _dioPresence.delete(path, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-classe-id': classeId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── NOTIFICATION SERVICE ──────────────────────────────────────
  static Future<Map<String, dynamic>> getNotif(String path, {required String userId, required String role, String? etablissementId, String? departementId, String? classeId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioNotif.get(path, queryParameters: params, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
        'x-dept-id':   departementId   ?? '',
        'x-classe-id': classeId        ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postNotif(String path, {Map<String, dynamic>? data, required String userId, required String role, String? etablissementId, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioNotif.post(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
        'x-dept-id':   departementId   ?? '',
        'x-classe-id': classeId        ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> putNotif(String path, {Map<String, dynamic>? data, required String userId, required String role, String? etablissementId, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioNotif.put(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
        'x-dept-id':   departementId   ?? '',
        'x-classe-id': classeId        ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> deleteNotif(String path, {required String userId, required String role, String? etablissementId, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioNotif.delete(path, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
        'x-dept-id':   departementId   ?? '',
        'x-classe-id': classeId        ?? '',
      }));
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── CHATBOT SERVICE ───────────────────────────────────────────
  static Future<Map<String, dynamic>> postChatbot(String path, {Map<String, dynamic>? data, required String userId, required String role}) async {
    try {
      final resp = await _dioChatbot.post(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<dynamic> getChatbot(String path, {required String userId, required String role}) async {
    try {
      final resp = await _dioChatbot.get(path, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
      }));
      return resp.data;
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── ACADEMIC SERVICE ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getAcademic(String path, {required String userId, required String role, String? departementId, String? classeId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioAcademic.get(path, queryParameters: params, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-dept-id':   departementId ?? '',
        'x-classe-id': classeId      ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postAcademic(String path, {Map<String, dynamic>? data, required String userId, required String role, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioAcademic.post(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-dept-id':   departementId ?? '',
        'x-classe-id': classeId      ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> patchAcademic(String path, {Map<String, dynamic>? data, required String userId, required String role, String? departementId, String? classeId}) async {
    try {
      final resp = await _dioAcademic.patch(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-dept-id':   departementId ?? '',
        'x-classe-id': classeId      ?? '',
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
        'x-user-id':   userId,
        'x-user-role': role,
        'x-dept-id':   departementId ?? '',
        'x-classe-id': classeId      ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> deleteAcademic(String path, {required String userId, required String role, String? departementId, String? classeId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioAcademic.delete(path, queryParameters: params, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-dept-id':   departementId ?? '',
        'x-classe-id': classeId      ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  // ── HELPERS ──────────────────────────────────────────────────
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
    final msg  = data is Map
        ? (data['message'] ?? data['error'] ?? 'Erreur')
        : 'Erreur réseau';
    return ApiException(
      msg.toString(),
      statusCode: e.response?.statusCode,
      body: data is Map<String, dynamic> ? data : null,
    );
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
        final options = Options(
          method:  err.requestOptions.method,
          headers: {...err.requestOptions.headers, 'Authorization': 'Bearer $newToken'},
        );
        final clone = await Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl)).request(
          err.requestOptions.path,
          data:            err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options:         options,
        );
        return handler.resolve(clone);
      }
    }
    handler.next(err);
  }
}