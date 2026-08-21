// 撮影動画を統一した向き(横向き)で表示する共通ウィジェット。
// 縦撮り動画を90度回転し、上下逆に記録された動画(needsFlip)は更に180度補正する。

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class RecordedVideoView extends StatelessWidget {
  const RecordedVideoView({
    super.key,
    required this.controller,
    this.needsFlip = false,
    this.recordedPlatform = 'mobile',
  });

  final VideoPlayerController controller;
  // ファイル自体が上下逆に記録された動画(Android前面カメラ等)を180度回して補正する。
  final bool needsFlip;
  // 撮影したプラットフォーム。回転・反転の補正に使う。
  final String recordedPlatform;

  @override
  Widget build(BuildContext context) {
    final isWeb = recordedPlatform == 'web';
    // スマホは縦撮りを90度(3)回す。Webカメラは逆方向に倒れるため向きを変える(1)。
    // 上下逆の動画はさらに180度(2)加えて補正する。
    final quarterTurns = ((isWeb ? 1 : 3) + (needsFlip ? 2 : 0)) % 4;

    return FittedBox(
      fit: BoxFit.cover,
      // Web撮影動画は撮影プレビュー(鏡)と向きを揃えるため左右反転する。
      child: Transform.scale(
        scaleX: isWeb ? -1 : 1,
        scaleY: 1,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: IgnorePointer(child: VideoPlayer(controller)),
          ),
        ),
      ),
    );
  }
}
