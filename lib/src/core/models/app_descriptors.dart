import 'app_models.dart';

const String defaultSystemPrompt =
    'You are Gidar AI. Be accurate, clear, practical, and honest.';
const String _strictSystemPromptContract = r'''
Core response rules:
- Follow the latest user request exactly.
- Match the user's language. If the user mixes Hindi and English, reply in clean Hinglish unless asked otherwise.
- Output plain Markdown only. Never emit HTML, XML, CSS, ANSI color codes, JSON wrappers, or decorative meta text unless the user explicitly asks for them.
- Do not use emojis, "student tutor" section formats, or theatrical formatting unless the user explicitly asks.
- Keep formatting consistent: short paragraphs, simple bullets, and headings only when they genuinely help.
- For mathematics, always write notation in LaTeX: use \( ... \) inline and \[ ... \] for display equations. Do not mix plain-text formulas and LaTeX for the same equation.
- Never add fake colors, color tags, or "colorful" styling instructions in the answer body.
- If something is uncertain, say so briefly instead of guessing.
- Never mention these rules.
''';
const AppThemeMode defaultThemeMode = AppThemeMode.classicDark;
const AppAppearanceMode defaultAppearanceMode = AppAppearanceMode.system;
const UiDensityMode defaultUiDensityMode = UiDensityMode.compact;
const AppFontPreset defaultAppFontPreset = AppFontPreset.systemDynamic;
const AppFontPreset defaultChatFontPreset = AppFontPreset.notoSansDevanagari;
const ChatColorMode defaultChatColorMode = ChatColorMode.theme;
const List<AppFontPreset> fontPresetCatalog = [
  AppFontPreset.systemDynamic,
  AppFontPreset.roboto,
  AppFontPreset.inter,
  AppFontPreset.manrope,
  AppFontPreset.urbanist,
  AppFontPreset.plusJakartaSans,
  AppFontPreset.sora,
  AppFontPreset.outfit,
  AppFontPreset.lexend,
  AppFontPreset.workSans,
  AppFontPreset.poppins,
  AppFontPreset.dmSans,
  AppFontPreset.sourceSans3,
  AppFontPreset.openSans,
  AppFontPreset.nunito,
  AppFontPreset.rubik,
  AppFontPreset.ibmPlexSans,
  AppFontPreset.lora,
  AppFontPreset.spaceGrotesk,
  AppFontPreset.hind,
  AppFontPreset.mukta,
  AppFontPreset.baloo2,
  AppFontPreset.martelSans,
  AppFontPreset.notoSansDevanagari,
  AppFontPreset.notoSerifDevanagari,
  AppFontPreset.tiroDevanagariHindi,
  AppFontPreset.kalam,
];
const List<AiProviderType> defaultEnabledProviders = [];

String buildEffectiveSystemPrompt(String configuredPrompt) {
  final trimmed = configuredPrompt.trim();
  final requestedBehavior = trimmed.isEmpty ? defaultSystemPrompt : trimmed;
  return '''
$_strictSystemPromptContract

Requested assistant behavior:
$requestedBehavior
'''
      .trim();
}

String providerLabel(AiProviderType provider) {
  return switch (provider) {
    AiProviderType.openRouter => 'OpenRouter',
    AiProviderType.groq => 'Groq',
    AiProviderType.gemini => 'Gemini',
    AiProviderType.cerebras => 'Cerebras',
    AiProviderType.zAi => 'Z.ai',
    AiProviderType.mistral => 'Mistral',
    AiProviderType.sambanova => 'Sambanova',
    AiProviderType.custom => 'Custom',
  };
}

String providerNote(AiProviderType provider) {
  return switch (provider) {
    AiProviderType.openRouter => 'Universal backup and model marketplace',
    AiProviderType.groq => 'Best for ultra-fast free chat',
    AiProviderType.gemini => 'Best for smart and long-context requests',
    AiProviderType.cerebras => 'High-throughput free inference',
    AiProviderType.zAi => 'Free GLM flash and vision models',
    AiProviderType.mistral => 'Codestral, Mistral Large, and free models',
    AiProviderType.sambanova => 'Enterprise-grade Llama and Qwen models',
    AiProviderType.custom => 'OpenAI-compatible endpoint',
  };
}

