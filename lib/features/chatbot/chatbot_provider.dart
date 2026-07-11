import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../features/auth/auth_provider.dart';
import 'models/chat_message.dart';

// ══════════════════════════════════════════════════════════════════
// ÉTAT
// ══════════════════════════════════════════════════════════════════

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const ChatState({required this.messages, required this.isLoading});

  factory ChatState.initial() =>
      const ChatState(messages: [], isLoading: false);

  ChatState copyWith({List<ChatMessage>? messages, bool? isLoading}) =>
      ChatState(
        messages:  messages  ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
      (ref) => ChatNotifier(ref),
);

// ══════════════════════════════════════════════════════════════════
// NOTIFIER
// ══════════════════════════════════════════════════════════════════

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;

  ChatNotifier(this._ref) : super(ChatState.initial());

  /// Charge l'historique persistant depuis PostgreSQL
  Future<void> loadHistory() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    try {
      print('[CHATBOT] loadHistory pour userId=${user.id}');
      final response = await ApiClient.getChatbot(
        '/api/chat/history',
        userId: user.id,
        role:   user.role,
      );
      print('[CHATBOT] loadHistory réponse: $response');

      if (response is List) {
        final loaded = response.map((data) {
          final m = data as Map<String, dynamic>;
          return ChatMessage(
            id:        m['id'].toString(),
            text:      m['text']      as String,
            isUser:    m['isUser']    as bool,
            createdAt: DateTime.parse(m['createdAt'] as String),
          );
        }).toList();
        state = ChatState(messages: loaded, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      print('[CHATBOT] loadHistory erreur: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Envoie un message et reçoit la réponse de l'IA
  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      print('[CHATBOT] send: user est null !');
      return;
    }

    print('[CHATBOT] send: userId=${user.id} message="$text"');

    // 1. Prépare l'historique au format Gemini attendu par Node.js
    final historyList = state.messages.map((msg) => {
      'role':  msg.isUser ? 'user' : 'model',
      'parts': [{'text': msg.text}],
    }).toList();

    // 2. Affiche le message utilisateur localement et passe en isLoading
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id:        'local_${DateTime.now().millisecondsSinceEpoch}',
          text:      text,
          isUser:    true,
          createdAt: DateTime.now(),
        ),
      ],
      isLoading: true,
    );

    try {
      print('[CHATBOT] Appel POST /api/chat...');
      final resp = await ApiClient.postChatbot(
        '/api/chat',
        data:   {'message': text, 'history': historyList},
        userId: user.id,
        role:   user.role,
      );
      print('[CHATBOT] Réponse reçue: $resp');

      final replyText = resp['reply'] as String?
          ?? "Je n'ai pas compris la réponse.";

      // 3. Succès : On ajoute la réponse de l'IA à la suite du tableau d'état
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id:        'local_${DateTime.now().millisecondsSinceEpoch + 1}',
            text:      replyText,
            isUser:    false,
            createdAt: DateTime.now(),
          ),
        ],
        isLoading: false,
      );
    } on ApiException catch (e) {
      print('[CHATBOT] ApiException: ${e.message} | body: ${e.body}');
      _addError(e.message);
    } catch (e, st) {
      print('[CHATBOT] Erreur inattendue: $e');
      print('[CHATBOT] StackTrace: $st');
      _addError(
        "Désolé, je n'arrive pas à joindre le serveur SmartCampus. "
            "Vérifie ta connexion.",
      );
    }
  }

  void _addError(String msg) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id:        'error_${DateTime.now().millisecondsSinceEpoch}',
          text:      msg,
          isUser:    false,
          createdAt: DateTime.now(),
        ),
      ],
      isLoading: false,
    );
  }

  void clearMessages() => state = ChatState.initial();
}