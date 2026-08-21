// コメント機能の状態管理およびSupabaseとの連携。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../models/comment.dart';

// 指定したpostIdのコメント一覧を取得するProvider
final commentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, String>((
      ref,
      postId,
    ) async {
      final rows = await supabase
          .from('comments')
          .select('*, users(name)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return [for (final r in rows) Comment.fromRow(r)];
    });

// コメントの追加・削除操作を行うController
final commentControllerProvider = Provider((ref) => CommentController(ref));

class CommentController {
  CommentController(this._ref);

  final Ref _ref;

  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('ログインが必要です');
    if (content.trim().isEmpty) return;

    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content.trim(),
    });

    _ref.invalidate(commentsProvider(postId));
  }

  Future<void> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('ログインが必要です');

    await supabase
        .from('comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', user.id);

    _ref.invalidate(commentsProvider(postId));
  }
}
