import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chatbot_provider.dart';
import 'widgets/chat_bubble.dart';
import '../../core/theme.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // On demande au Notifier de charger l'historique depuis PostgreSQL dès l'ouverture
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // On récupère le ChatState global (messages + isLoading)
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    // Écoute les changements pour faire défiler automatiquement vers le bas
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0) || next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartCampus Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isLoading
                ? _buildWelcome(context)
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              // On ajoute 1 item de plus à la liste si le bot est en train de charger
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (_, index) {
                // Si on arrive au bout et que ça charge, on affiche l'indicateur
                if (index == messages.length) {
                  return const _LoadingBubble();
                }

                final message = messages[index];
                return ChatBubble(
                  text: message.text,
                  isUser: message.isUser,
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: context.borderColor,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Pose une question...',
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async {
                final text = controller.text;
                if (text.trim().isEmpty) return;

                controller.clear();
                await ref.read(chatProvider.notifier).send(text);
              },
              icon: const Icon(
                Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Bonjour 😊',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Je suis l\'assistant intégré à SmartCampus. Comment puis-je t\'aider aujourd\'hui ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _SuggestionChip('Mes absences'),
                _SuggestionChip('Mes notes'),
                _SuggestionChip('Mon emploi du temps'),
                _SuggestionChip('Mes notifications'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Composant pour les puces de suggestion cliquables
class _SuggestionChip extends ConsumerWidget {
  final String text;

  const _SuggestionChip(this.text);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      label: Text(text),
      backgroundColor: context.cardColor,
      labelStyle: TextStyle(color: context.textPrimary),
      onPressed: () async {
        await ref.read(chatProvider.notifier).send(text);
      },
    );
  }
}

// Petite bulle animée pour simuler l'écriture du bot
class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return const SizedBox(
                width: 6,
                height: 6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}