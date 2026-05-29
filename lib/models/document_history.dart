// lib/models/document_history.dart
class DocumentHistory {
  final String id;
  final String originalText;
  final String summary;
  final DateTime createdAt;
  final String title;
  final List<ChatMessage> conversation;

  DocumentHistory({
    required this.id,
    required this.originalText,
    required this.summary,
    required this.createdAt,
    required this.title,
    required this.conversation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalText': originalText,
      'summary': summary,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'title': title,
      'conversation': conversation.map((msg) => msg.toMap()).toList(),
    };
  }

  factory DocumentHistory.fromMap(Map<String, dynamic> map) {
    return DocumentHistory(
      id: map['id'],
      originalText: map['originalText'],
      summary: map['summary'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      title: map['title'],
      conversation: List<ChatMessage>.from(
        map['conversation'].map((x) => ChatMessage.fromMap(x)),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final String sender; // 'user', 'ai', 'document'
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sender': sender,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      sender: map['sender'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}