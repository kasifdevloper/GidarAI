import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_descriptors.dart';
import '../models/app_models.dart';

const List<ThemePalette> palettes = [
  ThemePalette(
    mode: AppThemeMode.classicDark,
    name: 'Classic Dark',
    primary: Color(0xFF74A7FF),
    secondary: Color(0xFF93BAFF),
    surface: Color(0xFF17191D),
    backgroundTop: Color(0xFF0F1115),
    backgroundBottom: Color(0xFF0F1115),
  ),
  ThemePalette(
    mode: AppThemeMode.pureLight,
    name: 'Pure Light',
    primary: Color(0xFF376CFF),
    secondary: Color(0xFF6B8EFF),
    surface: Color(0xFFFFFFFF),
    backgroundTop: Color(0xFFF4F6FB),
    backgroundBottom: Color(0xFFF4F6FB),
  ),
  ThemePalette(
    mode: AppThemeMode.midnightBlue,
    name: 'Midnight Blue',
    primary: Color(0xFF7FA7FF),
    secondary: Color(0xFFA7BEFF),
    surface: Color(0xFF141A23),
    backgroundTop: Color(0xFF0D1219),
    backgroundBottom: Color(0xFF0D1219),
  ),
  ThemePalette(
    mode: AppThemeMode.forestGreen,
    name: 'Forest Green',
    primary: Color(0xFF4A9B6E),
    secondary: Color(0xFF79B694),
    surface: Color(0xFF141A17),
    backgroundTop: Color(0xFF0D1310),
    backgroundBottom: Color(0xFF0D1310),
  ),
  ThemePalette(
    mode: AppThemeMode.sunsetPurple,
    name: 'Sunset Purple',
    primary: Color(0xFF8E6BE2),
    secondary: Color(0xFFB29AEF),
    surface: Color(0xFF181520),
    backgroundTop: Color(0xFF110E16),
    backgroundBottom: Color(0xFF110E16),
  ),
  ThemePalette(
    mode: AppThemeMode.roseGold,
    name: 'Rose Gold',
    primary: Color(0xFFD78092),
    secondary: Color(0xFFE3AAB4),
    surface: Color(0xFF21181A),
    backgroundTop: Color(0xFF161012),
    backgroundBottom: Color(0xFF161012),
  ),
  ThemePalette(
    mode: AppThemeMode.oceanTeal,
    name: 'Ocean Teal',
    primary: Color(0xFF319C9A),
    secondary: Color(0xFF76BDB8),
    surface: Color(0xFF11191A),
    backgroundTop: Color(0xFF0B1314),
    backgroundBottom: Color(0xFF0B1314),
  ),
];

ThemePalette paletteFor(AppThemeMode mode) {
  return palettes.firstWhere(
    (item) => item.mode == mode,
    orElse: () => palettes.first,
  );
}

ThemeMode materialThemeModeFor(AppAppearanceMode appearanceMode) {
  return switch (appearanceMode) {
    AppAppearanceMode.dark => ThemeMode.dark,
    AppAppearanceMode.light => ThemeMode.light,
    AppAppearanceMode.system => ThemeMode.system,
  };
}

