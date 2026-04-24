import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';

class SidebarSectionData {
  const SidebarSectionData({
    required this.title,
    required this.chats,
  });

  final String title;
  final List<ChatSession> chats;
}

class SidebarViewModel {
  const SidebarViewModel({
    required this.sections,
    required this.starredChats,
    required this.selectedSessionId,
    required this.showSkeleton,
    required this.isRefreshing,
    required this.hasVisibleChats,
  });

  final List<SidebarSectionData> sections;
  final List<ChatSession> starredChats;
  final String? selectedSessionId;
  final bool showSkeleton;
  final bool isRefreshing;
  final bool hasVisibleChats;
}

final sidebarViewModelProvider = Provider.family<SidebarViewModel, String>(
  (ref, query) {
    final controller = ref.watch(appControllerProvider);
    final now = DateTime.now();
    final chats = controller.filteredSidebarSessions(query);
    final pinnedChats = chats.where((chat) => chat.isPinned).toList();
    final unpinnedChats = chats.where((chat) => !chat.isPinned).toList();
    final starredChats = chats.where((chat) => chat.isStarred).toList();

    List<ChatSession> pick(bool Function(Duration age) predicate) {
      return unpinnedChats.where((chat) {
        final age = now.difference(chat.updatedAt);
        return predicate(age);
      }).toList();
    }

    return SidebarViewModel(
      selectedSessionId: controller.selectedSession?.id,
      showSkeleton: controller.isHydratingChats && !controller.hasSidebarCache,
      isRefreshing: controller.isHydratingChats && controller.hasSidebarCache,
      hasVisibleChats: chats.isNotEmpty,
      starredChats: starredChats,
      sections: [
        SidebarSectionData(
          title: 'PINNED',
          chats: pinnedChats,
        ),
        SidebarSectionData(
          title: 'TODAY',
          chats: pick((age) => age.inDays == 0),
        ),
        SidebarSectionData(
          title: 'YESTERDAY',
          chats: pick((age) => age.inDays == 1),
        ),
        SidebarSectionData(
          title: 'LAST 30 DAYS',
          chats: pick((age) => age.inDays > 1 && age.inDays < 30),
        ),
        SidebarSectionData(
          title: 'OLDER',
          chats: pick((age) => age.inDays >= 30),
        ),
      ],
    );
  },
  dependencies: [appControllerProvider],
);
