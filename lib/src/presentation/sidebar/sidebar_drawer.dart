import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'sidebar_view_model.dart';

enum _SidebarBrowseMode {
  all,
  starred,
}

enum _SidebarChatMenuAction {
  pin,
  star,
  delete,
}

class SidebarDrawer extends ConsumerStatefulWidget {
  const SidebarDrawer({
    super.key,
    required this.searchController,
    this.scrollController,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onSelectHome,
    required this.onSelectSettings,
    this.compact = false,
  });

  final TextEditingController searchController;
  final ScrollController? scrollController;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollOffsetChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final VoidCallback onSelectHome;
  final VoidCallback onSelectSettings;
  final bool compact;

  @override
  ConsumerState<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends ConsumerState<SidebarDrawer> {
  _SidebarBrowseMode _mode = _SidebarBrowseMode.all;
  ScrollController? _ownedScrollController;
  bool _restoredInitialOffset = false;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _ownedScrollController!;

  @override
  void initState() {
    super.initState();
    _attachScrollController();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreInitialOffset());
  }

  @override
  void didUpdateWidget(covariant SidebarDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController(
          oldWidget.scrollController ?? _ownedScrollController);
      _attachScrollController();
      _restoredInitialOffset = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _restoreInitialOffset());
    }
  }

  @override
  void dispose() {
    _detachScrollController(_effectiveScrollController);
    _ownedScrollController?.dispose();
    super.dispose();
  }

  void _attachScrollController() {
    _ownedScrollController ??= ScrollController();
    _effectiveScrollController.addListener(_handleScrollOffsetChanged);
  }

  void _detachScrollController(ScrollController? controller) {
    controller?.removeListener(_handleScrollOffsetChanged);
  }

  void _handleScrollOffsetChanged() {
    widget.onScrollOffsetChanged?.call(_effectiveScrollController.offset);
  }

  void _restoreInitialOffset() {
    if (!mounted || _restoredInitialOffset) return;
    final targetOffset = widget.initialScrollOffset;
    if (targetOffset <= 0 || !_effectiveScrollController.hasClients) {
      _restoredInitialOffset = true;
      return;
    }
    final position = _effectiveScrollController.position;
    final clamped =
        targetOffset.clamp(0.0, position.maxScrollExtent).toDouble();
    _effectiveScrollController.jumpTo(clamped);
    _restoredInitialOffset = true;
  }

  @override
  Widget build(BuildContext context) {
    final vm =
        ref.watch(sidebarViewModelProvider(widget.searchController.text));
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final theme = Theme.of(context);
    final visibleSections = _mode == _SidebarBrowseMode.starred
        ? [
            SidebarSectionData(
              title: 'STARRED CHATS',
              chats: vm.starredChats,
            ),
          ]
        : vm.sections;
    final hasVisibleChats = _mode == _SidebarBrowseMode.starred
        ? vm.starredChats.isNotEmpty
        : vm.hasVisibleChats;

    return Container(
      width: widget.compact ? double.infinity : 264,
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 14 : 11,
        widget.compact ? 14 : 10,
        widget.compact ? 14 : 11,
        widget.compact ? 14 : 11,
      ),
      decoration: BoxDecoration(
        color: tokens.sidebarSurface
            .withValues(alpha: widget.compact ? 0.985 : 0.96),
        borderRadius: BorderRadius.circular(widget.compact ? 24 : 26),
        border: Border.all(color: tokens.mutedBorder),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: widget.compact ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) ...[
            Row(
              children: [
                const AvatarPlaceholder(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gidar AI',
                        style: typography.sidebarTitle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                const AvatarPlaceholder(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gidar AI',
                        style: typography.sidebarTitle.copyWith(fontSize: 15.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                minimumSize: Size.fromHeight(widget.compact ? 40 : 42),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 14 : 16,
                  vertical: widget.compact ? 11 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: widget.onNewChat,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                widget.compact ? 'New Chat' : 'NEW CHAT',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tokens.onAccent,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: widget.compact ? 0.1 : 0.3,
                ),
              ),
            ),
          ),
          SizedBox(height: widget.compact ? 10 : 9),
          TextField(
            controller: widget.searchController,
            onChanged: (_) => widget.onSearchChanged(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.foreground,
              fontSize: 12.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search conversations',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.subtleForeground,
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              filled: true,
              fillColor: tokens.searchSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tokens.mutedBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tokens.mutedBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tokens.strongBorder),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SidebarModeSwitcher(
            mode: _mode,
            starredCount: vm.starredChats.length,
            onModeChanged: (mode) => setState(() => _mode = mode),
          ),
          SizedBox(height: widget.compact ? 10 : 9),
          if (widget.compact)
            Row(
              children: [
                Expanded(
                  child: _CompactSidebarAction(
                    onPressed: widget.onSelectHome,
                    icon: const Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactSidebarAction(
                    onPressed: widget.onSelectSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ),
              ],
            ),
          if (widget.compact) const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: vm.showSkeleton
                  ? const _SidebarSkeletonList(
                      key: ValueKey('sidebar-skeleton'),
                    )
                  : _SidebarContentList(
                      key: ValueKey(
                        'sidebar-content-${vm.isRefreshing}-$hasVisibleChats-${visibleSections.length}-${_mode.name}',
                      ),
                      sections: visibleSections,
                      selectedSessionId: vm.selectedSessionId,
                      scrollController: _effectiveScrollController,
                      onSelectChat: widget.onSelectChat,
                      isRefreshing: vm.isRefreshing,
                      emptyLabel: _mode == _SidebarBrowseMode.starred
                          ? 'No starred chats yet.'
                          : 'Your chats will appear here.',
                    ),
            ),
          ),
          if (!widget.compact)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.settings_rounded,
                color: tokens.mutedForeground,
              ),
              title: Text(
                'Settings',
                style: typography.menuLabel,
              ),
              onTap: widget.onSelectSettings,
            ),
        ],
      ),
    );
  }
}

