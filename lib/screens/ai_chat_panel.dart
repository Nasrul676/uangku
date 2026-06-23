import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import 'settings_screen.dart';
import 'saving_goals_screen.dart';
import 'shopping_list_screen.dart';
import 'pocket_list_screen.dart';

class AiChatPanel extends StatefulWidget {
  final String currentContext;

  const AiChatPanel({
    super.key,
    required this.currentContext,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleNavigation(String pageName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context); // Close the chat panel
      
      if (pageName == 'settings') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      } else if (pageName == 'savings') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingGoalsScreen()));
      } else if (pageName == 'shopping_list') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen()));
      } else if (pageName == 'pockets') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PocketListScreen()));
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    _textController.clear();

    final provider = context.read<TransactionProvider>();
    await provider.sendChatMessage(text, widget.currentContext);

    setState(() {
      _isSending = false;
    });
  }

  void _showSessionsDialog() {
    final provider = context.read<TransactionProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Riwayat Sesi'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Consumer<TransactionProvider>(
              builder: (context, prov, child) {
                if (prov.chatSessions.isEmpty) {
                  return const Center(child: Text('Belum ada riwayat obrolan.'));
                }
                return ListView.builder(
                  itemCount: prov.chatSessions.length,
                  itemBuilder: (context, index) {
                    final session = prov.chatSessions[index];
                    return ListTile(
                      title: Text(session.title),
                      subtitle: Text(session.updatedAt.split('T')[0]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          prov.deleteChatSession(session.id!);
                        },
                      ),
                      onTap: () {
                        prov.loadChatMessages(session.id!);
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final messages = provider.currentChatMessages;
    final theme = Theme.of(context);

    // Auto-scroll when new messages arrive
    if (messages.length != _previousMessageCount) {
      final newCount = messages.length - _previousMessageCount;
      _previousMessageCount = messages.length;
      _scrollToBottom();
      
      // Handle navigation action if present in new messages
      if (newCount > 0 && messages.isNotEmpty) {
        final lastMsg = messages.last;
        if (lastMsg.action == 'navigate_to_page' && lastMsg.actionData != null) {
          try {
            final data = jsonDecode(lastMsg.actionData!);
            final pageName = data['page_name'];
            _handleNavigation(pageName);
          } catch (_) {}
        }
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Asisten AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      tooltip: 'Sesi Baru',
                      onPressed: () {
                        provider.startNewChatSession();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'Riwayat',
                      onPressed: _showSessionsDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? theme.colorScheme.primary : theme.cardColor,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (msg.action != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Aksi dijalankan: ${msg.action}',
                                  style: const TextStyle(fontSize: 10, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan atau instruksi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isSending ? Colors.grey : theme.colorScheme.primary,
                  child: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.send_rounded, color: theme.colorScheme.onPrimary),
                          onPressed: _sendMessage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
