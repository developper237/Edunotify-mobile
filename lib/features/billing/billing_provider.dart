// lib/features/billing/billing_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'billing_models.dart';

class BillingState {
  final List<BillingPlan> plans;
  final SubscriptionInfo? abonnement;
  final InvoiceInfo? facture;
  final int? nbEtudiants;
  final bool isLoading;
  final bool isSubscribing;
  final String? error;

  const BillingState({
    this.plans = const [],
    this.abonnement,
    this.facture,
    this.nbEtudiants,
    this.isLoading = false,
    this.isSubscribing = false,
    this.error,
  });

  BillingState copyWith({
    List<BillingPlan>? plans,
    SubscriptionInfo? abonnement,
    InvoiceInfo? facture,
    int? nbEtudiants,
    bool? isLoading,
    bool? isSubscribing,
    String? error,
  }) =>
      BillingState(
        plans: plans ?? this.plans,
        abonnement: abonnement ?? this.abonnement,
        facture: facture ?? this.facture,
        nbEtudiants: nbEtudiants ?? this.nbEtudiants,
        isLoading: isLoading ?? this.isLoading,
        isSubscribing: isSubscribing ?? this.isSubscribing,
        error: error,
      );

  bool get peutSouscrirePayant => plans.any((p) => p.code != 'free');
}

final billingProvider = StateNotifierProvider<BillingNotifier, BillingState>(
  (ref) => BillingNotifier(ref),
);

class BillingNotifier extends StateNotifier<BillingState> {
  final Ref _ref;
  BillingNotifier(this._ref) : super(const BillingState());

  ({String userId, String role, String? etabId})? get _user {
    final u = _ref.read(currentUserProvider);
    if (u == null) return null;
    return (userId: u.id, role: u.role, etabId: u.etablissementId);
  }

  Future<void> charger() async {
    final user = _user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final [plansResp, subResp] = await Future.wait([
        ApiClient.getBilling('/billing/plans',
            userId: user.userId, role: user.role, etablissementId: user.etabId),
        ApiClient.getBilling('/billing/subscription',
            userId: user.userId, role: user.role, etablissementId: user.etabId),
      ]);

      final plans = (plansResp['plans'] as List? ?? [])
          .map((e) => BillingPlan.fromJson(e as Map<String, dynamic>))
          .toList();

      final aboRaw = subResp['abonnement'] as Map<String, dynamic>?;
      state = BillingState(
        plans: plans,
        abonnement: aboRaw == null ? null : SubscriptionInfo.fromJson(aboRaw),
        facture: subResp['facture'] == null
            ? null
            : InvoiceInfo.fromJson(subResp['facture'] as Map<String, dynamic>),
        nbEtudiants: subResp['nbEtudiants'] as int?,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
    }
  }

  /// Souscrit (ou change de plan). Renvoie l'URL de paiement si disponible.
  Future<String?> souscrire({
    required String planCode,
    String cycle = 'mensuel',
    String? methodePaiement,
    String? telephone,
    String? email,
  }) async {
    final user = _user;
    if (user == null) return null;

    state = state.copyWith(isSubscribing: true, error: null);
    try {
      final resp = await ApiClient.postBilling(
        '/billing/subscriptions',
        data: {
          'planCode': planCode,
          'cycle': cycle,
          if (methodePaiement != null) 'methodePaiement': methodePaiement,
          if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        userId: user.userId,
        role: user.role,
        etablissementId: user.etabId,
      );

      // Met à jour l'état local à partir de la réponse
      final abo = resp['abonnement'] as Map<String, dynamic>?;
      final facture = resp['facture'] as Map<String, dynamic>?;
      state = state.copyWith(
        abonnement:
            abo == null ? state.abonnement : SubscriptionInfo.fromJson(abo),
        facture:
            facture == null ? state.facture : InvoiceInfo.fromJson(facture),
        isSubscribing: false,
      );
      return resp['paiementUrl'] as String?;
    } on ApiException catch (e) {
      state = state.copyWith(isSubscribing: false, error: e.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(isSubscribing: false, error: 'Erreur réseau');
      rethrow;
    }
  }

  /// Paye la facture en attente. Renvoie l'URL de paiement CinetPay.
  Future<String?> payerFacture({
    required String subscriptionId,
    required String methodePaiement,
    String? telephone,
  }) async {
    final user = _user;
    if (user == null) return null;

    state = state.copyWith(isSubscribing: true, error: null);
    try {
      final resp = await ApiClient.postBilling(
        '/billing/subscriptions/$subscriptionId/payer',
        data: {
          'methodePaiement': methodePaiement,
          if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
        },
        userId: user.userId,
        role: user.role,
        etablissementId: user.etabId,
      );
      final facture = resp['facture'] as Map<String, dynamic>?;
      state = state.copyWith(
        facture:
            facture == null ? state.facture : InvoiceInfo.fromJson(facture),
        isSubscribing: false,
      );
      return resp['paiementUrl'] as String?;
    } on ApiException catch (e) {
      state = state.copyWith(isSubscribing: false, error: e.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(isSubscribing: false, error: 'Erreur réseau');
      rethrow;
    }
  }

  /// Initie un paiement direct (push MoMo/OM, pas de redirect).
  /// Retourne le transactionId pour le polling.
  Future<String?> payerDirect({
    required String subscriptionId,
    required String methodePaiement,
    required String telephone,
    String? email,
  }) async {
    final user = _user;
    if (user == null) return null;

    state = state.copyWith(isSubscribing: true, error: null);
    try {
      final resp = await ApiClient.postBilling(
        '/billing/subscriptions/$subscriptionId/payer-direct',
        data: {
          'methodePaiement': methodePaiement,
          'telephone': telephone,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        userId: user.userId,
        role: user.role,
        etablissementId: user.etabId,
      );
      state = state.copyWith(isSubscribing: false);
      return resp['transactionId'] as String?;
    } on ApiException catch (e) {
      state = state.copyWith(isSubscribing: false, error: e.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(isSubscribing: false, error: 'Erreur réseau');
      rethrow;
    }
  }

  /// Vérifie le statut d'un paiement (polling côté app).
  Future<String> verifierStatutPaiement(String transId) async {
    final user = _user;
    if (user == null) return 'ERROR';

    try {
      final resp = await ApiClient.getBilling(
        '/billing/payment-status/$transId',
        userId: user.userId,
        role: user.role,
        etablissementId: user.etabId,
      );
      return resp['statut'] as String? ?? 'PENDING';
    } catch (_) {
      return 'PENDING';
    }
  }

  Future<void> annuler() async {
    final user = _user;
    if (user == null) return;

    state = state.copyWith(isSubscribing: true, error: null);
    try {
      await ApiClient.postBilling(
        '/billing/subscriptions/cancel',
        userId: user.userId,
        role: user.role,
        etablissementId: user.etabId,
      );
      await charger();
    } on ApiException catch (e) {
      state = state.copyWith(isSubscribing: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isSubscribing: false, error: 'Erreur réseau');
    }
  }
}

/// Ouvre une URL de paiement (CinetPay) dans le navigateur.
Future<bool> ouvrirUrlPaiement(String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
  return ok;
}
