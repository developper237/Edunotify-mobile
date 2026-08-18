import 'package:dio/dio.dart';
import 'storage.dart';
import 'package:flutter/widgets.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? body;
  ApiException(this.message, {this.statusCode, this.body});
  @override
  String toString() => message;
}

class ApiClient {
  // Callback global pour déconnexion forcée (établissement suspendu)
  static VoidCallback? _onForceLogout;
  static bool _forceLogoutPending = false;
  static void setForceLogoutCallback(VoidCallback cb) => _onForceLogout = cb;
  static void triggerForceLogout() {
    if (_forceLogoutPending) return;
    _forceLogoutPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onForceLogout?.call();
      _forceLogoutPending = false;
    });
  }

  // URLs de production — services déployés sur Render
  static String get _baseUrl         => 'https://smartcampus-auth.onrender.com';
  static String get _presenceBaseUrl => 'https://presence-service-q9wq.onrender.com';
  static String get _notifBaseUrl    => 'https://notification-service-1o8a.onrender.com';
  static String get _academicBaseUrl => 'https://academic-service-f5sm.onrender.com';
  static String get _chatbotBaseUrl  => 'https://chatbot-service-sh1b.onrender.com';
  // TODO: remplacer par l'URL Render du billing-service une fois déployé
  static String get _billingBaseUrl  => 'https://billing-service-36of.onrender.com';

  // Initialisation des instances Dio basées sur les getters dynamiques
  static final _dio         = Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 60)))..interceptors.add(_AuthInterceptor());
  static final _dioPresence = Dio(BaseOptions(baseUrl: _presenceBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioNotif    = Dio(BaseOptions(baseUrl: _notifBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioAcademic = Dio(BaseOptions(baseUrl: _academicBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioChatbot  = Dio(BaseOptions(baseUrl: _chatbotBaseUrl))..interceptors.add(_AuthInterceptor());
  static final _dioBilling  = Dio(BaseOptions(baseUrl: _billingBaseUrl))..interceptors.add(_AuthInterceptor());

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

  // ── BILLING SERVICE (abonnements & paiement Mobile Money) ─────
  static Future<Map<String, dynamic>> getBilling(String path, {required String userId, required String role, String? etablissementId, Map<String, dynamic>? params}) async {
    try {
      final resp = await _dioBilling.get(path, queryParameters: params, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
  }

  static Future<Map<String, dynamic>> postBilling(String path, {Map<String, dynamic>? data, required String userId, required String role, String? etablissementId}) async {
    try {
      final resp = await _dioBilling.post(path, data: data, options: Options(headers: {
        'x-user-id':   userId,
        'x-user-role': role,
        'x-etab-id':   etablissementId ?? '',
      }));
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handle(e); }
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
    final code = data is Map ? data['code'] : null;
    final msg  = data is Map
        ? (data['message'] ?? data['error'] ?? 'Erreur')
        : 'Erreur réseau';

    // Déconnexion automatique si établissement suspendu
    if (code == 'ETABLISSEMENT_SUSPENDU') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Storage.clear();
        ApiClient.triggerForceLogout();
      });
    }

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
    final data = err.response?.data;
    final code = data is Map ? data['code'] : null;

    // ── Établissement suspendu → déconnexion immédiate ──────────
    if (err.response?.statusCode == 403 &&
        code == 'ETABLISSEMENT_SUSPENDU') {
      await Storage.clear();
      ApiClient.triggerForceLogout();
      handler.next(err);
      return;
    }

    // ── Token expiré → tentative de refresh ─────────────────────
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/login')) {
      final newToken = await ApiClient._refreshToken();
      if (newToken != null) {
        final options = Options(
          method:  err.requestOptions.method,
          headers: {
            ...err.requestOptions.headers,
            'Authorization': 'Bearer $newToken',
          },
        );
        final clone = await Dio(
          BaseOptions(baseUrl: err.requestOptions.baseUrl),
        ).request(
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
