import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../home/home_screen.dart';
import 'presence_archive.dart';
import 'pdf_service.dart' as pdf_service;

// ══════════════════════════════════════════════════════════════════
// MODÈLES & PROVIDERS
// ══════════════════════════════════════════════════════════════════

enum PresenceStatus { idle, loading, success, error }
enum SessionStatus  { idle, active, closed }

class SessionData {
  final String code;
  final String matiere;
  final String professeur;
  final String salle;
  final String type;
  final DateTime ouverteLe;
  final int dureeMinutes;
  final List<String> presents;
  final bool geoActif;
  final double? gpsLat;
  final double? gpsLng;
  final int? rayonMetres;

  const SessionData({
    required this.code,
    required this.matiere,
    required this.professeur,
    required this.salle,
    required this.type,
    required this.ouverteLe,
    required this.dureeMinutes,
    this.presents = const [],
    this.geoActif = false,
    this.gpsLat,
    this.gpsLng,
    this.rayonMetres,
  });

  int get ttlRestant {
    final expiry = ouverteLe.add(Duration(minutes: dureeMinutes));
    final diff   = expiry.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired => ttlRestant == 0;

  SessionData copyWith({List<String>? presents}) => SessionData(
    code:         code,
    matiere:      matiere,
    professeur:   professeur,
    salle:        salle,
    type:         type,
    ouverteLe:    ouverteLe,
    dureeMinutes: dureeMinutes,
    presents:     presents ?? this.presents,
    geoActif:     geoActif,
    gpsLat:       gpsLat,
    gpsLng:       gpsLng,
    rayonMetres:  rayonMetres,
  );
}

class PresenceHistorique {
  final String sessionId;
  final String matiere;
  final String professeur;
  final String salle;
  final String type;
  final DateTime date;
  final bool present;
  final String methode;

  const PresenceHistorique({
    required this.sessionId,
    required this.matiere,
    required this.professeur,
    required this.salle,
    required this.type,
    required this.date,
    required this.present,
    this.methode = 'code_session',
  });

  factory PresenceHistorique.fromJson(Map<String, dynamic> j) {
    final dateStr = (j['date'] ?? j['confirmeA'] ?? j['ouverteLe']) as String?;
    final bool present;
    if (j.containsKey('present')) {
      present = j['present'] as bool? ?? false;
    } else {
      present = (j['statut'] as String? ?? '') == 'present';
    }
    return PresenceHistorique(
      sessionId:  j['sessionId'] as String? ?? j['id'] as String? ?? '',
      matiere:    j['matiere']    as String? ?? '',
      professeur: j['professeur'] as String? ?? '',
      salle:      j['salle']      as String? ?? '',
      type:       j['type']       as String? ?? '',
      date:       dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
      present:    present,
      methode:    j['methode']    as String? ?? 'code_session',
    );
  }
}

final sessionStatusProvider   = StateProvider<SessionStatus>((_) => SessionStatus.idle);
final sessionDataProvider      = StateProvider<SessionData?>((_) => null);
final presenceStatusProvider   = StateProvider<PresenceStatus>((_) => PresenceStatus.idle);
final presenceErrorProvider    = StateProvider<String?>((_) => null);
final dernierSessionIdProvider = StateProvider<String?>((ref) => null);

final historiqueEtudiantProvider =
StateNotifierProvider<HistoriqueEtudiantNotifier,
    AsyncValue<List<PresenceHistorique>>>(
      (_) => HistoriqueEtudiantNotifier(),
);

class HistoriqueEtudiantNotifier
    extends StateNotifier<AsyncValue<List<PresenceHistorique>>> {
  HistoriqueEtudiantNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role, {String? classeId}) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getPresence(
        '/presence/historique/etudiant',
        userId:   userId,
        role:     role,
        classeId: classeId,
      );
      final liste = (resp['historique'] as List<dynamic>? ?? [])
          .map((e) => PresenceHistorique.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(liste);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void ajouterPresence(PresenceHistorique h) {
    final actuel = state.valueOrNull ?? [];
    state = AsyncValue.data([h, ...actuel]);
  }
}

// ══════════════════════════════════════════════════════════════════
// GPS HELPER
// ══════════════════════════════════════════════════════════════════

Future<Position?> _obtenirPosition() async {
  bool serviceActif = await Geolocator.isLocationServiceEnabled();
  if (!serviceActif) return null;
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  if (permission == LocationPermission.deniedForever) return null;
  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
}

// ══════════════════════════════════════════════════════════════════
// ROUTER
// ══════════════════════════════════════════════════════════════════

class PresenceScreen extends ConsumerWidget {
  const PresenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role ?? 'etudiant';
    if (role == 'delegue') return const _PresenceDelegue();
    return const _PresenceEtudiant();
  }
}

// ══════════════════════════════════════════════════════════════════
// VUE ÉTUDIANT
// ══════════════════════════════════════════════════════════════════

class _PresenceEtudiant extends ConsumerStatefulWidget {
  const _PresenceEtudiant();

  @override
  ConsumerState<_PresenceEtudiant> createState() => _PresenceEtudiantState();
}

