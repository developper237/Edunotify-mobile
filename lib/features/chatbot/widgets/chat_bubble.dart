import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
      isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF1E293B)
              : context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: isUser
              ? null
              : Border.all(color: context.borderColor),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : context.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}