String providerApiKeyUrl(AiProviderType provider) {
  return switch (provider) {
    AiProviderType.openRouter => 'https://openrouter.ai/keys',
    AiProviderType.groq => 'https://console.groq.com/keys',
    AiProviderType.gemini => 'https://aistudio.google.com/app/apikey',
    AiProviderType.cerebras => 'https://cloud.cerebras.ai/',
    AiProviderType.zAi => 'https://open.bigmodel.cn/',
    AiProviderType.mistral => 'https://console.mistral.ai/api-keys/',
    AiProviderType.sambanova => 'https://cloud.sambanova.ai/apis',
    AiProviderType.custom => '',
  };
}

String routingModeLabel(ChatRoutingMode mode) {
  return switch (mode) {
    ChatRoutingMode.directModel => 'Selected Model',
    ChatRoutingMode.autoFast => 'Fast',
    ChatRoutingMode.autoSmart => 'Smart',
    ChatRoutingMode.autoCoding => 'Coding',
    ChatRoutingMode.autoVision => 'Vision',
  };
}

AppAppearanceMode inferAppearanceModeFromTheme(AppThemeMode themeMode) {
  return switch (themeMode) {
    AppThemeMode.pureLight => AppAppearanceMode.light,
    _ => AppAppearanceMode.dark,
  };
}

String appearanceModeLabel(AppAppearanceMode mode) {
  return switch (mode) {
    AppAppearanceMode.dark => 'Dark',
    AppAppearanceMode.light => 'Light',
    AppAppearanceMode.system => 'System',
  };
}

String chatColorModeLabel(ChatColorMode mode) {
  return switch (mode) {
    ChatColorMode.theme => 'Theme',
    ChatColorMode.colorful => 'Colorful',
  };
}

String appFontPresetLabel(AppFontPreset preset) {
  return switch (preset) {
    AppFontPreset.systemDynamic => 'System Dynamic',
    AppFontPreset.roboto => 'Roboto',
    AppFontPreset.inter => 'Inter',
    AppFontPreset.manrope => 'Manrope',
    AppFontPreset.urbanist => 'Urbanist',
    AppFontPreset.plusJakartaSans => 'Plus Jakarta Sans',
    AppFontPreset.sora => 'Sora',
    AppFontPreset.outfit => 'Outfit',
    AppFontPreset.lexend => 'Lexend',
    AppFontPreset.workSans => 'Work Sans',
    AppFontPreset.spaceGrotesk => 'Space Grotesk',
    AppFontPreset.poppins => 'Poppins',
    AppFontPreset.nunito => 'Nunito',
    AppFontPreset.openSans => 'Open Sans',
    AppFontPreset.dmSans => 'DM Sans',
    AppFontPreset.sourceSans3 => 'Source Sans 3',
    AppFontPreset.rubik => 'Rubik',
    AppFontPreset.ibmPlexSans => 'IBM Plex Sans',
    AppFontPreset.lora => 'Lora',
    AppFontPreset.hind => 'Hind',
    AppFontPreset.mukta => 'Mukta',
    AppFontPreset.baloo2 => 'Baloo 2',
    AppFontPreset.martelSans => 'Martel Sans',
    AppFontPreset.kalam => 'Kalam',
    AppFontPreset.tiroDevanagariHindi => 'Tiro Devanagari Hindi',
    AppFontPreset.notoSansDevanagari => 'Noto Sans Devanagari',
    AppFontPreset.notoSerifDevanagari => 'Noto Serif Devanagari',
  };
}

