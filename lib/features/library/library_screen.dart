import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class DocumentItem {
  final String id;
  final String nom;
  final String? description;
  final String categorie;
  final String typeFichier;
  final int tailleOctets;
  final int nbTelechargements;
  final String? uploadeParNom;
  final DateTime? createdAt;

  const DocumentItem({
    required this.id,
    required this.nom,
    this.description,
    required this.categorie,
    required this.typeFichier,
    required this.tailleOctets,
    this.nbTelechargements = 0,
    this.uploadeParNom,
    this.createdAt,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> j) {
    final uploadeur = j['uploadePar'] as Map<String, dynamic>?;
    return DocumentItem(
      id: j['id'] ?? '',
      nom: j['nom'] ?? '',
      description: j['description'],
      categorie: j['categorie'] ?? 'autre',
      typeFichier: j['typeFichier'] ?? '',
      tailleOctets: j['tailleOctets'] ?? 0,
      nbTelechargements: j['nbTelechargements'] ?? 0,
      uploadeParNom: uploadeur != null
          ? '${uploadeur['prenom'] ?? ''} ${uploadeur['nom'] ?? ''}'.trim()
          : null,
      createdAt:
          j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
    );
  }

  String get tailleFormatee {
    if (tailleOctets < 1024) return '$tailleOctets o';
    if (tailleOctets < 1048576)
      return '${(tailleOctets / 1024).toStringAsFixed(1)} Ko';
    return '${(tailleOctets / 1048576).toStringAsFixed(1)} Mo';
  }

  IconData get icone {
    if (typeFichier.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (typeFichier.contains('word') || typeFichier.contains('document'))
      return Icons.description_rounded;
    if (typeFichier.contains('powerpoint') ||
        typeFichier.contains('presentation')) return Icons.slideshow_rounded;
    if (typeFichier.contains('image')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get iconeCouleur {
    if (typeFichier.contains('pdf')) return const Color(0xFFE53935);
    if (typeFichier.contains('word')) return const Color(0xFF1565C0);
    if (typeFichier.contains('powerpoint')) return const Color(0xFFEF6C00);
    if (typeFichier.contains('image')) return const Color(0xFF2E7D32);
    return AppColors.cyan;
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL
// ══════════════════════════════════════════════════════════════════

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';
  String _categorieFiltre = 'tous';
  bool _isLoading = false;
  List<DocumentItem> _documents = [];
  final _searchController = TextEditingController();

  static const _categories = {
    'tous': 'Tous',
    'anciennes_epreuves': 'Épreuves',
    'rapports_stages': 'Rapports',
    'livres_scientifiques': 'Livres',
    'cours': 'Cours',
    'projets': 'Projets',
    'autre': 'Autres',
  };

  @override
  void initState() {
    super.initState();
    _chargerDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chargerDocuments() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{
        'page': '1',
        'limit': '50',
      };
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_categorieFiltre != 'tous') params['categorie'] = _categorieFiltre;

      final resp = await ApiClient.getBilling(
        '/library/documents',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
        params: params,
      );

      final docs = (resp['documents'] as List? ?? [])
          .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _uploaderDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'jpg',
        'jpeg',
        'png',
        'txt'
      ],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le fichier dépasse 20 Mo')),
        );
      }
      return;
    }

    // Demander la catégorie
    if (!mounted) return;
    final categorie = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Catégorie du document'),
        children: _categories.entries
            .where((e) => e.key != 'tous')
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e.key),
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );

    if (categorie == null) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      final fileBytes = await File(file.path!).readAsBytes();

      await ApiClient.uploadDocument(
        '/library/documents',
        fileBytes: fileBytes,
        filename: file.name,
        fields: {'categorie': categorie},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploadé avec succès')),
        );
      }
      await _chargerDocuments();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e')),
        );
      }
    }
  }

  void _telecharger(DocumentItem doc) async {
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.getLibrary(
        '/library/documents/${doc.id}/telecharger',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc.nom} téléchargé')),
        );
      }
      _chargerDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(
            onPressed: _uploaderDocument,
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Importer un manuel',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un document...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _chargerDocuments();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _chargerDocuments();
              },
            ),
          ),

          // Filtres par catégorie
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final entry = _categories.entries.elementAt(i);
                final selected = _categorieFiltre == entry.key;
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _categorieFiltre = entry.key);
                    _chargerDocuments();
                  },
                  selectedColor: AppColors.cyan.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.cyan : context.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  checkmarkColor: AppColors.cyan,
                  side: BorderSide(
                    color: selected ? AppColors.cyan : context.borderColor,
                  ),
                );
              },
            ),
          ),

          // Liste des documents
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.library_books_outlined,
                                size: 56, color: context.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun document',
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Appuyez sur + pour importer un manuel',
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _chargerDocuments,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _documents.length,
                          itemBuilder: (ctx, i) => _DocumentCard(
                            doc: _documents[i],
                            onTap: () => _telecharger(_documents[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CARTE DE DOCUMENT
// ══════════════════════════════════════════════════════════════════

class _DocumentCard extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;

  const _DocumentCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icône du type de fichier
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: doc.iconeCouleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(doc.icone, color: doc.iconeCouleur, size: 26),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.nom,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          doc.tailleFormatee,
                          style:
                              TextStyle(color: context.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: context.textMuted)),
                        const SizedBox(width: 8),
                        Text(
                          '${doc.nbTelechargements} téléchargement(s)',
                          style:
                              TextStyle(color: context.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    if (doc.uploadeParNom != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Par ${doc.uploadeParNom}',
                        style:
                            TextStyle(color: context.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.download_rounded, color: context.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