Brightness resolveBrightness(
  AppAppearanceMode appearanceMode,
  Brightness platformBrightness,
) {
  return switch (appearanceMode) {
    AppAppearanceMode.dark => Brightness.dark,
    AppAppearanceMode.light => Brightness.light,
    AppAppearanceMode.system => platformBrightness,
  };
}

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.appBackground,
    required this.sidebarSurface,
    required this.panelSurface,
    required this.elevatedSurface,
    required this.composerSurface,
    required this.modalSurface,
    required this.topBarSurface,
    required this.chipSurface,
    required this.searchSurface,
    required this.attachmentSurface,
    required this.selectedSurface,
    required this.subtleSurface,
    required this.mutedBorder,
    required this.strongBorder,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.foreground,
    required this.mutedForeground,
    required this.subtleForeground,
    required this.shadow,
  });

  final Color appBackground;
  final Color sidebarSurface;
  final Color panelSurface;
  final Color elevatedSurface;
  final Color composerSurface;
  final Color modalSurface;
  final Color topBarSurface;
  final Color chipSurface;
  final Color searchSurface;
  final Color attachmentSurface;
  final Color selectedSurface;
  final Color subtleSurface;
  final Color mutedBorder;
  final Color strongBorder;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color foreground;
  final Color mutedForeground;
  final Color subtleForeground;
  final Color shadow;

  static AppThemeTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppThemeTokens>() ??
        AppThemeTokens.fallback(theme.colorScheme);
  }

  factory AppThemeTokens.manual(
    AppThemeMode family,
    Brightness brightness,
  ) {
    final variant = _manualVariantFor(family, brightness);
    final scheme = ColorScheme.fromSeed(
      seedColor: variant.primary,
      brightness: brightness,
      primary: variant.primary,
      secondary: variant.secondary,
      surface: variant.surface,
    );
    final isDark = brightness == Brightness.dark;
    return AppThemeTokens(
      appBackground: variant.background,
      sidebarSurface: _blend(
        variant.surface,
        isDark ? Colors.black : Colors.white,
        isDark ? 0.16 : 0.06,
      ),
      panelSurface: variant.surface,
      elevatedSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.05 : 0.035,
      ),
      composerSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.07 : 0.03,
      ),
      modalSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.06 : 0.03,
      ),
      topBarSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.04 : 0.02,
      ),
      chipSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.08 : 0.05,
      ),
      searchSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.1 : 0.06,
      ),
      attachmentSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.06 : 0.04,
      ),
      selectedSurface: _blend(
        variant.surface,
        variant.primary,
        isDark ? 0.18 : 0.12,
      ),
      subtleSurface: _blend(
        variant.surface,
        isDark ? Colors.white : Colors.black,
        isDark ? 0.03 : 0.018,
      ),
      mutedBorder:
          scheme.outlineVariant.withValues(alpha: isDark ? 0.34 : 0.16),
      strongBorder: scheme.outline.withValues(alpha: isDark ? 0.26 : 0.14),
      accent: variant.primary,
      accentSoft: variant.primary.withValues(alpha: isDark ? 0.18 : 0.1),
      onAccent: scheme.onPrimary,
      foreground: scheme.onSurface,
      mutedForeground: scheme.onSurfaceVariant,
      subtleForeground: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      shadow: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
    );
  }

  factory AppThemeTokens.dynamic(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final accent = _tameAccent(
      scheme.primary,
      scheme.onSurface,
      isDark ? 0.16 : 0.24,
    );
    return AppThemeTokens(
      appBackground: scheme.surface,
      sidebarSurface: scheme.surfaceContainer,
      panelSurface: scheme.surfaceContainerLow,
      elevatedSurface: scheme.surfaceContainer,
      composerSurface: scheme.surfaceContainerHigh,
      modalSurface: scheme.surfaceContainerHigh,
      topBarSurface: scheme.surfaceContainer,
      chipSurface: scheme.surfaceContainerHigh,
      searchSurface: scheme.surfaceContainerHighest,
      attachmentSurface: scheme.surfaceContainer,
      selectedSurface: _blend(
        scheme.surfaceContainerHigh,
        accent,
        isDark ? 0.18 : 0.1,
      ),
      subtleSurface: scheme.surfaceContainerHighest,
      mutedBorder:
          scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.18),
      strongBorder: scheme.outline.withValues(alpha: isDark ? 0.24 : 0.14),
      accent: accent,
      accentSoft: accent.withValues(alpha: isDark ? 0.18 : 0.1),
      onAccent: scheme.onPrimary,
      foreground: scheme.onSurface,
      mutedForeground: scheme.onSurfaceVariant,
      subtleForeground: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      shadow: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
    );
  }

  factory AppThemeTokens.fallback(ColorScheme scheme) {
    return AppThemeTokens.dynamic(scheme);
  }

  @override
  AppThemeTokens copyWith({
    Color? appBackground,
    Color? sidebarSurface,
    Color? panelSurface,
    Color? elevatedSurface,
    Color? composerSurface,
    Color? modalSurface,
    Color? topBarSurface,
    Color? chipSurface,
    Color? searchSurface,
    Color? attachmentSurface,
    Color? selectedSurface,
    Color? subtleSurface,
    Color? mutedBorder,
    Color? strongBorder,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? foreground,
    Color? mutedForeground,
    Color? subtleForeground,
    Color? shadow,
  }) {
    return AppThemeTokens(
      appBackground: appBackground ?? this.appBackground,
      sidebarSurface: sidebarSurface ?? this.sidebarSurface,
      panelSurface: panelSurface ?? this.panelSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      composerSurface: composerSurface ?? this.composerSurface,
      modalSurface: modalSurface ?? this.modalSurface,
      topBarSurface: topBarSurface ?? this.topBarSurface,
      chipSurface: chipSurface ?? this.chipSurface,
      searchSurface: searchSurface ?? this.searchSurface,
      attachmentSurface: attachmentSurface ?? this.attachmentSurface,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      mutedBorder: mutedBorder ?? this.mutedBorder,
      strongBorder: strongBorder ?? this.strongBorder,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      subtleForeground: subtleForeground ?? this.subtleForeground,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      sidebarSurface: Color.lerp(sidebarSurface, other.sidebarSurface, t)!,
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      composerSurface: Color.lerp(composerSurface, other.composerSurface, t)!,
      modalSurface: Color.lerp(modalSurface, other.modalSurface, t)!,
      topBarSurface: Color.lerp(topBarSurface, other.topBarSurface, t)!,
      chipSurface: Color.lerp(chipSurface, other.chipSurface, t)!,
      searchSurface: Color.lerp(searchSurface, other.searchSurface, t)!,
      attachmentSurface:
          Color.lerp(attachmentSurface, other.attachmentSurface, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      mutedBorder: Color.lerp(mutedBorder, other.mutedBorder, t)!,
      strongBorder: Color.lerp(strongBorder, other.strongBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      subtleForeground:
          Color.lerp(subtleForeground, other.subtleForeground, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.appFontPreset,
    required this.chatFontPreset,
    required this.chatBody,
    required this.chatStrong,
    required this.chatH1,
    required this.chatH2,
    required this.chatH3,
    required this.chatListBullet,
    required this.chatBlockquote,
    required this.chatTyping,
    required this.chatMeta,
    required this.sidebarTitle,
    required this.sidebarSubtitle,
    required this.sidebarSectionLabel,
    required this.sidebarSessionTitle,
    required this.menuLabel,
    required this.previewTitle,
    required this.previewBody,
  });

  final AppFontPreset appFontPreset;
  final AppFontPreset chatFontPreset;
  final TextStyle chatBody;
  final TextStyle chatStrong;
  final TextStyle chatH1;
  final TextStyle chatH2;
  final TextStyle chatH3;
  final TextStyle chatListBullet;
  final TextStyle chatBlockquote;
  final TextStyle chatTyping;
  final TextStyle chatMeta;
  final TextStyle sidebarTitle;
  final TextStyle sidebarSubtitle;
  final TextStyle sidebarSectionLabel;
  final TextStyle sidebarSessionTitle;
  final TextStyle menuLabel;
  final TextStyle previewTitle;
  final TextStyle previewBody;

  static AppTypography of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppTypography>() ?? AppTypography.fallback(theme);
  }

  factory AppTypography.resolve({
    required ThemeData theme,
    required AppThemeTokens tokens,
    required AppFontPreset appFontPreset,
    required AppFontPreset chatFontPreset,
  }) {
    final textTheme = theme.textTheme;
    final labelSmall = textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final labelMedium = textTheme.labelMedium ?? const TextStyle(fontSize: 12);
    final bodyMedium = textTheme.bodyMedium ?? const TextStyle(fontSize: 13);
    final bodyLarge = textTheme.bodyLarge ?? const TextStyle(fontSize: 15);
    final titleMedium = textTheme.titleMedium ?? const TextStyle(fontSize: 17);
    final titleLarge = textTheme.titleLarge ?? const TextStyle(fontSize: 22);

    return AppTypography(
      appFontPreset: appFontPreset,
      chatFontPreset: chatFontPreset,
      chatBody: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyLarge.copyWith(
          fontSize: _chatNudgedFontSize(15.5),
          height: 1.55,
          color: tokens.foreground,
        ),
      ),
      chatStrong: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyLarge.copyWith(
          fontSize: _chatNudgedFontSize(15.5),
          height: 1.55,
          color: tokens.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      chatH1: resolveFontPresetTextStyle(
        chatFontPreset,
        titleLarge.copyWith(
          fontSize: _chatNudgedFontSize(22),
          height: 1.4,
          color: tokens.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
      chatH2: resolveFontPresetTextStyle(
        chatFontPreset,
        titleMedium.copyWith(
          fontSize: _chatNudgedFontSize(18),
          height: 1.4,
          color: tokens.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      chatH3: resolveFontPresetTextStyle(
        chatFontPreset,
        titleMedium.copyWith(
          fontSize: _chatNudgedFontSize(16),
          height: 1.4,
          color: tokens.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      chatListBullet: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyLarge.copyWith(
          fontSize: _chatNudgedFontSize(15.5),
          color: tokens.foreground,
        ),
      ),
      chatBlockquote: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyLarge.copyWith(
          fontSize: _chatNudgedFontSize(15),
          height: 1.55,
          color: tokens.mutedForeground,
        ),
      ),
      chatTyping: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyLarge.copyWith(
          fontSize: _chatNudgedFontSize(15.5),
          height: 1.55,
          color: tokens.foreground,
        ),
      ),
      chatMeta: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyMedium.copyWith(
          fontSize: _chatNudgedFontSize(12.5),
          height: 1.35,
          color: tokens.subtleForeground,
        ),
      ),
      sidebarTitle: titleMedium.copyWith(
        color: tokens.foreground,
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
        height: 1.1,
      ),
      sidebarSubtitle: bodyMedium.copyWith(
        color: tokens.mutedForeground,
        fontSize: 12,
        height: 1.25,
      ),
      sidebarSectionLabel: labelSmall.copyWith(
        color: tokens.subtleForeground,
        fontSize: 9.5,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
      ),
      sidebarSessionTitle: labelMedium.copyWith(
        color: tokens.foreground,
        fontSize: 12.4,
        fontWeight: FontWeight.w600,
      ),
      menuLabel: bodyMedium.copyWith(
        color: tokens.foreground,
        fontSize: 13.25,
        fontWeight: FontWeight.w500,
      ),
      previewTitle: resolveFontPresetTextStyle(
        appFontPreset,
        titleMedium.copyWith(
          color: tokens.foreground,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      previewBody: resolveFontPresetTextStyle(
        chatFontPreset,
        bodyMedium.copyWith(
          color: tokens.mutedForeground,
          fontSize: _chatNudgedFontSize(13.5),
          height: 1.45,
        ),
      ),
    );
  }

  factory AppTypography.fallback(ThemeData theme) {
    final tokens = AppThemeTokens.fallback(theme.colorScheme);
    return AppTypography.resolve(
      theme: theme,
      tokens: tokens,
      appFontPreset: defaultAppFontPreset,
      chatFontPreset: defaultChatFontPreset,
    );
  }

  @override
  AppTypography copyWith({
    AppFontPreset? appFontPreset,
    AppFontPreset? chatFontPreset,
    TextStyle? chatBody,
    TextStyle? chatStrong,
    TextStyle? chatH1,
    TextStyle? chatH2,
    TextStyle? chatH3,
    TextStyle? chatListBullet,
    TextStyle? chatBlockquote,
    TextStyle? chatTyping,
    TextStyle? chatMeta,
    TextStyle? sidebarTitle,
    TextStyle? sidebarSubtitle,
    TextStyle? sidebarSectionLabel,
    TextStyle? sidebarSessionTitle,
    TextStyle? menuLabel,
    TextStyle? previewTitle,
    TextStyle? previewBody,
  }) {
    return AppTypography(
      appFontPreset: appFontPreset ?? this.appFontPreset,
      chatFontPreset: chatFontPreset ?? this.chatFontPreset,
      chatBody: chatBody ?? this.chatBody,
      chatStrong: chatStrong ?? this.chatStrong,
      chatH1: chatH1 ?? this.chatH1,
      chatH2: chatH2 ?? this.chatH2,
      chatH3: chatH3 ?? this.chatH3,
      chatListBullet: chatListBullet ?? this.chatListBullet,
      chatBlockquote: chatBlockquote ?? this.chatBlockquote,
      chatTyping: chatTyping ?? this.chatTyping,
      chatMeta: chatMeta ?? this.chatMeta,
      sidebarTitle: sidebarTitle ?? this.sidebarTitle,
      sidebarSubtitle: sidebarSubtitle ?? this.sidebarSubtitle,
      sidebarSectionLabel: sidebarSectionLabel ?? this.sidebarSectionLabel,
      sidebarSessionTitle: sidebarSessionTitle ?? this.sidebarSessionTitle,
      menuLabel: menuLabel ?? this.menuLabel,
      previewTitle: previewTitle ?? this.previewTitle,
      previewBody: previewBody ?? this.previewBody,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      appFontPreset: t < 0.5 ? appFontPreset : other.appFontPreset,
      chatFontPreset: t < 0.5 ? chatFontPreset : other.chatFontPreset,
      chatBody: TextStyle.lerp(chatBody, other.chatBody, t)!,
      chatStrong: TextStyle.lerp(chatStrong, other.chatStrong, t)!,
      chatH1: TextStyle.lerp(chatH1, other.chatH1, t)!,
      chatH2: TextStyle.lerp(chatH2, other.chatH2, t)!,
      chatH3: TextStyle.lerp(chatH3, other.chatH3, t)!,
      chatListBullet: TextStyle.lerp(chatListBullet, other.chatListBullet, t)!,
      chatBlockquote: TextStyle.lerp(chatBlockquote, other.chatBlockquote, t)!,
      chatTyping: TextStyle.lerp(chatTyping, other.chatTyping, t)!,
      chatMeta: TextStyle.lerp(chatMeta, other.chatMeta, t)!,
      sidebarTitle: TextStyle.lerp(sidebarTitle, other.sidebarTitle, t)!,
      sidebarSubtitle:
          TextStyle.lerp(sidebarSubtitle, other.sidebarSubtitle, t)!,
      sidebarSectionLabel:
          TextStyle.lerp(sidebarSectionLabel, other.sidebarSectionLabel, t)!,
      sidebarSessionTitle:
          TextStyle.lerp(sidebarSessionTitle, other.sidebarSessionTitle, t)!,
      menuLabel: TextStyle.lerp(menuLabel, other.menuLabel, t)!,
      previewTitle: TextStyle.lerp(previewTitle, other.previewTitle, t)!,
      previewBody: TextStyle.lerp(previewBody, other.previewBody, t)!,
    );
  }
}

class ChatColorTheme extends ThemeExtension<ChatColorTheme> {
  const ChatColorTheme({
    required this.mode,
  });

  final ChatColorMode mode;

  static ChatColorTheme of(BuildContext context) {
    return Theme.of(context).extension<ChatColorTheme>() ??
        const ChatColorTheme(mode: defaultChatColorMode);
  }

  @override
  ChatColorTheme copyWith({
    ChatColorMode? mode,
  }) {
    return ChatColorTheme(mode: mode ?? this.mode);
  }

  @override
  ChatColorTheme lerp(ThemeExtension<ChatColorTheme>? other, double t) {
    if (other is! ChatColorTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeContext on BuildContext {
  AppThemeTokens get appThemeTokens => AppThemeTokens.of(this);
  AppTypography get appTypography => AppTypography.of(this);
  ChatColorTheme get chatColorTheme => ChatColorTheme.of(this);
}

ThemeData buildTheme(
  ThemePalette palette, {
  required Brightness brightness,
  required AppFontPreset appFontPreset,
  required AppFontPreset chatFontPreset,
  ChatColorMode chatColorMode = defaultChatColorMode,
}) {
  final variant = _manualVariantFor(palette.mode, brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: variant.primary,
    brightness: brightness,
    primary: variant.primary,
    secondary: variant.secondary,
    surface: variant.surface,
  );
  return _buildThemeFromParts(
    scheme: scheme,
    tokens: AppThemeTokens.manual(palette.mode, brightness),
    appFontPreset: appFontPreset,
    chatFontPreset: chatFontPreset,
    chatColorMode: chatColorMode,
  );
}

ThemeData buildDynamicTheme(
  ColorScheme scheme, {
  required AppFontPreset appFontPreset,
  required AppFontPreset chatFontPreset,
  ChatColorMode chatColorMode = defaultChatColorMode,
}) {
  return _buildThemeFromParts(
    scheme: scheme,
    tokens: AppThemeTokens.dynamic(scheme),
    appFontPreset: appFontPreset,
    chatFontPreset: chatFontPreset,
    chatColorMode: chatColorMode,
  );
}

ThemeData _buildThemeFromParts({
  required ColorScheme scheme,
  required AppThemeTokens tokens,
  required AppFontPreset appFontPreset,
  required AppFontPreset chatFontPreset,
  required ChatColorMode chatColorMode,
}) {
  final brightness = scheme.brightness;
  final baseTextTheme = _decorateBaseTextTheme(
    _baseTextThemeFor(appFontPreset, brightness),
  );

  var theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.appBackground,
    canvasColor: tokens.modalSurface,
    shadowColor: tokens.shadow,
    textTheme: baseTextTheme,
    primaryTextTheme: baseTextTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.searchSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: tokens.mutedBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: tokens.accent, width: 1.2),
      ),
      hintStyle: baseTextTheme.bodyMedium?.copyWith(
        color: tokens.subtleForeground,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: tokens.panelSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.chipSurface,
      selectedColor: tokens.selectedSurface,
      side: BorderSide(color: tokens.mutedBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: tokens.mutedForeground),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: tokens.strongBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.modalSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.modalSurface,
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: tokens.foreground,
      ),
    ),
    dividerColor: tokens.mutedBorder,
  );

  final typography = AppTypography.resolve(
    theme: theme,
    tokens: tokens,
    appFontPreset: appFontPreset,
    chatFontPreset: chatFontPreset,
  );
  theme = theme.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      tokens,
      typography,
      ChatColorTheme(mode: chatColorMode),
    ],
  );
  return theme;
}

TextStyle resolveFontPresetTextStyle(
  AppFontPreset preset,
  TextStyle baseStyle,
) {
  final resolved = switch (preset) {
    AppFontPreset.systemDynamic => baseStyle,
    AppFontPreset.roboto => GoogleFonts.roboto(textStyle: baseStyle),
    AppFontPreset.inter => GoogleFonts.inter(textStyle: baseStyle),
    AppFontPreset.manrope => GoogleFonts.manrope(textStyle: baseStyle),
    AppFontPreset.urbanist => GoogleFonts.urbanist(textStyle: baseStyle),
    AppFontPreset.plusJakartaSans =>
      GoogleFonts.plusJakartaSans(textStyle: baseStyle),
    AppFontPreset.sora => GoogleFonts.sora(textStyle: baseStyle),
    AppFontPreset.outfit => GoogleFonts.outfit(textStyle: baseStyle),
    AppFontPreset.lexend => GoogleFonts.lexend(textStyle: baseStyle),
    AppFontPreset.workSans => GoogleFonts.workSans(textStyle: baseStyle),
    AppFontPreset.spaceGrotesk =>
      GoogleFonts.spaceGrotesk(textStyle: baseStyle),
    AppFontPreset.poppins => GoogleFonts.poppins(textStyle: baseStyle),
    AppFontPreset.nunito => GoogleFonts.nunito(textStyle: baseStyle),
    AppFontPreset.openSans => GoogleFonts.openSans(textStyle: baseStyle),
    AppFontPreset.dmSans => GoogleFonts.dmSans(textStyle: baseStyle),
    AppFontPreset.sourceSans3 => GoogleFonts.sourceSans3(textStyle: baseStyle),
    AppFontPreset.rubik => GoogleFonts.rubik(textStyle: baseStyle),
    AppFontPreset.ibmPlexSans => GoogleFonts.ibmPlexSans(textStyle: baseStyle),
    AppFontPreset.lora => GoogleFonts.lora(textStyle: baseStyle),
    AppFontPreset.hind => GoogleFonts.hind(textStyle: baseStyle),
    AppFontPreset.mukta => GoogleFonts.mukta(textStyle: baseStyle),
    AppFontPreset.baloo2 => GoogleFonts.baloo2(textStyle: baseStyle),
    AppFontPreset.martelSans => GoogleFonts.martelSans(textStyle: baseStyle),
    AppFontPreset.kalam => GoogleFonts.kalam(textStyle: baseStyle),
    AppFontPreset.tiroDevanagariHindi =>
      GoogleFonts.tiroDevanagariHindi(textStyle: baseStyle),
    AppFontPreset.notoSansDevanagari =>
      GoogleFonts.notoSansDevanagari(textStyle: baseStyle),
    AppFontPreset.notoSerifDevanagari =>
      GoogleFonts.notoSerifDevanagari(textStyle: baseStyle),
  };
  final safeResolved = _indicSafeTextStyle(resolved) ?? resolved;
  return safeResolved.copyWith(
    fontFamilyFallback: _fontFallbacksFor(preset),
  );
}

TextTheme _baseTextThemeFor(AppFontPreset preset, Brightness brightness) {
  final material = ThemeData(brightness: brightness).textTheme;
  final themed = switch (preset) {
    AppFontPreset.systemDynamic => material,
    AppFontPreset.roboto => GoogleFonts.robotoTextTheme(material),
    AppFontPreset.inter => GoogleFonts.interTextTheme(material),
    AppFontPreset.manrope => GoogleFonts.manropeTextTheme(material),
    AppFontPreset.urbanist => GoogleFonts.urbanistTextTheme(material),
    AppFontPreset.plusJakartaSans =>
      GoogleFonts.plusJakartaSansTextTheme(material),
    AppFontPreset.sora => GoogleFonts.soraTextTheme(material),
    AppFontPreset.outfit => GoogleFonts.outfitTextTheme(material),
    AppFontPreset.lexend => GoogleFonts.lexendTextTheme(material),
    AppFontPreset.workSans => GoogleFonts.workSansTextTheme(material),
    AppFontPreset.spaceGrotesk => GoogleFonts.spaceGroteskTextTheme(material),
    AppFontPreset.poppins => GoogleFonts.poppinsTextTheme(material),
    AppFontPreset.nunito => GoogleFonts.nunitoTextTheme(material),
    AppFontPreset.openSans => GoogleFonts.openSansTextTheme(material),
    AppFontPreset.dmSans => GoogleFonts.dmSansTextTheme(material),
    AppFontPreset.sourceSans3 => GoogleFonts.sourceSans3TextTheme(material),
    AppFontPreset.rubik => GoogleFonts.rubikTextTheme(material),
    AppFontPreset.ibmPlexSans => GoogleFonts.ibmPlexSansTextTheme(material),
    AppFontPreset.lora => GoogleFonts.loraTextTheme(material),
    AppFontPreset.hind => GoogleFonts.hindTextTheme(material),
    AppFontPreset.mukta => GoogleFonts.muktaTextTheme(material),
    AppFontPreset.baloo2 => GoogleFonts.baloo2TextTheme(material),
    AppFontPreset.martelSans => GoogleFonts.martelSansTextTheme(material),
    AppFontPreset.kalam => GoogleFonts.kalamTextTheme(material),
    AppFontPreset.tiroDevanagariHindi =>
      GoogleFonts.tiroDevanagariHindiTextTheme(material),
    AppFontPreset.notoSansDevanagari =>
      GoogleFonts.notoSansDevanagariTextTheme(material),
    AppFontPreset.notoSerifDevanagari =>
      GoogleFonts.notoSerifDevanagariTextTheme(material),
  };
  return _withFontFallbacks(themed, preset);
}

TextTheme _decorateBaseTextTheme(TextTheme baseTextTheme) {
  return baseTextTheme.copyWith(
    displayLarge: _indicSafeTextStyle(baseTextTheme.displayLarge?.copyWith(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      height: 1.02,
    )),
    displayMedium: _indicSafeTextStyle(baseTextTheme.displayMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.05,
    )),
    titleLarge: _indicSafeTextStyle(baseTextTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
    )),
    titleMedium: _indicSafeTextStyle(baseTextTheme.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    )),
    bodyLarge: _indicSafeTextStyle(baseTextTheme.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.45,
    )),
    bodyMedium: _indicSafeTextStyle(baseTextTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.45,
    )),
    labelLarge: _indicSafeTextStyle(baseTextTheme.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    )),
  );
}