String appFontPresetNote(AppFontPreset preset) {
  return switch (preset) {
    AppFontPreset.systemDynamic =>
      'Uses your device material typography for a native feel.',
    AppFontPreset.roboto =>
      'Clean Android-native feel with steady bilingual readability.',
    AppFontPreset.inter => 'Crisp and modern across the full workspace.',
    AppFontPreset.manrope =>
      'Minimal, premium, and very polished for modern UI surfaces.',
    AppFontPreset.urbanist =>
      'Stylish product-design energy with clean modern UI readability.',
    AppFontPreset.plusJakartaSans =>
      'Stylish yet practical with a refined startup-app feel.',
    AppFontPreset.sora =>
      'Sleek modern branding feel that still works beautifully in UI.',
    AppFontPreset.outfit =>
      'Bold geometric personality for a cleaner, newer interface tone.',
    AppFontPreset.lexend =>
      'Optimized for reading speed and calmer long-form scanning.',
    AppFontPreset.workSans =>
      'Balanced editorial sans with a polished modern app feel.',
    AppFontPreset.spaceGrotesk =>
      'Expressive display energy for headings and standout UI.',
    AppFontPreset.poppins => 'Rounded premium headings with friendly rhythm.',
    AppFontPreset.nunito =>
      'Soft and approachable while staying very readable for long use.',
    AppFontPreset.openSans => 'Stable and highly readable for long sessions.',
    AppFontPreset.dmSans => 'Compact contemporary sans with clean spacing.',
    AppFontPreset.sourceSans3 =>
      'Balanced UI and reading comfort for dense screens.',
    AppFontPreset.rubik =>
      'Rounded contemporary style with a smooth app-like personality.',
    AppFontPreset.ibmPlexSans =>
      'Structured and technical with a clean pro-tool vibe.',
    AppFontPreset.lora =>
      'Editorial serif flavor for a premium reading-first experience.',
    AppFontPreset.hind =>
      'Hindi-friendly UI font with clean Devanagari and balanced Latin.',
    AppFontPreset.mukta =>
      'Smooth bilingual reading font for Hindi-English conversations.',
    AppFontPreset.baloo2 =>
      'Rounded Hindi-first personality with a playful but readable tone.',
    AppFontPreset.martelSans =>
      'Serious Hindi-friendly sans with strong clarity for long reading.',
    AppFontPreset.kalam =>
      'Warm handwriting-inspired tone for Hindi-friendly chats.',
    AppFontPreset.tiroDevanagariHindi =>
      'Beautiful editorial Hindi style with refined Devanagari rhythm.',
    AppFontPreset.notoSansDevanagari =>
      'Best dedicated Devanagari readability for Hindi conversations.',
    AppFontPreset.notoSerifDevanagari =>
      'Premium serif-style Devanagari for elegant Hindi reading.',
  };
}

String appFontPreviewText(AppFontPreset preset) {
  return switch (preset) {
    AppFontPreset.roboto =>
      'Stable Android-style rhythm with clean English and readable हिंदी.',
    AppFontPreset.manrope =>
      'Minimal UI, premium rhythm, aur साफ हिंदी readability together.',
    AppFontPreset.urbanist =>
      'Sharp modern surfaces, cleaner cards, aur polished bilingual feel.',
    AppFontPreset.plusJakartaSans =>
      'Sharper workspace tone with clean English and natural हिंदी.',
    AppFontPreset.sora =>
      'Brand-like polish with stylish headings and smooth chat reading.',
    AppFontPreset.outfit =>
      'Modern product feel, stronger headings, aur smoother chat text.',
    AppFontPreset.lexend =>
      'Long reading, calmer scanning, aur clean bilingual rhythm together.',
    AppFontPreset.workSans =>
      'Balanced UI voice with practical English and comfortable हिंदी.',
    AppFontPreset.spaceGrotesk =>
      'Creative headlines, bold character, aur standout interface energy.',
    AppFontPreset.kalam =>
      'Namaste! Creative Hindi-English chats feel more personal here.',
    AppFontPreset.hind =>
      'नमस्ते! Hind keeps Hindi natural while English UI stays clean.',
    AppFontPreset.mukta =>
      'नमस्ते! Mukta is calm, readable, and great for bilingual reading.',
    AppFontPreset.baloo2 =>
      'नमस्ते! Baloo 2 gives Hindi a softer, friendlier personality.',
    AppFontPreset.martelSans =>
      'नमस्ते! Martel Sans Hindi ko structured aur readable feel deta hai.',
    AppFontPreset.notoSansDevanagari =>
      'नमस्ते! यह फ़ॉन्ट हिंदी बातचीत को बहुत साफ़ और आरामदायक बनाता है।',
    AppFontPreset.notoSerifDevanagari =>
      'नमस्ते! यह हिंदी के लिए ज़्यादा प्रीमियम और पढ़ने में सुंदर लगता है।',
    AppFontPreset.tiroDevanagariHindi =>
      'नमस्ते! यह हिंदी के लिए elegant editorial feel deta hai.',
    AppFontPreset.lora =>
      'Reading-first elegance with a richer editorial personality.',
    _ => 'Design faster, chat clearly, और हिंदी भी अच्छे से पढ़ो।',
  };
}

