// core/sse_client.dart
//
// Client SSE (Server-Sent Events) minimal pour recevoir les événements en
// temps réel depuis le notification-service. Basé sur Dio en mode stream afin
// de ne pas ajouter de dépendance native. En cas d'échec réseau, il se
// reconnecte avec un backoff — le polling classique reste le filet de sécurité.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'storage.dart';

typedef SseEventHandler = void Function(String event, Map<String, dynamic> data);

class SseClient {
  final String url;
  final bool Function() canListen;   // vérifie la présence du token utilisateur
  final Future<Map<String, String>> Function() headers;
  final SseEventHandler onEvent;

  Dio? _dio;
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;
  Timer? _retry;
  Timer? _heartbeatWatch;

  SseClient({
    required this.url,
    required this.canListen,
    required this.headers,
    required this.onEvent,
  });

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _retry?.cancel();
    _heartbeatWatch?.cancel();
    await _sub?.cancel();
    _sub = null;
    try { _dio?.close(force: true); } catch (_) {}
    _dio = null;
  }

  Future<void> _connect() async {
    if (!_running) return;
    if (!canListen()) return;

    try {
      final base = _dio ?? Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 0),
        responseType: ResponseType.stream,
      ));
      _dio = base;

      final hdrs = await headers();
      final resp = await base.get<ResponseBody>(
        url,
        options: Options(headers: hdrs, receiveTimeout: const Duration(seconds: 0)),
      );

      final stream = resp.data!.stream;
      var buffer = '';
      _sub = stream.listen((chunk) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        var idx = buffer.indexOf('\n\n');
        while (idx != -1) {
          final rawEvent = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);
          _parse(rawEvent);
          idx = buffer.indexOf('\n\n');
        }
        // Sécurité mémoire: si le buffer ne contient jamais de delimiteur
        // (flux anormal), on le plafonne.
        if (buffer.length > 65536) buffer = buffer.substring(buffer.length - 4096);
      }, onDone: () async {
        await _scheduleRetry();
      }, onError: (e) async {
        await _scheduleRetry();
      }, cancelOnError: true);

      // Watchdog: si aucune donnée pendant 60s (proxy silencieux), on reconnecte.
      _heartbeatWatch?.cancel();
      _heartbeatWatch = Timer.periodic(const Duration(seconds: 60), (_) {
        _sub?.cancel();
        _scheduleRetry();
      });
    } catch (e) {
      await _scheduleRetry();
    }
  }

  Future<void> _scheduleRetry() async {
    if (!_running) return;
    try { await _sub?.cancel(); } catch (_) {}
    _sub = null;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), _connect);
  }

  void _parse(String raw) {
    final lines = raw.split('\n');
    String? event;
    String? data;
    for (final line in lines) {
      if (line.startsWith('event:')) event = line.substring(6).trim();
      if (line.startsWith('data:'))  data  = line.substring(5).trim();
    }
    if (event == null || data == null) return;
    try {
      onEvent(event, jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      // données non-JSON : ignorer
    }
  }
}

// ── Helper pour construire les headers d'auth cohérents avec ApiClient ────
Future<Map<String, String>> buildAuthHeaders({
  required String userId,
  required String role,
  String? etablissementId,
  String? departementId,
  String? classeId,
}) async {
  final token = await Storage.getAccessToken();
  return {
    'Authorization': token != null ? 'Bearer $token' : '',
    'x-user-id':   userId,
    'x-user-role': role,
    'x-etab-id':   etablissementId ?? '',
    'x-dept-id':   departementId   ?? '',
    'x-classe-id': classeId        ?? '',
  };
}