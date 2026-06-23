class ChatMessage {
  final int? id;
  final int sessionId;
  final String role; // 'user' or 'model'
  final String text;
  final String? action; // e.g. 'ADD_EXPENSE'
  final String? actionData; // JSON string of the payload
  final String timestamp;

  ChatMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.text,
    this.action,
    this.actionData,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'text': text,
      'action': action,
      'action_data': actionData,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      role: map['role'] as String,
      text: map['text'] as String,
      action: map['action'] as String?,
      actionData: map['action_data'] as String?,
      timestamp: map['timestamp'] as String,
    );
  }
}
