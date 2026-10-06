import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/session.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// Big centred banners: area names, quest complete, level up, bosses.
class BannerView extends StatefulWidget {
  const BannerView({super.key, required this.session});

  final GameSession session;

  @override
  State<BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  BannerMessage? _current;

  @override
  void initState() {
    super.initState();
    widget.session.banner.addListener(_onBanner);
  }

  @override
  void dispose() {
    widget.session.banner.removeListener(_onBanner);
    _anim.dispose();
    super.dispose();
  }

  void _onBanner() {
    final b = widget.session.banner.value;
    if (b == null) return;
    setState(() => _current = b);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final b = _current;
    if (b == null) return const SizedBox.shrink();
    final color = switch (b.style) {
      'level' || 'quest' || 'legendary' => DR.gold,
      'boss' || 'danger' => DR.red,
      'event' || 'ultimate' => DR.green,
      _ => DR.text,
    };
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) {
          final t = _anim.value;
          final opacity = t < 0.1 ? t / 0.1 : (t > 0.78 ? (1 - t) / 0.22 : 1.0);
          final scale = t < 0.1 ? 0.85 + t * 1.5 : 1.0 + (t - 0.1) * 0.04;
          if (_anim.isCompleted) return const SizedBox.shrink();
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (b.style != 'area')
                    Container(
                      width: 120,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: const BoxDecoration(gradient: DR.goldGradient),
                    ),
                  ShaderMask(
                    shaderCallback: (r) =>
                        (b.style == 'area' || b.style == 'boss' || b.style == 'danger'
                                ? LinearGradient(colors: [color, color])
                                : const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xfffff9d9), Color(0xffffd75d), Color(0xffff8a2a)],
                                  ))
                            .createShader(r),
                    child: Text(
                      b.title,
                      textAlign: TextAlign.center,
                      style: DR.title(b.style == 'area' ? 38 : 46, color: Colors.white),
                    ),
                  ),
                  if (b.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      b.subtitle!,
                      textAlign: TextAlign.center,
                      style: DR.body(16, color: const Color(0xffe8e2d0), weight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Stacked notifications (loot, quest progress, unlocks).
class ToastList extends StatefulWidget {
  const ToastList({super.key, required this.session});

  final GameSession session;

  @override
  State<ToastList> createState() => _ToastListState();
}

class _ToastListState extends State<ToastList> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final now = DateTime.now();
      final list = widget.session.toasts.value;
      final kept = list.where((t) => now.difference(t.created).inMilliseconds < 4200).toList();
      if (kept.length != list.length) widget.session.toasts.value = kept;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<List<Toast>>(
        valueListenable: widget.session.toasts,
        builder: (_, toasts, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in toasts)
              TweenAnimationBuilder<double>(
                key: ObjectKey(t),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(-20 * (1 - v), 0), child: child),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: const Color(0xdd0b0f18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (t.rarity != null ? DR.rarity(t.rarity!) : (t.color != null ? Color(t.color!) : DR.line)).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (t.icon != null) ...[IconImage(t.icon!, size: 24), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(
                          t.text,
                          style: DR.body(
                            13,
                            color: t.rarity != null ? DR.rarity(t.rarity!) : (t.color != null ? Color(t.color!) : DR.text),
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