TextTheme _withFontFallbacks(TextTheme textTheme, AppFontPreset preset) {
  return textTheme.copyWith(
    displayLarge: _withFallback(textTheme.displayLarge, preset),
    displayMedium: _withFallback(textTheme.displayMedium, preset),
    displaySmall: _withFallback(textTheme.displaySmall, preset),
    headlineLarge: _withFallback(textTheme.headlineLarge, preset),
    headlineMedium: _withFallback(textTheme.headlineMedium, preset),
    headlineSmall: _withFallback(textTheme.headlineSmall, preset),
    titleLarge: _withFallback(textTheme.titleLarge, preset),
    titleMedium: _withFallback(textTheme.titleMedium, preset),
    titleSmall: _withFallback(textTheme.titleSmall, preset),
    bodyLarge: _withFallback(textTheme.bodyLarge, preset),
    bodyMedium: _withFallback(textTheme.bodyMedium, preset),
    bodySmall: _withFallback(textTheme.bodySmall, preset),
    labelLarge: _withFallback(textTheme.labelLarge, preset),
    labelMedium: _withFallback(textTheme.labelMedium, preset),
    labelSmall: _withFallback(textTheme.labelSmall, preset),
  );
}

TextStyle? _withFallback(TextStyle? style, AppFontPreset preset) {
  return _indicSafeTextStyle(style)?.copyWith(
    fontFamilyFallback: _fontFallbacksFor(preset),
  );
}