class _SidebarContentList extends StatelessWidget {
  const _SidebarContentList({
    super.key,
    required this.sections,
    required this.selectedSessionId,
    this.scrollController,
    required this.onSelectChat,
    required this.isRefreshing,
    required this.emptyLabel,
  });

  final List<SidebarSectionData> sections;
  final String? selectedSessionId;
  final ScrollController? scrollController;
  final ValueChanged<String> onSelectChat;
  final bool isRefreshing;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final hasChats = sections.any((section) => section.chats.isNotEmpty);

    return ListView(
      controller: scrollController,
      key: ValueKey('sidebar-list-$hasChats-$isRefreshing'),
      padding: EdgeInsets.zero,
      children: [
        if (isRefreshing)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.subtleSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.mutedBorder),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refreshing chats...',
                      overflow: TextOverflow.ellipsis,
                      style: typography.sidebarSubtitle.copyWith(
                        color: tokens.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!hasChats)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              emptyLabel,
              style: typography.sidebarSubtitle.copyWith(
                color: tokens.subtleForeground,
              ),
            ),
          )
        else
          ...sections.map((section) {
            return _SidebarSection(
              data: section,
              selectedSessionId: selectedSessionId,
              onSelectChat: onSelectChat,
            );
          }),
      ],
    );
  }
}

class _SidebarSkeletonList extends StatelessWidget {
  const _SidebarSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('sidebar-skeleton-list'),
      padding: EdgeInsets.zero,
      children: const [
        _SidebarSkeletonSection(titleWidthFactor: 0.26),
        SizedBox(height: 10),
        _SidebarSkeletonSection(titleWidthFactor: 0.34),
      ],
    );
  }
}

class _SidebarSkeletonSection extends StatelessWidget {
  const _SidebarSkeletonSection({
    required this.titleWidthFactor,
  });

  final double titleWidthFactor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 180.0;
              return Row(
                children: [
                  SizedBox(
                    width: maxWidth * titleWidthFactor,
                    child: const _SidebarSkeletonLine(height: 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: tokens.mutedBorder,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const _SidebarSkeletonRow(),
        const SizedBox(height: 4),
        const _SidebarSkeletonRow(),
        const SizedBox(height: 4),
        const _SidebarSkeletonRow(shorter: true),
      ],
    );
  }
}

class _SidebarSkeletonRow extends StatelessWidget {
  const _SidebarSkeletonRow({this.shorter = false});

