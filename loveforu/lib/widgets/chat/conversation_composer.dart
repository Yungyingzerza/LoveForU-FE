import 'package:flutter/material.dart';

import 'package:loveforu/controllers/chat_conversation_controller.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final ChatConversationController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F39).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.messageController,
                focusNode: controller.inputFocusNode,
                enabled: !controller.isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              width: 40,
              child: ElevatedButton(
                onPressed: controller.isSending ? null : () => onSend(),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF5B7CF7),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 0,
                ),
                child: controller.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