List<String> _fontFallbacksFor(AppFontPreset preset) {
  final fallbacks = <String>[];
  fallbacks.add('NirmalaUI');
  if (preset != AppFontPreset.notoSansDevanagari) {
    fallbacks.add('Noto Sans Devanagari');
  }
  if (preset != AppFontPreset.kalam) {
    fallbacks.add('Kalam');
  }
  fallbacks.addAll(const ['Noto Sans', 'sans-serif']);
  return fallbacks;
}

TextStyle? _indicSafeTextStyle(TextStyle? style) {
  if (style == null) return null;
  final tunedWeight = _slightlyStrongerWeight(style.fontWeight);
  return style.copyWith(
    letterSpacing: 0,
    wordSpacing: 0.1,
    fontWeight: tunedWeight,
  );
}

FontWeight? _slightlyStrongerWeight(FontWeight? weight) {
  if (weight == null) return FontWeight.w500;
  if (weight.index < FontWeight.w500.index) {
    return FontWeight.w500;
  }
  return weight;
}

double _chatNudgedFontSize(double size) => size + 0.35;

class _ManualVariant {
  const _ManualVariant({
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
}

_ManualVariant _manualVariantFor(
  AppThemeMode family,
  Brightness brightness,
) {
  return switch ((family, brightness)) {
    (AppThemeMode.classicDark, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF0F1115),
        surface: Color(0xFF17191D),
        primary: Color(0xFF74A7FF),
        secondary: Color(0xFF93BAFF),
      ),
    (AppThemeMode.classicDark, Brightness.light) => const _ManualVariant(
        background: Color(0xFFF7F8FC),
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF356BFF),
        secondary: Color(0xFF6D8DFF),
      ),
    (AppThemeMode.pureLight, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF111318),
        surface: Color(0xFF181B22),
        primary: Color(0xFF7C96FF),
        secondary: Color(0xFFA3B3FF),
      ),
    (AppThemeMode.pureLight, Brightness.light) => const _ManualVariant(
        background: Color(0xFFF4F6FB),
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF376CFF),
        secondary: Color(0xFF6B8EFF),
      ),
    (AppThemeMode.midnightBlue, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF0D1219),
        surface: Color(0xFF141A23),
        primary: Color(0xFF7FA7FF),
        secondary: Color(0xFFA7BEFF),
      ),
    (AppThemeMode.midnightBlue, Brightness.light) => const _ManualVariant(
        background: Color(0xFFF5F8FF),
        surface: Color(0xFFFEFFFF),
        primary: Color(0xFF4D73D9),
        secondary: Color(0xFF7C97EA),
      ),
    (AppThemeMode.forestGreen, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF0D1310),
        surface: Color(0xFF141A17),
        primary: Color(0xFF4A9B6E),
        secondary: Color(0xFF79B694),
      ),
    (AppThemeMode.forestGreen, Brightness.light) => const _ManualVariant(
        background: Color(0xFFF4F8F5),
        surface: Color(0xFFFFFCFC),
        primary: Color(0xFF3D8B63),
        secondary: Color(0xFF6EAF8A),
      ),
    (AppThemeMode.sunsetPurple, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF110E16),
        surface: Color(0xFF181520),
        primary: Color(0xFF8E6BE2),
        secondary: Color(0xFFB29AEF),
      ),
    (AppThemeMode.sunsetPurple, Brightness.light) => const _ManualVariant(
        background: Color(0xFFFAF7FF),
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF7F5DCC),
        secondary: Color(0xFFA58BDE),
      ),
    (AppThemeMode.roseGold, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF161012),
        surface: Color(0xFF21181A),
        primary: Color(0xFFD78092),
        secondary: Color(0xFFE3AAB4),
      ),
    (AppThemeMode.roseGold, Brightness.light) => const _ManualVariant(
        background: Color(0xFFFDF7F8),
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFFC36F82),
        secondary: Color(0xFFDDA0AC),
      ),
    (AppThemeMode.oceanTeal, Brightness.dark) => const _ManualVariant(
        background: Color(0xFF0B1314),
        surface: Color(0xFF11191A),
        primary: Color(0xFF319C9A),
        secondary: Color(0xFF76BDB8),
      ),
    (AppThemeMode.oceanTeal, Brightness.light) => const _ManualVariant(
        background: Color(0xFFF4FBFA),
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF2A8D8B),
        secondary: Color(0xFF65B5B0),
      ),
  };
}

Color _blend(Color base, Color tint, double opacity) {
  return Color.alphaBlend(tint.withValues(alpha: opacity), base);
}

Color _tameAccent(Color accent, Color neutral, double blendAmount) {
  return Color.lerp(accent, neutral, blendAmount) ?? accent;
}