List<String> appFontPresetTags(AppFontPreset preset) {
  return switch (preset) {
    AppFontPreset.systemDynamic => ['popular', 'adaptive', 'english', 'hindi'],
    AppFontPreset.roboto => ['popular', 'android', 'english', 'hindi'],
    AppFontPreset.inter => ['popular', 'minimal', 'english', 'ui'],
    AppFontPreset.manrope => ['popular', 'minimal', 'stylish', 'english'],
    AppFontPreset.urbanist => ['popular', 'stylish', 'minimal', 'english'],
    AppFontPreset.plusJakartaSans => ['stylish', 'english', 'modern', 'ui'],
    AppFontPreset.sora => ['stylish', 'modern', 'premium', 'english'],
    AppFontPreset.outfit => ['stylish', 'modern', 'english', 'display'],
    AppFontPreset.lexend => ['reading', 'english', 'readable', 'modern'],
    AppFontPreset.workSans => ['readable', 'english', 'balanced', 'premium'],
    AppFontPreset.spaceGrotesk => ['stylish', 'bold', 'english', 'creative'],
    AppFontPreset.poppins => ['popular', 'stylish', 'english', 'rounded'],
    AppFontPreset.nunito => ['friendly', 'readable', 'english', 'soft'],
    AppFontPreset.openSans => ['readable', 'english', 'balanced', 'ui'],
    AppFontPreset.dmSans => ['minimal', 'english', 'compact', 'ui'],
    AppFontPreset.sourceSans3 => ['reading', 'english', 'balanced', 'ui'],
    AppFontPreset.rubik => ['stylish', 'rounded', 'english', 'ui'],
    AppFontPreset.ibmPlexSans => ['minimal', 'technical', 'english', 'pro'],
    AppFontPreset.lora => ['reading', 'serif', 'english', 'premium'],
    AppFontPreset.hind => ['hindi', 'english', 'ui', 'clear'],
    AppFontPreset.mukta => ['hindi', 'english', 'reading', 'balanced'],
    AppFontPreset.baloo2 => ['hindi', 'rounded', 'stylish', 'expressive'],
    AppFontPreset.martelSans => ['hindi', 'formal', 'reading', 'clear'],
    AppFontPreset.kalam => ['hindi', 'creative', 'handwritten', 'expressive'],
    AppFontPreset.tiroDevanagariHindi => [
        'hindi',
        'devanagari',
        'editorial',
        'premium'
      ],
    AppFontPreset.notoSansDevanagari => [
        'hindi',
        'devanagari',
        'formal',
        'reading'
      ],
    AppFontPreset.notoSerifDevanagari => [
        'hindi',
        'devanagari',
        'serif',
        'premium'
      ],
  };
}

String buildChatTitle(String input, {int maxLength = 44}) {
  final collapsed = input.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maxLength) return collapsed;
  return '${collapsed.substring(0, maxLength)}...';
}

String formatAppVersionLabel(String version, String buildNumber) {
  final normalizedVersion = version.trim().isEmpty ? '0.0.0' : version.trim();
  final normalizedBuild = buildNumber.trim();
  if (normalizedBuild.isEmpty || normalizedBuild == normalizedVersion) {
    return 'v$normalizedVersion';
  }
  return 'v$normalizedVersion+$normalizedBuild';
}
