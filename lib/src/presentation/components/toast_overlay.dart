import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppToastTone {
  success,
  error,
  info,
  neutral,
}

class AppToastData {
  const AppToastData({
    required this.message,
    required this.tone,
  });

  final String message;
  final AppToastTone tone;
}

class ToastOverlay extends StatelessWidget {
  const ToastOverlay({
    super.key,
    required this.toast,
  });

  final AppToastData toast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final theme = Theme.of(context);
    final style = _ToastToneStyle.resolve(toast.tone, tokens);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 18),
                child: child,
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 760,
              maxHeight: 240,
            ),
            margin: EdgeInsets.fromLTRB(18, 0, 18, 108 + bottomInset),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: style.border,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.iconSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: style.border.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Icon(
                    style.icon,
                    color: style.iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: style.iconColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            toast.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.foreground,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastToneStyle {
  const _ToastToneStyle({
    required this.title,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconSurface,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconSurface;
  final Color iconColor;

  static _ToastToneStyle resolve(AppToastTone tone, AppThemeTokens tokens) {
    final success = const Color(0xFF2E9E68);
    final error = const Color(0xFFD96A73);
    final info = tokens.accent;
    final neutral = tokens.foreground.withValues(alpha: 0.72);
    final accent = switch (tone) {
      AppToastTone.success => success,
      AppToastTone.error => error,
      AppToastTone.info => info,
      AppToastTone.neutral => neutral,
    };
    final background = Color.alphaBlend(
      accent.withValues(alpha: tone == AppToastTone.error ? 0.18 : 0.14),
      tokens.modalSurface.withValues(alpha: 0.985),
    );
    return _ToastToneStyle(
      title: switch (tone) {
        AppToastTone.success => 'Success',
        AppToastTone.error => 'Model Error',
        AppToastTone.info => 'Info',
        AppToastTone.neutral => 'Notice',
      },
      icon: switch (tone) {
        AppToastTone.success => Icons.check_circle_rounded,
        AppToastTone.error => Icons.error_outline_rounded,
        AppToastTone.info => Icons.info_outline_rounded,
        AppToastTone.neutral => Icons.notifications_none_rounded,
      },
      background: background,
      border: Color.alphaBlend(
        accent.withValues(alpha: 0.42),
        tokens.mutedBorder,
      ),
      iconSurface: Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        tokens.elevatedSurface,
      ),
      iconColor: accent,
    );
  }
}