class _PresenceEtudiantState extends ConsumerState<_PresenceEtudiant> {
  bool   _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkSessionActive());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkSessionActive() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final resp = await ApiClient.getPresence(
        '/presence/session-active',
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      if (!mounted) return;

      final session = resp['session'];
      if (session != null) {
        final dejaConfirme = session['dejaConfirme'] as bool? ?? false;
        if (dejaConfirme) {
          ref.read(presenceStatusProvider.notifier).state =
              PresenceStatus.success;
        } else {
          ref.read(sessionDataProvider.notifier).state = SessionData(
            code:         session['code'] ?? '',
            matiere:      session['matiere']    ?? '',
            professeur:   session['professeur'] ?? '',
            salle:        session['salle']       ?? '',
            type:         session['type']        ?? 'Cours',
            ouverteLe:    DateTime.now(),
            dureeMinutes: session['ttlRestant'] != null
                ? (session['ttlRestant'] as int) ~/ 60
                : 5,
            geoActif:    session['geoRequise'] as bool? ?? false,
            rayonMetres: session['rayonMetres'] as int?,
          );
          ref.read(sessionStatusProvider.notifier).state =
              SessionStatus.active;

          _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
            if (!mounted) { _timer?.cancel(); return; }
            if (ref.read(presenceStatusProvider) == PresenceStatus.success) {
              _timer?.cancel();
              return;
            }
            await _checkSessionActive();
          });
        }
      } else {
        // Pas de session active — reset si l'état était active
        if (ref.read(sessionStatusProvider) == SessionStatus.active) {
          ref.read(sessionStatusProvider.notifier).state = SessionStatus.idle;
          ref.read(sessionDataProvider.notifier).state   = null;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Écoute sessionActiveProvider (mis à jour par home_screen)
    // pour déclencher un refresh quand une session démarre
    final hasActiveSession = ref.watch(sessionActiveProvider);
    final sessionStatus    = ref.watch(sessionStatusProvider);
    final confirmStatus    = ref.watch(presenceStatusProvider);
    final session          = ref.watch(sessionDataProvider);

    // Si le home détecte une session mais cet écran est idle → refresh
    if (hasActiveSession &&
        sessionStatus == SessionStatus.idle &&
        confirmStatus == PresenceStatus.idle) {
      _checkSessionActive();
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.cyan, strokeWidth: 2),
        ),
      );
    }

    if ((hasActiveSession || sessionStatus == SessionStatus.active) &&
        session != null &&
        !session.isExpired &&
        confirmStatus != PresenceStatus.success) {
      return _EtudiantSessionActive(session: session);
    }

    if (confirmStatus == PresenceStatus.success) {
      return _SuccessView(
        session: session,
        onReset: () {
          _timer?.cancel();
          ref.read(presenceStatusProvider.notifier).state =
              PresenceStatus.idle;
          ref.read(presenceErrorProvider.notifier).state  = null;
          ref.read(sessionStatusProvider.notifier).state  =
              SessionStatus.idle;
          ref.invalidate(sessionActiveProvider);
        },
      );
    }

    return const _EtudiantHistorique();
  }
}

// ── Session active côté étudiant ──────────────────────────────────

class _EtudiantSessionActive extends ConsumerStatefulWidget {
  final SessionData session;
  const _EtudiantSessionActive({required this.session});

  @override
  ConsumerState<_EtudiantSessionActive> createState() =>
      _EtudiantSessionActiveState();
}

