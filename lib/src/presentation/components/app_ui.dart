import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';

class GidarTopBar extends StatelessWidget {
  const GidarTopBar({
    super.key,
    this.title,
    this.centerChip,
    this.leadingIcon = Icons.menu_rounded,
    this.showLeading = true,
    this.onLeadingTap,
    this.trailing,
  });

  final String? title;
  final Widget? centerChip;
  final IconData leadingIcon;
  final bool showLeading;
  final VoidCallback? onLeadingTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = Color.alphaBlend(
      tokens.appBackground.withValues(alpha: isDark ? 0.06 : 0.03),
      tokens.panelSurface,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.mutedBorder.withValues(alpha: isDark ? 0.95 : 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showLeading) ...[
            _RoundIconButton(
              icon: leadingIcon,
              onTap: onLeadingTap ?? () {},
            ),
            const SizedBox(width: 6),
          ],
          if (title != null)
            Expanded(
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: tokens.mutedForeground.withValues(alpha: 0.9),
                  letterSpacing: 0.1,
                ),
              ),
            )
          else
            const Spacer(),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.selectedSurface,
        border: Border.all(color: tokens.strongBorder),
      ),
      child: Icon(Icons.person, color: tokens.accent),
    );
  }
}

class ModelChip extends StatelessWidget {
  const ModelChip({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: tokens.chipSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accent,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.foreground,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: tokens.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class ApiWarningBanner extends StatelessWidget {
  const ApiWarningBanner({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final warningSurface = Color.alphaBlend(
      const Color(0xFFD97706).withValues(alpha: 0.12),
      tokens.panelSurface,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: warningSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFD97706).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'API Key Required. Tap to set up in Settings.',
                  style: TextStyle(color: tokens.foreground, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeroLogo extends StatefulWidget {
  const HeroLogo({
    super.key,
    this.size = 148,
    this.animationDuration = const Duration(milliseconds: 1650),
    this.repeat = false,
    this.tapToRestart = true,
  });

  final double size;
  final Duration animationDuration;
  final bool repeat;
  final bool tapToRestart;

  @override
  State<HeroLogo> createState() => _HeroLogoState();
}

class _HeroLogoState extends State<HeroLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const logoAspectRatio = 112.5 / 100;
    final logoWidth = widget.size;
    final logoHeight = widget.size * logoAspectRatio;

    return Center(
      child: GestureDetector(
        behavior: widget.tapToRestart
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTap: widget.tapToRestart
            ? () {
                if (widget.repeat) {
                  _controller.repeat(min: 0);
                } else {
                  _controller
                    ..stop()
                    ..forward(from: 0);
                }
              }
            : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            return SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var index = 0; index < _heroLogoLayers.length; index++)
                    _AnimatedHeroLogoLayer(
                      svg: _heroLogoLayers[index],
                      width: logoWidth,
                      height: logoHeight,
                      progress: progress,
                      delay: index * 0.082,
                      fadeOutAtEnd: widget.repeat,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedHeroLogoLayer extends StatelessWidget {
  const _AnimatedHeroLogoLayer({
    required this.svg,
    required this.width,
    required this.height,
    required this.progress,
    required this.delay,
    required this.fadeOutAtEnd,
  });

  final String svg;
  final double width;
  final double height;
  final double progress;
  final double delay;
  final bool fadeOutAtEnd;

  @override
  Widget build(BuildContext context) {
    const revealSpan = 0.235;
    const fadeStart = 0.972;
    final reveal = _intervalValue(
      progress,
      start: delay,
      end: (delay + revealSpan).clamp(0.0, fadeStart),
      curve: Curves.easeOutCubic,
    );
    final fade = !fadeOutAtEnd || progress < fadeStart
        ? 1.0
        : 1 -
            _intervalValue(
              progress,
              start: fadeStart,
              end: 1.0,
              curve: Curves.easeInQuart,
            );
    final opacity = (reveal * fade).clamp(0.0, 1.0);
    final translateY = (1 - reveal) * 2.4;
    final scale = 0.968 + (0.032 * reveal);

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: SvgPicture.string(
              svg,
              width: width,
              height: height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

double _intervalValue(
  double progress, {
  required double start,
  required double end,
  required Curve curve,
}) {
  if (progress <= start) {
    return 0;
  }
  if (progress >= end) {
    return 1;
  }
  final t = (progress - start) / (end - start);
  return curve.transform(t.clamp(0.0, 1.0));
}

const List<String> _heroLogoLayers = [
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m1" x1="49.7" x2="19.1" y1="35.05" y2="35.05" gradientUnits="userSpaceOnUse">
      <stop stop-color="#590989" offset="0"/>
      <stop stop-color="#FF2B8F" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m1)" d="m49.9 1.2-37.1 37.1c-3.6 3.6-7.2 8.8-7.9 16.3-0.6 7.8 1.9 15.1 7.3 20.9l8.2 8.1c-1.8-2.3-5.2-5.7-5.2-11.3 0-2.9 1.2-6.1 3.7-8.4l30.8-31.9 0.2-30.8z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m2" x1="25.35" x2="45.82" y1="72.9" y2="26.49" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFB25B" offset="0"/>
      <stop stop-color="#8909A5" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m2)" d="m44.9 6s1.5 6.9 0.7 14.5l-32.4 33.4c-2.5 2.4-5.1 5.8-4.5 13.5 0.2 2.2 1.2 5.5 3.5 8.1l8.2 8.1c-1.8-2.3-5-5.6-5-11.2 0-3.1 1.3-6.4 3.7-8.7l20.7-21.9c3-5.9 5.5-12.9 5.8-21.3 0.8-7.6-0.7-14.5-0.7-14.5z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m3" x1="63" x2="63" y1="112.4" y2="29.1" gradientUnits="userSpaceOnUse">
      <stop stop-color="#0B56E3" offset="0"/>
      <stop stop-color="#4DE5E5" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m3)" d="m88.3 36.8-9.4-7.7 3.2 4.4c1.3 2 2.3 4 2.3 6.5 0 3.4-1.3 6.5-4.1 9.3l-30.6 30.6v32.5l36.9-36.9c4.9-4.9 8.6-11.3 8.6-19.2s-3.1-15.1-6.9-19.5z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m4" x1="53.5" x2="91.6" y1="92.9" y2="39.3" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1E76E8" offset="0"/>
      <stop stop-color="#4DE5E5" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m4)" d="m88.3 36.8c3.8 4.9 4.8 14.3-1.4 22.3l-33 33c-0.3 7.4 0.6 15.4 0.6 15.4l32.1-32.1c4.9-4.9 8.6-11.2 8.6-19.1s-3.1-15.1-6.9-19.5z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m5" x1="59.7" x2="59.7" y1="69.6" y2="1.3" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FF73AB" offset="0"/>
      <stop stop-color="#8909A5" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m5)" d="m49.7 1.3v68.3l23.7-24.2c2.8-2.7 4.1-5.9 4.1-10.2 0-4.2-1.9-8.2-4.1-10.6l-23.7-23.3z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m6" x1="57.25" x2="57.25" y1="50.9" y2="1.3" gradientUnits="userSpaceOnUse">
      <stop stop-color="#BC1E81" offset="0"/>
      <stop stop-color="#C130C0" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m6)" d="m65.2 16.9-15.5-15.6v49.6c6.5-4.7 12.9-11.4 15.5-24.4 0.7-3.4 0.4-6.9 0-9.6z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m7" x1="37.05" x2="37.05" y1="112.4" y2="42.8" gradientUnits="userSpaceOnUse">
      <stop stop-color="#0B88E3" offset="0"/>
      <stop stop-color="#7EFBC1" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m7)" d="m25.8 68.1c-2.4 2.3-3.8 5.5-3.8 9.4s1.4 7.2 3.8 9.9l23.9 25v-69.6l-23.9 25.3z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m8" x1="46.15" x2="46.15" y1="112.4" y2="62.2" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1482DD" offset="0"/>
      <stop stop-color="#3CCBA1" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m8)" d="m35.6 87.1c0-12.2 8.5-20.4 14-24.9l0.1 50.2-14.1-14.2v-11.1z"/>
</svg>
''',
  '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2.25 104 117">
  <defs>
    <linearGradient id="m9" x1="55.55" x2="55.55" y1="112.4" y2="70.6" gradientUnits="userSpaceOnUse">
      <stop stop-color="#002795" offset="0"/>
      <stop stop-color="#1766BC" offset="1"/>
    </linearGradient>
  </defs>
  <path fill="url(#m9)" d="m59.9 70.6c-2.8 6-6.4 15.4-6.4 26.4 0 2.9 0.4 7.9 1 10.5l-4.8 4.9v-31.4l10.2-10.4z"/>
</svg>
''',
];

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.panelSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: tokens.mutedBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tokens.chipSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.mutedBorder),
                  ),
                  child: Icon(icon, color: tokens.accent, size: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.foreground,
                    height: 1.14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.subtleForeground.withValues(alpha: 0.9),
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Use prompt',
                      style: TextStyle(
                        color: tokens.accent.withValues(alpha: 0.92),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: tokens.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BottomPromptBar extends StatelessWidget {
  const BottomPromptBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.isStreaming,
    required this.onStop,
    required this.onImageTap,
    required this.onCameraTap,
    this.onFileTap,
    required this.onAttachTap,
    required this.onCommandsTap,
    required this.onModelTap,
    required this.onProviderTap,
    required this.onToggleOptions,
    required this.showExpandedOptions,
    required this.selectedModelLabel,
    required this.selectedProviderLabel,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.generateImageEnabled,
    required this.generateDocumentEnabled,
    required this.webSearchEnabled,
    required this.deepResearchEnabled,
    required this.activeModes,
    required this.isEditingLastMessage,
    this.onCancelEditing,
    required this.onToggleGenerateImage,
    required this.onToggleGenerateDocument,
    required this.onToggleWebSearch,
    required this.onToggleDeepResearch,
    this.commandOptions = const [],
    this.showCommands = false,
    this.onSelectCommand,
  });

  final TextEditingController controller;
  final Future<void> Function() onSubmit;
  final bool isStreaming;
  final Future<void> Function() onStop;
  final Future<void> Function() onImageTap;
  final Future<void> Function() onCameraTap;
  final Future<void> Function()? onFileTap;
  final VoidCallback onAttachTap;
  final VoidCallback onCommandsTap;
  final VoidCallback onModelTap;
  final VoidCallback onProviderTap;
  final VoidCallback onToggleOptions;
  final bool showExpandedOptions;
  final String selectedModelLabel;
  final String selectedProviderLabel;
  final List<ComposerAttachment> attachments;
  final ValueChanged<String> onRemoveAttachment;
  final bool generateImageEnabled;
  final bool generateDocumentEnabled;
  final bool webSearchEnabled;
  final bool deepResearchEnabled;
  final List<String> activeModes;
  final bool isEditingLastMessage;
  final VoidCallback? onCancelEditing;
  final VoidCallback onToggleGenerateImage;
  final VoidCallback onToggleGenerateDocument;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleDeepResearch;
  final List<String> commandOptions;
  final bool showCommands;
  final ValueChanged<String>? onSelectCommand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = Color.alphaBlend(
      tokens.appBackground.withValues(alpha: isDark ? 0.04 : 0.025),
      tokens.composerSurface,
    );
    final inputSurface = Color.alphaBlend(
      tokens.panelSurface.withValues(alpha: isDark ? 0.18 : 0.08),
      tokens.subtleSurface,
    );
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: shellColor,
          borderRadius: BorderRadius.circular(showExpandedOptions ? 24 : 22),
          border: Border.all(
            color: tokens.mutedBorder.withValues(alpha: isDark ? 0.82 : 0.74),
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditingLastMessage) ...[
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Editing last message',
                        style: TextStyle(
                          color: tokens.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onCancelEditing,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 2),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return _AttachmentChip(
                      attachment: attachment,
                      onRemove: () => onRemoveAttachment(attachment.id),
                    );
                  },
                ),
              ),
            ],
            if (activeModes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: activeModes
                      .map((mode) => _MiniToolbarChip(
                            icon: Icons.auto_awesome_rounded,
                            label: mode,
                            onTap: onToggleOptions,
                          ))
                      .toList(),
                ),
              ),
            ],
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: tokens.modalSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.mutedBorder),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.shadow
                            .withValues(alpha: isDark ? 0.16 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 34,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                tokens.subtleForeground.withValues(alpha: 0.36),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ComposerDrawerTile(
                              icon: Icons.image_outlined,
                              label: 'Image',
                              onTap: onImageTap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ComposerDrawerTile(
                              icon: Icons.photo_camera_outlined,
                              label: 'Camera',
                              onTap: onCameraTap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ComposerToggleRow(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Generate Image',
                        value: generateImageEnabled,
                        onChanged: onToggleGenerateImage,
                      ),
                      _ComposerToggleRow(
                        icon: Icons.description_outlined,
                        label: 'Generate Document',
                        value: generateDocumentEnabled,
                        onChanged: onToggleGenerateDocument,
                      ),
                      _ComposerToggleRow(
                        icon: Icons.search_rounded,
                        label: 'Web Search',
                        value: webSearchEnabled,
                        onChanged: onToggleWebSearch,
                      ),
                      _ComposerToggleRow(
                        icon: Icons.psychology_alt_outlined,
                        label: 'Deep Research',
                        value: deepResearchEnabled,
                        onChanged: onToggleDeepResearch,
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: tokens.mutedBorder,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ComposerSelectorCard(
                              icon: Icons.hub_rounded,
                              title: 'Provider',
                              value: selectedProviderLabel,
                              onTap: onProviderTap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ComposerSelectorCard(
                              icon: Icons.auto_awesome_mosaic_rounded,
                              title: 'Model',
                              value: selectedModelLabel,
                              onTap: onModelTap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              crossFadeState: showExpandedOptions
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
            if (showCommands && commandOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: tokens.modalSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.mutedBorder),
                ),
                child: Column(
                  children: commandOptions.map((command) {
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        command,
                        style: TextStyle(color: tokens.foreground),
                      ),
                      onTap: () => onSelectCommand?.call(command),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _ComposerAction(
                  icon: showExpandedOptions
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.tune_rounded,
                  onTap: onToggleOptions,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    style: TextStyle(color: tokens.foreground, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: true,
                      fillColor: inputSurface,
                      hintText: isEditingLastMessage
                          ? 'Edit last message...'
                          : 'Message Gidar AI...',
                      hintStyle: TextStyle(
                        color: tokens.subtleForeground,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: _ComposerAction(
                    key: ValueKey(isStreaming),
                    icon: isStreaming ? Icons.stop_rounded : Icons.send_rounded,
                    filled: true,
                    color:
                        isStreaming ? const Color(0xFFFF8A65) : tokens.accent,
                    onTap: () {
                      if (isStreaming) {
                        onStop();
                      } else {
                        FocusScope.of(context).unfocus();
                        onSubmit();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final items = const [
      Icons.home_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.settings_rounded,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.composerSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final active = currentIndex == index;
          return InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: active ? tokens.selectedSurface : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                items[index],
                color: active ? tokens.accent : tokens.subtleForeground,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Text(
      text,
      style: TextStyle(
        color: tokens.accent.withValues(alpha: 0.94),
        letterSpacing: 1.8,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class SettingsBlock extends StatelessWidget {
  const SettingsBlock({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.panelSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: child,
    );
  }
}

class DangerBlock extends StatelessWidget {
  const DangerBlock({
    super.key,
    required this.text,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return SettingsBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(color: tokens.mutedForeground, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4D191C),
                foregroundColor: const Color(0xFFFFD7D7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSwatchButton extends StatelessWidget {
  const ThemeSwatchButton({
    super.key,
    required this.palette,
    required this.active,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 20,
          color: tokens.mutedForeground.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    super.key,
    required this.icon,
    this.filled = false,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final bool filled;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? (color ?? tokens.accent) : tokens.chipSurface,
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Icon(
          icon,
          size: 19,
          color: filled ? tokens.onAccent : tokens.mutedForeground,
        ),
      ),
    );
  }
}

class _ComposerDrawerTile extends StatelessWidget {
  const _ComposerDrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        decoration: BoxDecoration(
          color: tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: tokens.foreground,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: tokens.foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerToggleRow extends StatelessWidget {
  const _ComposerToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value ? tokens.accent : tokens.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: tokens.foreground,
                fontSize: 14,
                fontWeight: value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onChanged(),
            activeThumbColor: tokens.onAccent,
            activeTrackColor: tokens.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: tokens.subtleForeground.withValues(alpha: 0.28),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ComposerSelectorCard extends StatelessWidget {
  const _ComposerSelectorCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: tokens.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.subtleForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: tokens.subtleForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniToolbarChip extends StatelessWidget {
  const _MiniToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.chipSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: tokens.mutedForeground, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  final ComposerAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      width: 166,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.attachmentSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Row(
        children: [
          if (attachment.hasPreview)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                attachment.previewBytes!,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tokens.chipSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.image_outlined,
                color: tokens.accent,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.foreground, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.extractionSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.subtleForeground,
                    fontSize: 10.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: tokens.subtleForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModelSelectionBottomSheet extends StatefulWidget {
  const ModelSelectionBottomSheet({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onModelSelected,
  });

  final List<ModelOption> models;
  final ModelOption? selectedModel;
  final ValueChanged<ModelOption> onModelSelected;

  @override
  State<ModelSelectionBottomSheet> createState() =>
      _ModelSelectionBottomSheetState();
}

class _ModelSelectionBottomSheetState extends State<ModelSelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ModelOption> _filterModels(List<ModelOption> models) {
    if (_searchQuery.isEmpty) return models;
    final query = _searchQuery.toLowerCase();
    return models.where((model) {
      return model.name.toLowerCase().contains(query) ||
          model.id.toLowerCase().contains(query) ||
          model.blurb.toLowerCase().contains(query);
    }).toList();
  }

  Map<AiProviderType, List<ModelOption>> _groupModelsByProvider(
      List<ModelOption> models) {
    final grouped = <AiProviderType, List<ModelOption>>{};
    for (final model in models) {
      grouped.putIfAbsent(model.provider, () => []).add(model);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final filteredModels = _filterModels(widget.models);
    final groupedModels = _groupModelsByProvider(filteredModels);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: tokens.modalSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.mutedBorder),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.subtleForeground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select Model',
                        style: TextStyle(
                          color: tokens.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: tokens.subtleForeground,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: TextStyle(color: tokens.foreground, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    hintStyle: TextStyle(
                      color: tokens.subtleForeground,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: tokens.subtleForeground,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: tokens.subtleForeground,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: tokens.searchSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (groupedModels.isNotEmpty) ...[
                  ...groupedModels.entries.map((entry) {
                    final provider = entry.key;
                    final models = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            providerLabel(provider).toUpperCase(),
                            style: TextStyle(
                              color: tokens.subtleForeground,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...models.map((model) => _ModelTile(
                              model: model,
                              isSelected: model
                                  .sameSelectionIdentity(widget.selectedModel),
                              onTap: () {
                                widget.onModelSelected(model);
                                Navigator.pop(context);
                              },
                            )),
                      ],
                    );
                  }),
                ],
                if (filteredModels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No models found',
                        style: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 14,
                        ),
                      ),
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

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final ModelOption model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final accentColor = const Color(0xFF4CF086);
    final bgColor =
        isSelected ? accentColor.withValues(alpha: 0.12) : tokens.chipSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : tokens.mutedBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.cloud_download_rounded,
                size: 14,
                color: accentColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (model.blurb.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      model.blurb,
                      style: TextStyle(
                        color: tokens.subtleForeground,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (model.supportsVision)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: accentColor,
                ),
              ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }
}
