// コメントのデータモデル。Supabaseのcommentsテーブルと対応。

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  factory Comment.fromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    return Comment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      userId: row['user_id'] as String,
      userName: user?['name'] as String? ?? '匿名',
      content: row['content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
