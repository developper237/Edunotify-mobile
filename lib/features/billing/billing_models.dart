// lib/features/billing/billing_models.dart
// Modèles alignés sur le billing-service (backend).

class BillingPlan {
  final String code; // free | pro | institution
  final String nom;
  final String? description;
  final int? maxEtudiants;
  final int prixMensuelXAF;
  final int prixAnnuelXAF;
  final Map<String, dynamic>? fonctionnalites;

  const BillingPlan({
    required this.code,
    required this.nom,
    this.description,
    this.maxEtudiants,
    required this.prixMensuelXAF,
    required this.prixAnnuelXAF,
    this.fonctionnalites,
  });

  factory BillingPlan.fromJson(Map<String, dynamic> j) => BillingPlan(
        code: j['code'] as String? ?? 'free',
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String?,
        maxEtudiants: j['maxEtudiants'] as int?,
        prixMensuelXAF: j['prixMensuelXAF'] as int? ?? 0,
        prixAnnuelXAF: j['prixAnnuelXAF'] as int? ?? 0,
        fonctionnalites: j['fonctionnalites'] as Map<String, dynamic>?,
      );

  String prixPour(String cycle) {
    final xaf = cycle == 'annuel' ? prixAnnuelXAF : prixMensuelXAF;
    if (xaf == 0) return 'Gratuit';
    final milliers = (xaf / 1000).toStringAsFixed(xaf % 1000 == 0 ? 0 : 1);
    return '$milliers ${xaf >= 1000 ? 'k' : ''}FCFA'.replaceAll('.0k', 'k');
  }
}

class SubscriptionInfo {
  final String planCode;
  final String statut; // essai | actif | expire | annule | impaye
  final String cycle; // mensuel | annuel
  final DateTime? essaiJusqua;
  final DateTime? finPeriode;
  final DateTime? debutPeriode;
  final int? prixXAF;
  final bool renouvellementAuto;
  final String? id;

  const SubscriptionInfo({
    this.id,
    required this.planCode,
    required this.statut,
    this.cycle = 'mensuel',
    this.essaiJusqua,
    this.finPeriode,
    this.debutPeriode,
    this.prixXAF,
    this.renouvellementAuto = true,
  });

  bool get estGratuit => planCode == 'free';
  bool get enEssai => statut == 'essai';

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        id: j['id'] as String?,
        planCode: j['planCode'] as String? ?? 'free',
        statut: j['statut'] as String? ?? 'actif',
        cycle: j['cycle'] as String? ?? 'mensuel',
        essaiJusqua: j['essaiJusqua'] != null
            ? DateTime.tryParse(j['essaiJusqua'])
            : null,
        finPeriode:
            j['finPeriode'] != null ? DateTime.tryParse(j['finPeriode']) : null,
        debutPeriode: j['debutPeriode'] != null
            ? DateTime.tryParse(j['debutPeriode'])
            : null,
        prixXAF: j['prixXAF'] as int?,
        renouvellementAuto: j['renouvellementAuto'] as bool? ?? true,
      );
}

class InvoiceInfo {
  final String? id;
  final String numero;
  final int montantXAF;
  final String statut; // en_attente | payee | echouee
  final String? methodePaiement;
  final String? urlPaiement;
  final DateTime? createdAt;

  const InvoiceInfo({
    this.id,
    required this.numero,
    required this.montantXAF,
    this.statut = 'en_attente',
    this.methodePaiement,
    this.urlPaiement,
    this.createdAt,
  });

  factory InvoiceInfo.fromJson(Map<String, dynamic> j) => InvoiceInfo(
        id: j['id'] as String?,
        numero: j['numero'] as String? ?? '',
        montantXAF: j['montantXAF'] as int? ?? 0,
        statut: j['statut'] as String? ?? 'en_attente',
        methodePaiement: j['methodePaiement'] as String?,
        urlPaiement: j['urlPaiement'] as String?,
        createdAt:
            j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );
}