  final bool shorter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 0.82),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      onEnd: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.topBarSurface.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 15,
              decoration: BoxDecoration(
                color: tokens.mutedBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: tokens.subtleForeground.withValues(alpha: 0.55),
              size: 13,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FractionallySizedBox(
                widthFactor: shorter ? 0.58 : 0.82,
                alignment: Alignment.centerLeft,
                child: const _SidebarSkeletonLine(height: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSkeletonLine extends StatelessWidget {
  const _SidebarSkeletonLine({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: tokens.subtleForeground.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SidebarSection extends ConsumerWidget {
  const _SidebarSection({
    required this.data,
    required this.selectedSessionId,
    required this.onSelectChat,
  });

  final SidebarSectionData data;
  final String? selectedSessionId;
  final ValueChanged<String> onSelectChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.chats.isEmpty) return const SizedBox.shrink();
    final controller = ref.read(appControllerProvider);
    final interactive = controller.hasHydratedChats;
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              children: [
                Text(
                  data.title,
                  style: typography.sidebarSectionLabel,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: tokens.mutedBorder,
                  ),
                ),
              ],
            ),
          ),
          for (final chat in data.chats)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _SidebarChatRow(
                chat: chat,
                active: selectedSessionId == chat.id,
                enabled: interactive,
                onTap: () {
                  controller.selectSession(chat);
                  onSelectChat(chat.id);
                },
                onTogglePin: () => controller.toggleSessionPinned(chat.id),
                onToggleStar: () => controller.toggleSessionStarred(chat.id),
                onDelete: () => controller.deleteSession(chat.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarChatRow extends StatelessWidget {
  const _SidebarChatRow({
    required this.chat,
    required this.active,
    required this.enabled,
    required this.onTap,
    required this.onTogglePin,
    required this.onToggleStar,
    required this.onDelete,
  });

  final ChatSession chat;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleStar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? tokens.selectedSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active
              ? tokens.accent.withValues(alpha: 0.26)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: active ? tokens.topBarSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 15,
                  decoration: BoxDecoration(
                    color: active ? tokens.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: active ? tokens.accent : tokens.mutedForeground,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.sidebarSessionTitle.copyWith(
                      color: active ? tokens.accent : tokens.foreground,
                    ),
                  ),
                ),
                if (chat.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: active ? tokens.accent : tokens.mutedForeground,
                    ),
                  ),
                if (chat.isStarred)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: Color(0xFFFFC107),
                    ),
                  ),
                PopupMenuButton<_SidebarChatMenuAction>(
                  enabled: enabled,
                  padding: EdgeInsets.zero,
                  tooltip: 'Chat actions',
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 16,
                    color: tokens.subtleForeground,
                  ),
                  color: tokens.modalSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case _SidebarChatMenuAction.pin:
                        onTogglePin();
                        break;
                      case _SidebarChatMenuAction.star:
                        onToggleStar();
                        break;
                      case _SidebarChatMenuAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _SidebarChatMenuAction.pin,
                      child: _sidebarMenuRow(
                        chat.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                        chat.isPinned ? 'Unpin chat' : 'Pin chat',
                      ),
                    ),
                    PopupMenuItem(
                      value: _SidebarChatMenuAction.star,
                      child: _sidebarMenuRow(
                        chat.isStarred
                            ? Icons.star_outline_rounded
                            : Icons.star_rounded,
                        chat.isStarred ? 'Remove star' : 'Star chat',
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SidebarChatMenuAction.delete,
                      child: _sidebarMenuRow(
                        Icons.delete_outline_rounded,
                        'Delete chat',
                        color: const Color(0xFFE35D6A),
                      ),
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

class AvatarPlaceholder extends StatelessWidget {
  const AvatarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: tokens.selectedSurface,
        border: Border.all(color: tokens.strongBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SvgPicture.asset(
          'assets/gidar_logo.svg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SidebarModeSwitcher extends StatelessWidget {
  const _SidebarModeSwitcher({
    required this.mode,
    required this.starredCount,
    required this.onModeChanged,
  });

  final _SidebarBrowseMode mode;
  final int starredCount;
  final ValueChanged<_SidebarBrowseMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.searchSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SidebarModeButton(
              label: 'All Chats',
              selected: mode == _SidebarBrowseMode.all,
              onTap: () => onModeChanged(_SidebarBrowseMode.all),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SidebarModeButton(
              label: starredCount == 0 ? 'Starred' : 'Starred ($starredCount)',
              selected: mode == _SidebarBrowseMode.starred,
              onTap: () => onModeChanged(_SidebarBrowseMode.starred),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarModeButton extends StatelessWidget {
  const _SidebarModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.selectedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: tokens.accent.withValues(alpha: 0.18))
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typography.sidebarSessionTitle.copyWith(
            color: selected ? tokens.accent : tokens.foreground,
            fontSize: 12.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Widget _sidebarMenuRow(
  IconData icon,
  String label, {
  Color? color,
}) {
  return Builder(
    builder: (context) {
      final tokens = context.appThemeTokens;
      final tint = color ?? tokens.foreground;
      return Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CompactSidebarAction extends StatelessWidget {
  const _CompactSidebarAction({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.foreground,
        backgroundColor: tokens.chipSurface.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: tokens.mutedBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
