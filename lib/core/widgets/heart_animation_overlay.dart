import 'package:flutter/material.dart';

/// ダブルタップ時にハートのアニメーション（拡大・フェードアウト）を表示するラッパーウィジェット
class HeartAnimationOverlay extends StatefulWidget {
  const HeartAnimationOverlay({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;

  @override
  State<HeartAnimationOverlay> createState() => _HeartAnimationOverlayState();
}

class _HeartAnimationOverlayState extends State<HeartAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // ポップして少し弾むような拡大アニメーション
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // 後半でフェードアウト
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showHeart = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHeart() {
    widget.onDoubleTap?.call();
    setState(() {
      _showHeart = true;
    });
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: _triggerHeart,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_showHeart)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFFF2D55),
                            size: 88,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