class _EtudiantSessionActiveState
    extends ConsumerState<_EtudiantSessionActive> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focuses     = List.generate(6, (_) => FocusNode());
  late final Stream<int> _ticker;
  bool    _gpsEnCours = false;
  String? _gpsErreur;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focuses) f.unfocus();
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  void _onDigit(int index, String value) {
    if (value.length == 1 && index < 5) _focuses[index + 1].requestFocus();
    if (value.isEmpty && index > 0)     _focuses[index - 1].requestFocus();
    setState(() {});
  }

  void _clear() {
    for (final c in _controllers) c.clear();
    _focuses[0].requestFocus();
    ref.read(presenceStatusProvider.notifier).state = PresenceStatus.idle;
    ref.read(presenceErrorProvider.notifier).state  = null;
    setState(() { _gpsErreur = null; });
  }

  Future<void> _confirm() async {
    if (code.length < 6) return;
    ref.read(presenceStatusProvider.notifier).state = PresenceStatus.loading;
    ref.read(presenceErrorProvider.notifier).state  = null;
    setState(() { _gpsErreur = null; });

    double? latitude;
    double? longitude;

    if (widget.session.geoActif) {
      setState(() => _gpsEnCours = true);
      try {
        final position = await _obtenirPosition();
        if (position == null) {
          setState(() {
            _gpsEnCours = false;
            _gpsErreur  = 'Impossible d\'obtenir votre position GPS.';
          });
          ref.read(presenceStatusProvider.notifier).state =
              PresenceStatus.error;
          ref.read(presenceErrorProvider.notifier).state = _gpsErreur;
          return;
        }
        latitude  = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        setState(() {
          _gpsEnCours = false;
          _gpsErreur  = 'Erreur GPS : ${e.toString()}';
        });
        ref.read(presenceStatusProvider.notifier).state = PresenceStatus.error;
        ref.read(presenceErrorProvider.notifier).state  = _gpsErreur;
        return;
      }
      setState(() => _gpsEnCours = false);
    }

    try {
      final user = ref.read(currentUserProvider)!;
      final body = <String, dynamic>{'code': code};
      if (latitude != null)  body['latitude']  = latitude;
      if (longitude != null) body['longitude'] = longitude;

      await ApiClient.postPresence(
        '/presence/confirmer',
        data:     body,
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      ref.read(historiqueEtudiantProvider.notifier).ajouterPresence(
        PresenceHistorique(
          sessionId:  '',
          matiere:    widget.session.matiere,
          professeur: widget.session.professeur,
          salle:      widget.session.salle,
          type:       widget.session.type,
          date:       DateTime.now(),
          present:    true,
        ),
      );
      ref.invalidate(sessionActiveProvider);
      ref.read(presenceStatusProvider.notifier).state = PresenceStatus.success;
    } on ApiException catch (e) {
      ref.read(presenceStatusProvider.notifier).state = PresenceStatus.error;
      ref.read(presenceErrorProvider.notifier).state  = e.message;
    } catch (_) {
      ref.read(presenceStatusProvider.notifier).state = PresenceStatus.error;
      ref.read(presenceErrorProvider.notifier).state  = 'Erreur de connexion';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(presenceStatusProvider);
    final error  = ref.watch(presenceErrorProvider);
    final filled = code.length == 6;

    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, _) {
        final ttl     = widget.session.ttlRestant;
        final minutes = (ttl ~/ 60).toString().padLeft(2, '0');
        final seconds = (ttl % 60).toString().padLeft(2, '0');
        final expired = widget.session.isExpired;

        return Scaffold(
          appBar: AppBar(title: const Text('Confirmer ma présence')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Infos session
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.cast_for_education_outlined,
                                color: AppColors.orange,
                                size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.session.matiere,
                                    style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                Text(widget.session.professeur,
                                    style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _InfoChip(
                              icon: Icons.door_front_door_outlined,
                              label: widget.session.salle),
                          const SizedBox(width: 8),
                          _InfoChip(
                              icon: Icons.category_outlined,
                              label: widget.session.type),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: expired
                                  ? AppColors.red.withValues(alpha: 0.15)
                                  : AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 13,
                                    color: expired
                                        ? AppColors.red
                                        : AppColors.green),
                                const SizedBox(width: 4),
                                Text(
                                  expired ? 'Expiré' : '$minutes:$seconds',
                                  style: TextStyle(
                                    color: expired
                                        ? AppColors.red
                                        : AppColors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (widget.session.geoActif) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        _gpsEnCours
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.cyan))
                            : const Icon(Icons.my_location,
                            color: AppColors.cyan, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _gpsEnCours
                                ? 'Localisation en cours…'
                                : 'Localisation requise · rayon ${widget.session.rayonMetres ?? '?'}m',
                            style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                Text('Saisis le code affiché par le délégué',
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center),

                const SizedBox(height: 24),

                // Champs OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46, height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _controllers[i].text.isNotEmpty
                              ? AppColors.orange
                              : context.borderColor,
                          width:
                          _controllers[i].text.isNotEmpty ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focuses[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onChanged: (v) => _onDigit(i, v),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(error,
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: filled &&
                        status != PresenceStatus.loading &&
                        !expired &&
                        !_gpsEnCours
                        ? _confirm
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      AppColors.orange.withValues(alpha: 0.3),
                    ),
                    child: status == PresenceStatus.loading || _gpsEnCours
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Confirmer ma présence'),
                  ),
                ),

                if (filled || error != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _clear,
                    child: Text('Effacer',
                        style: TextStyle(color: context.textMuted)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Historique étudiant ───────────────────────────────────────────

class _EtudiantHistorique extends ConsumerStatefulWidget {
  const _EtudiantHistorique();

  @override
  ConsumerState<_EtudiantHistorique> createState() =>
      _EtudiantHistoriqueState();
}

class _EtudiantHistoriqueState extends ConsumerState<_EtudiantHistorique> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(historiqueEtudiantProvider.notifier).charger(
          user.id, user.role,
          classeId: user.classeId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historique = ref.watch(historiqueEtudiantProvider);
    return historique.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Présence')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Présence')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: context.textMuted),
              const SizedBox(height: 12),
              Text('Impossible de charger l\'historique',
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final user = ref.read(currentUserProvider);
                  if (user != null) {
                    ref.read(historiqueEtudiantProvider.notifier).charger(
                      user.id, user.role,
                      classeId: user.classeId,
                    );
                  }
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (liste) => _EtudiantHistoriqueView(historique: liste),
    );
  }
}

class _EtudiantHistoriqueView extends ConsumerWidget {
  final List<PresenceHistorique> historique;
  const _EtudiantHistoriqueView({required this.historique});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presents = historique.where((h) => h.present).length;
    final absents  = historique.where((h) => !h.present).length;
    final taux     = historique.isEmpty
        ? 0
        : (presents / historique.length * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Présence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                ref.read(historiqueEtudiantProvider.notifier).charger(
                  user.id, user.role,
                  classeId: user.classeId,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Aucune session en cours
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.hourglass_empty_outlined,
                      color: context.textMuted, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Aucune session en cours',
                    style:
                    TextStyle(color: context.textMuted, fontSize: 13)),
              ],
            ),
          ),

          // Stats
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatMini(
                        label: 'Présences',
                        value: '$presents',
                        color: AppColors.green),
                    _vDivider(context),
                    _StatMini(
                        label: 'Absences',
                        value: '$absents',
                        color: AppColors.red),
                    _vDivider(context),
                    _StatMini(
                        label: 'Taux',
                        value: '$taux%',
                        color: taux >= 75
                            ? AppColors.green
                            : taux >= 50
                            ? AppColors.orange
                            : AppColors.red),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: historique.isEmpty
                        ? 0
                        : presents / historique.length,
                    backgroundColor:
                    AppColors.red.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      taux >= 75
                          ? AppColors.green
                          : taux >= 50
                          ? AppColors.orange
                          : AppColors.red,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Historique',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${historique.length} séances',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: historique.isEmpty
                ? Center(
                child: Text('Aucune séance enregistrée',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 13)))
                : ListView.separated(
              padding:
              const EdgeInsets.symmetric(horizontal: 16),
              itemCount: historique.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _HistoriqueTile(h: historique[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider(BuildContext context) =>
      Container(width: 1, height: 32, color: context.borderColor);
}

class _HistoriqueTile extends StatelessWidget {
  final PresenceHistorique h;
  const _HistoriqueTile({required this.h});

  @override
  Widget build(BuildContext context) {
    final color = h.present ? AppColors.green : AppColors.red;
    final icon  = h.present
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;

    final d    = h.date;
    final now  = DateTime.now();
    final diff = now.difference(d).inDays;
    final String dateLabel;
    if (diff == 0)
      dateLabel = 'Aujourd\'hui';
    else if (diff == 1)
      dateLabel = 'Hier';
    else
      dateLabel =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final heureLabel =
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: h.present
              ? context.borderColor
              : AppColors.red.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.matiere,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 11, color: context.textMuted),
                    const SizedBox(width: 3),
                    Text(h.professeur,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 11)),
                    const SizedBox(width: 8),
                    Icon(Icons.door_front_door_outlined,
                        size: 11, color: context.textMuted),
                    const SizedBox(width: 3),
                    Text(h.salle,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(h.type,
                    style: const TextStyle(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text('$dateLabel · $heureLabel',
                  style:
                  TextStyle(color: context.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Vue succès ────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final SessionData? session;
  final VoidCallback onReset;
  const _SuccessView({required this.session, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h   = now.hour.toString().padLeft(2, '0');
    final m   = now.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Présence')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.green, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Présence confirmée !',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (session != null) ...[
                Text(session!.matiere,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${session!.professeur} · ${session!.salle}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 13)),
                const SizedBox(height: 4),
              ],
              Text('Enregistrée à $h:$m',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 13)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.borderColor),
                  ),
                  child: const Text('Retour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// VUE DÉLÉGUÉ
// ══════════════════════════════════════════════════════════════════

class _PresenceDelegue extends ConsumerStatefulWidget {
  const _PresenceDelegue();

  @override
  ConsumerState<_PresenceDelegue> createState() => _PresenceDelegueState();
}

class _PresenceDelegueState extends ConsumerState<_PresenceDelegue> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkSessionActive());
  }

  Future<void> _checkSessionActive() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final resp = await ApiClient.getPresence(
        '/presence/sessions/active',
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );
      final session = resp['session'];
      if (session == null) {
        ref.read(sessionStatusProvider.notifier).state = SessionStatus.idle;
        ref.read(sessionDataProvider.notifier).state   = null;
      } else {
        ref.read(dernierSessionIdProvider.notifier).state =
        session['id'] as String?;
        ref.read(sessionDataProvider.notifier).state = SessionData(
          code:         session['code'],
          matiere:      session['matiere']    ?? '',
          professeur:   session['professeur'] ?? '',
          salle:        session['salle']       ?? '',
          type:         session['type']        ?? 'Cours',
          ouverteLe: DateTime.now().subtract(
            Duration(
              seconds: (session['dureeMinutes'] as int? ?? 5) * 60 -
                  (session['ttlRestant'] as int? ?? 0),
            ),
          ),
          dureeMinutes: session['dureeMinutes'] ?? 5,
          geoActif:    session['geoActif']    as bool? ?? false,
          rayonMetres: session['rayonMetres'] as int?,
        );
        ref.read(sessionStatusProvider.notifier).state =
            SessionStatus.active;
      }
    } catch (_) {
      ref.read(sessionStatusProvider.notifier).state = SessionStatus.idle;
      ref.read(sessionDataProvider.notifier).state   = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(sessionStatusProvider);
    switch (status) {
      case SessionStatus.idle:   return const _FormSession();
      case SessionStatus.active: return const _SessionActive();
      case SessionStatus.closed: return const _SessionClosed();
    }
  }
}

// ── Formulaire lancement ──────────────────────────────────────────

class _FormSession extends ConsumerStatefulWidget {
  const _FormSession();

  @override
  ConsumerState<_FormSession> createState() => _FormSessionState();
}

class _FormSessionState extends ConsumerState<_FormSession> {
  final _matiere    = TextEditingController();
  final _professeur = TextEditingController();
  final _salle      = TextEditingController();
  String  _type    = 'Cours';
  int     _duree   = 5;
  bool    _loading = false;
  String? _error;

  bool    _geoActif    = false;
  int     _rayonMetres = 100;
  bool    _gpsEnCours  = false;
  double? _gpsLat;
  double? _gpsLng;
  String? _gpsErreur;

  static const _durees = [5, 10, 15, 20, 30];
  static const _rayons = [
    _RayonOption(metres: 50,   label: '50 m',  desc: 'Salle de classe'),
    _RayonOption(metres: 100,  label: '100 m', desc: 'Bâtiment'),
    _RayonOption(metres: 200,  label: '200 m', desc: 'Campus proche'),
    _RayonOption(metres: 500,  label: '500 m', desc: 'Grand campus'),
    _RayonOption(metres: 1000, label: '1 km',  desc: 'Site étendu'),
  ];

  @override
  void dispose() {
    _matiere.dispose();
    _professeur.dispose();
    _salle.dispose();
    super.dispose();
  }

  Future<void> _toggleGeo(bool valeur) async {
    if (valeur) {
      setState(() {
        _geoActif   = true;
        _gpsEnCours = true;
        _gpsErreur  = null;
      });
      try {
        final pos = await _obtenirPosition();
        if (pos == null) {
          setState(() {
            _geoActif   = false;
            _gpsEnCours = false;
            _gpsErreur  = 'Impossible d\'obtenir la position GPS.';
          });
          return;
        }
        setState(() {
          _gpsLat     = pos.latitude;
          _gpsLng     = pos.longitude;
          _gpsEnCours = false;
        });
      } catch (e) {
        setState(() {
          _geoActif   = false;
          _gpsEnCours = false;
          _gpsErreur  = 'Erreur GPS : ${e.toString()}';
        });
      }
    } else {
      setState(() {
        _geoActif  = false;
        _gpsLat    = null;
        _gpsLng    = null;
        _gpsErreur = null;
      });
    }
  }

  Future<void> _lancer() async {
    if (_matiere.text.trim().isEmpty ||
        _professeur.text.trim().isEmpty ||
        _salle.text.trim().isEmpty) {
      setState(() => _error = 'Remplis tous les champs obligatoires');
      return;
    }
    if (_geoActif && (_gpsLat == null || _gpsLng == null)) {
      setState(() => _error = 'Position GPS non disponible.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final user = ref.read(currentUserProvider)!;
      final body = <String, dynamic>{
        'matiere':      _matiere.text.trim(),
        'professeur':   _professeur.text.trim(),
        'salle':        _salle.text.trim(),
        'type':         _type,
        'dureeMinutes': _duree,
      };
      if (_geoActif && _gpsLat != null && _gpsLng != null) {
        body['gpsLat']      = _gpsLat;
        body['gpsLng']      = _gpsLng;
        body['rayonMetres'] = _rayonMetres;
      }

      final resp = await ApiClient.postPresence(
        '/presence/sessions',
        data:     body,
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      final session = resp['session'] as Map<String, dynamic>;
      ref.read(dernierSessionIdProvider.notifier).state =
      session['id'] as String?;
      ref.read(sessionDataProvider.notifier).state = SessionData(
        code:         session['code'],
        matiere:      session['matiere'],
        professeur:   session['professeur'],
        salle:        session['salle'],
        type:         session['type'],
        ouverteLe:    DateTime.now(),
        dureeMinutes: session['dureeMinutes'],
        geoActif:     session['geoActif']    as bool? ?? false,
        rayonMetres:  session['rayonMetres'] as int?,
      );
      ref.invalidate(sessionActiveProvider);
      ref.read(sessionStatusProvider.notifier).state = SessionStatus.active;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Erreur de connexion'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.startSession)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.orange, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Un code à 6 chiffres sera généré et visible par les étudiants de ta classe.',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _Label(s.subject, context),
            const SizedBox(height: 8),
            TextField(
              controller: _matiere,
              decoration: InputDecoration(
                hintText: s.subjectHint,
                prefixIcon: Icon(Icons.book_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 20),
            _Label(s.teacher, context),
            const SizedBox(height: 8),
            TextField(
              controller: _professeur,
              decoration: InputDecoration(
                hintText: s.teacherHint,
                prefixIcon: Icon(Icons.person_outline,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 20),
            _Label(s.room, context),
            const SizedBox(height: 8),
            TextField(
              controller: _salle,
              decoration: InputDecoration(
                hintText: s.roomHint,
                prefixIcon: Icon(Icons.door_front_door_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 20),
            _Label(s.sessionType, context),
            const SizedBox(height: 8),
            _Dropdown(
              value: _type,
              items: s.sessionTypes,
              onChanged: (v) => setState(() => _type = v ?? 'Cours'),
              context: context,
            ),

            const SizedBox(height: 20),
            _Label(s.validity, context),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _durees.map((d) {
                final selected = _duree == d;
                return GestureDetector(
                  onTap: () => setState(() => _duree = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.orange
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.orange
                            : context.borderColor,
                      ),
                    ),
                    child: Text('${d}min',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: context.textMuted, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    '${s.studentTime} $_duree ${s.minutesToEnter}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section géolocalisation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _geoActif
                    ? AppColors.cyan.withValues(alpha: 0.07)
                    : context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _geoActif
                      ? AppColors.cyan.withValues(alpha: 0.3)
                      : context.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: (_geoActif
                              ? AppColors.cyan
                              : context.textMuted)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined,
                            color: _geoActif
                                ? AppColors.cyan
                                : context.textMuted,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Limiter par géolocalisation',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                            Text(
                              'Seuls les étudiants dans le rayon confirmeront',
                              style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      _gpsEnCours
                          ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cyan))
                          : Switch(
                        value: _geoActif,
                        onChanged: _toggleGeo,
                        activeColor: AppColors.cyan,
                      ),
                    ],
                  ),

                  if (_gpsErreur != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_off,
                              color: AppColors.red, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_gpsErreur!,
                                style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_geoActif && _gpsLat != null && !_gpsEnCours) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: AppColors.green, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'Position capturée · '
                                '${_gpsLat!.toStringAsFixed(5)}, '
                                '${_gpsLng!.toStringAsFixed(5)}',
                            style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_geoActif && _gpsLat != null) ...[
                    const SizedBox(height: 16),
                    Text('Rayon de validité',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _rayons.map((r) {
                        final selected = _rayonMetres == r.metres;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _rayonMetres = r.metres),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.cyan
                                  : context.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.cyan
                                    : context.borderColor,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(r.label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : context.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    )),
                                Text(r.desc,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          .withValues(alpha: 0.8)
                                          : context.textMuted,
                                      fontSize: 10,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading || _gpsEnCours ? null : _lancer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: _loading
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(_loading ? s.launching : s.launch),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RayonOption {
  final int metres;
  final String label;
  final String desc;
  const _RayonOption(
      {required this.metres, required this.label, required this.desc});
}

// ── Session active côté délégué ───────────────────────────────────

class _SessionActive extends ConsumerStatefulWidget {
  const _SessionActive();

  @override
  ConsumerState<_SessionActive> createState() => _SessionActiveState();
}

class _SessionActiveState extends ConsumerState<_SessionActive> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i);
    _startPolling();
  }

  void _startPolling() {
    Stream.periodic(const Duration(seconds: 10)).listen((_) async {
      if (!mounted) return;
      try {
        final user    = ref.read(currentUserProvider)!;
        final session = ref.read(sessionDataProvider);
        if (session == null) return;

        final resp = await ApiClient.getPresence(
          '/presence/sessions/active',
          userId:   user.id,
          role:     user.role,
          classeId: user.classeId,
        );

        final data = resp['session'];
        if (data == null) return;

        ref.read(dernierSessionIdProvider.notifier).state =
        data['id'] as String?;

        final compteur = data['nbPresents'] as int? ?? 0;
        ref.read(sessionDataProvider.notifier).state = session.copyWith(
          presents: List.generate(compteur, (i) => i.toString()),
        );
      } catch (_) {}
    });
  }

  Future<void> _fermer() async {
    final session   = ref.read(sessionDataProvider)!;
    final user      = ref.read(currentUserProvider)!;
    final sessionId = ref.read(dernierSessionIdProvider);

    try {
      if (sessionId != null) {
        final resp = await ApiClient.deletePresence(
          '/presence/sessions/$sessionId',
          userId:   user.id,
          role:     user.role,
          classeId: user.classeId,
        );

        final rapport = resp['rapport'] as Map<String, dynamic>? ?? {};
        final rawPres = (rapport['presents'] as List<dynamic>? ?? []);
        final rawAbs  = (rapport['absents']  as List<dynamic>? ?? []);

        final archive = SessionArchive(
          id:         sessionId,
          matiere:    rapport['matiere']    as String? ?? session.matiere,
          professeur: rapport['professeur'] as String? ?? session.professeur,
          salle:      rapport['salle']      as String? ?? session.salle,
          type:       rapport['type']       as String? ?? session.type,
          debutLe: rapport['ouverteLe'] != null
              ? DateTime.parse(rapport['ouverteLe'] as String)
              : session.ouverteLe,
          finLe: rapport['fermeeLe'] != null
              ? DateTime.parse(rapport['fermeeLe'] as String)
              : DateTime.now(),
          presents: rawPres.map((p) {
            final m = p as Map<String, dynamic>;
            return EtudiantPresent(
              matricule:   m['matricule'] as String? ?? '',
              nom:         m['nom']       as String? ?? '',
              prenom:      m['prenom']    as String? ?? '',
              confirmedAt: m['confirmeA'] != null
                  ? DateTime.parse(m['confirmeA'] as String)
                  : null,
            );
          }).toList(),
          absents: rawAbs.map((p) {
            final m = p as Map<String, dynamic>;
            return EtudiantAbsent(
              matricule: m['matricule'] as String? ?? '',
              nom:       m['nom']       as String? ?? '',
              prenom:    m['prenom']    as String? ?? '',
            );
          }).toList(),
        );

        ref.read(archivesProvider.notifier).invalider();
        ref.read(archivesProvider.notifier).ajouter(archive);
        ref.invalidate(sessionActiveProvider);
        ref.read(sessionStatusProvider.notifier).state = SessionStatus.closed;
        return;
      }
    } catch (_) {}

    // Fallback
    ref.read(archivesProvider.notifier).invalider();
    ref.read(archivesProvider.notifier).ajouter(SessionArchive(
      id:         'arch-${DateTime.now().millisecondsSinceEpoch}',
      matiere:    session.matiere,
      professeur: session.professeur,
      salle:      session.salle,
      type:       session.type,
      debutLe:    session.ouverteLe,
      finLe:      DateTime.now(),
      presents:   [],
      absents:    [],
    ));
    ref.read(sessionStatusProvider.notifier).state = SessionStatus.closed;
  }

  void _showValidationManuelle(BuildContext context) {
    final user      = ref.read(currentUserProvider)!;
    final sessionId = ref.read(dernierSessionIdProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ValidationManuelleModal(
        sessionId: sessionId,
        userId:    user.id,
        role:      user.role,
        classeId:  user.classeId,
        onValider: (nom) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ $nom marqué(e) présent(e)'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionDataProvider)!;
    final s       = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(s.sessionActive), automaticallyImplyLeading: false),
      body: StreamBuilder<int>(
        stream: _ticker,
        builder: (context, _) {
          final ttl     = session.ttlRestant;
          final minutes = (ttl ~/ 60).toString().padLeft(2, '0');
          final seconds = (ttl % 60).toString().padLeft(2, '0');
          final expired = session.isExpired;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Code OTP
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: expired
                          ? AppColors.red.withValues(alpha: 0.4)
                          : AppColors.orange.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        expired ? s.expired : s.presenceCode,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        session.code,
                        style: TextStyle(
                          color: expired
                              ? AppColors.red
                              : AppColors.orange,
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (expired
                              ? AppColors.red
                              : AppColors.orange)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 16,
                                color: expired
                                    ? AppColors.red
                                    : AppColors.orange),
                            const SizedBox(width: 6),
                            Text(
                              expired
                                  ? s.codeExpired
                                  : '$minutes:$seconds ${s.remaining}',
                              style: TextStyle(
                                color: expired
                                    ? AppColors.red
                                    : AppColors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (session.geoActif) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                            AppColors.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.cyan, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'Rayon ${session.rayonMetres ?? '?'} m actif',
                                style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Infos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(s.subject, session.matiere,
                          Icons.book_outlined, context),
                      Divider(color: context.borderColor, height: 20),
                      _InfoRow(s.teacher, session.professeur,
                          Icons.person_outline, context),
                      Divider(color: context.borderColor, height: 20),
                      _InfoRow(s.room, session.salle,
                          Icons.door_front_door_outlined, context),
                      Divider(color: context.borderColor, height: 20),
                      _InfoRow(s.sessionType, session.type,
                          Icons.category_outlined, context),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Compteur présents
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.how_to_reg_outlined,
                          color: AppColors.green, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.confirmedCount,
                              style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12)),
                          Text(
                            '${session.presents.length} étudiant(s)',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                          AppColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh,
                                color: AppColors.green, size: 12),
                            SizedBox(width: 4),
                            Text('Live',
                                style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Validation manuelle
                GestureDetector(
                  onTap: () => _showValidationManuelle(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                          AppColors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_outlined,
                            color: AppColors.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Validation manuelle',
                                  style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text('Pour les étudiants sans téléphone',
                                  style: TextStyle(
                                      color: context.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: context.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _fermer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: 20),
                    label: Text(s.closeSession),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Session fermée ────────────────────────────────────────────────

class _SessionClosed extends ConsumerStatefulWidget {
  const _SessionClosed();

  @override
  ConsumerState<_SessionClosed> createState() => _SessionClosedState();
}

class _SessionClosedState extends ConsumerState<_SessionClosed> {
  bool    _envoyant    = false;
  bool    _envoye      = false;
  String? _erreurEnvoi;

  Future<void> _envoyerRapport() async {
    final sessionId = ref.read(dernierSessionIdProvider);
    final user      = ref.read(currentUserProvider);
    final archives  = ref.read(archivesProvider);

    if (sessionId == null) {
      setState(() =>
      _erreurEnvoi = 'Identifiant de session introuvable.');
      return;
    }
    if (user == null) return;

    SessionArchive? archive;
    try {
      archive = archives.firstWhere((a) => a.id == sessionId);
    } catch (_) {
      archive = archives.isNotEmpty ? archives.first : null;
    }

    if (archive == null) {
      setState(() => _erreurEnvoi = 'Archive de session introuvable.');
      return;
    }

    setState(() { _envoyant = true; _erreurEnvoi = null; });

    try {
      // 1. Générer le PDF depuis la même fonction que "Voir le rapport"
      final pdfBytes  = await pdf_service.genererPdfPresence(archive);
      final pdfBase64 = base64Encode(pdfBytes);

      // 2. Nom du fichier
      final dateStr      = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final matiereClean = archive.matiere.replaceAll(' ', '_');
      final salleClean   = archive.salle.replaceAll(' ', '_');
      final nomFichier   =
          'Rapport_${matiereClean}_${salleClean}_$dateStr.pdf';

      // 3. Envoyer au backend
      await ApiClient.postPresence(
        '/presence/sessions/$sessionId/envoyer-rapport',
        data: {
          'pdfBase64':  pdfBase64,
          'nomFichier': nomFichier,
          'targetRole': 'chef_departement',
        },
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      setState(() { _envoyant = false; _envoye = true; });
    } on ApiException catch (e) {
      setState(() { _envoyant = false; _erreurEnvoi = e.message; });
    } catch (e) {
      setState(() {
        _envoyant    = false;
        _erreurEnvoi = 'Erreur lors de la génération ou de l\'envoi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session  = ref.watch(sessionDataProvider);
    final archives = ref.watch(archivesProvider);
    final derniere = archives.isNotEmpty ? archives.first : null;
    final s        = ref.watch(stringsProvider);

    final dateStrVisuel    = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final salleAffichee    = derniere?.salle    ?? session?.salle    ?? 'Salle';
    final matiereAffichee  = derniere?.matiere  ?? session?.matiere  ?? 'Matiere';

    return Scaffold(
      appBar: AppBar(
          title: Text(s.sessionClosed),
          automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.cyan, size: 44),
              ),
              const SizedBox(height: 24),

              Text(s.sessionClosed,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                '${derniere?.nbPresents ?? session?.presents.length ?? 0} présent(s)\n'
                    '${session?.matiere ?? ''}',
                style: TextStyle(
                    color: context.textMuted,
                    fontSize: 14,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Voir l'archive
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HistoriqueScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: AppColors.dark,
                  ),
                  child: Text(s.viewReport),
                ),
              ),

              const SizedBox(height: 12),

              // Envoyer au chef
              if (!_envoye) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _envoyant ? null : _envoyerRapport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      AppColors.green.withValues(alpha: 0.4),
                    ),
                    icon: _envoyant
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(_envoyant
                        ? 'Envoi en cours...'
                        : 'Envoyer le rapport à mon chef'),
                  ),
                ),

                if (_erreurEnvoi != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_erreurEnvoi!,
                              style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Confirmation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                        AppColors.green.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rapport transmis avec succès',
                              style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rapport_${matiereAffichee}_${salleAffichee}_$dateStrVisuel.pdf',
                              style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Nouvel appel
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(sessionStatusProvider.notifier).state =
                        SessionStatus.idle;
                    ref.read(sessionDataProvider.notifier).state   = null;
                    ref.read(dernierSessionIdProvider.notifier).state =
                    null;
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.borderColor),
                  ),
                  child: Text(s.newRollCall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL VALIDATION MANUELLE
// ══════════════════════════════════════════════════════════════════

class _ValidationManuelleModal extends StatefulWidget {
  final String? sessionId;
  final String userId;
  final String role;
  final String? classeId;
  final void Function(String nom) onValider;

  const _ValidationManuelleModal({
    required this.sessionId,
    required this.userId,
    required this.role,
    this.classeId,
    required this.onValider,
  });

  @override
  State<_ValidationManuelleModal> createState() =>
      _ValidationManuelleModalState();
}

class _ValidationManuelleModalState
    extends State<_ValidationManuelleModal> {
  final _matricule = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _matricule.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_matricule.text.trim().isEmpty) {
      setState(() => _error = 'Saisis le matricule');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      if (widget.sessionId != null) {
        final resp = await ApiClient.postPresence(
          '/presence/sessions/${widget.sessionId}/valider-manuel',
          data:     {'matricule': _matricule.text.trim()},
          userId:   widget.userId,
          role:     widget.role,
          classeId: widget.classeId,
        );
        final etudiant = resp['etudiant'] as Map<String, dynamic>?;
        final nom = etudiant != null
            ? '${etudiant['prenom']} ${etudiant['nom']}'
            : _matricule.text.trim();
        widget.onValider(nom);
        _matricule.clear();
        setState(() { _loading = false; _error = null; });
        return;
      }
      widget.onValider(_matricule.text.trim());
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Erreur de connexion'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Text('Validation manuelle',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Pour les étudiants sans smartphone. '
                'La validation sera horodatée et tracée.',
            style: TextStyle(
                color: context.textMuted, fontSize: 12, height: 1.4),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.orange, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vérifiez physiquement la présence '
                        'avant de valider manuellement.',
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text('Matricule de l\'étudiant',
              style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _matricule,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ex: 21G0001',
              prefixIcon: Icon(Icons.badge_outlined,
                  color: context.textMuted, size: 20),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.red, fontSize: 12)),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _valider,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirmer la présence'),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS LOCAUX
// ══════════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: context.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

Widget _InfoRow(
    String label, String value, IconData icon, BuildContext context) {
  return Row(
    children: [
      Icon(icon, color: context.textMuted, size: 16),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(color: context.textMuted, fontSize: 13)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    ],
  );
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatMini(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
              TextStyle(color: context.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _Label(this.text, this.ctx);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: ctx.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;
  final BuildContext context;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: context.cardColor,
          icon:
          Icon(Icons.keyboard_arrow_down, color: context.textMuted),
          items: items
              .map((i) => DropdownMenuItem(
            value: i,
            child: Text(i,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
