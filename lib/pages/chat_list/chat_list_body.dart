import 'package:animations/animations.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item.dart';
import 'package:fluffychat/pages/chat_list/search_title.dart';
import 'package:fluffychat/pages/chat_list/space_view.dart';
import 'package:fluffychat/pages/chat_list/utils/on_chat_tap.dart';
import 'package:fluffychat/pages/user_bottom_sheet/user_bottom_sheet.dart';
import 'package:fluffychat/pangea/widgets/chat_list/chat_list_body_text.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/public_room_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';

import '../../config/themes.dart';
import '../../widgets/connection_status_header.dart';
import '../../widgets/matrix.dart';
import 'chat_list_header.dart';

class ChatListViewBody extends StatelessWidget {
  final ChatListController controller;

  const ChatListViewBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final publicRooms = controller.roomSearchResult?.chunk
        .where((room) => room.roomType != 'm.space')
        .toList();
    final publicSpaces = controller.roomSearchResult?.chunk
        .where((room) => room.roomType == 'm.space')
        .toList();
    final userSearchResult = controller.userSearchResult;
    final client = Matrix.of(context).client;
    const dummyChatCount = 4;
    final titleColor =
        Theme.of(context).textTheme.bodyLarge!.color!.withAlpha(100);
    final subtitleColor =
        Theme.of(context).textTheme.bodyLarge!.color!.withAlpha(50);

    return PageTransitionSwitcher(
      transitionBuilder: (
        Widget child,
        Animation<double> primaryAnimation,
        Animation<double> secondaryAnimation,
      ) {
        return SharedAxisTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
      },
      child: StreamBuilder(
        key: ValueKey(
          client.userID.toString() +
              controller.activeFilter.toString() +
              controller.activeSpaceId.toString(),
        ),
        stream: client.onSync.stream
            .where((s) => s.hasRoomUpdate)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, _) {
          if (controller.activeFilter == ActiveFilter.spaces) {
            return SpaceView(
              controller,
              scrollController: controller.scrollController,
              key: Key(controller.activeSpaceId ?? 'Spaces'),
            );
          }
          final rooms = controller.filteredRooms;
          return SafeArea(
            child: CustomScrollView(
              controller: controller.scrollController,
              slivers: [
                ChatListHeader(controller: controller),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (controller.isSearchMode) ...[
                        SearchTitle(
                          title: L10n.of(context)!.publicRooms,
                          icon: const Icon(Icons.explore_outlined),
                        ),
                        PublicRoomsHorizontalList(publicRooms: publicRooms),
                        SearchTitle(
                          title: L10n.of(context)!.publicSpaces,
                          icon: const Icon(Icons.workspaces_outlined),
                        ),
                        PublicRoomsHorizontalList(publicRooms: publicSpaces),
                        SearchTitle(
                          title: L10n.of(context)!.users,
                          icon: const Icon(Icons.group_outlined),
                        ),
                        AnimatedContainer(
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(),
                          height: userSearchResult == null ||
                                  userSearchResult.results.isEmpty
                              ? 0
                              : 106,
                          duration: FluffyThemes.animationDuration,
                          curve: FluffyThemes.animationCurve,
                          child: userSearchResult == null
                              ? null
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: userSearchResult.results.length,
                                  itemBuilder: (context, i) => _SearchItem(
                                    title: userSearchResult
                                            .results[i].displayName ??
                                        userSearchResult
                                            .results[i].userId.localpart ??
                                        L10n.of(context)!.unknownDevice,
                                    avatar:
                                        userSearchResult.results[i].avatarUrl,
                                    onPressed: () => showAdaptiveBottomSheet(
                                      context: context,
                                      builder: (c) => UserBottomSheet(
                                        profile: userSearchResult.results[i],
                                        outerContext: context,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                      // #Pangea
                      // if (!controller.isSearchMode &&
                      //    controller.activeFilter != ActiveFilter.groups &&
                      //    AppConfig.showPresences)
                      //  GestureDetector(
                      //    onLongPress: () => controller.dismissStatusList(),
                      //    child: StatusMessageList(
                      //      onStatusEdit: controller.setStatus,
                      //    ),
                      //  ),
                      // Pangea#
                      const ConnectionStatusHeader(),
                      AnimatedContainer(
                        height: controller.isTorBrowser ? 64 : 0,
                        duration: FluffyThemes.animationDuration,
                        curve: FluffyThemes.animationCurve,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: ListTile(
                            leading: const Icon(Icons.vpn_key),
                            title: Text(L10n.of(context)!.dehydrateTor),
                            subtitle: Text(L10n.of(context)!.dehydrateTorLong),
                            trailing: const Icon(Icons.chevron_right_outlined),
                            onTap: controller.dehydrate,
                          ),
                        ),
                      ),
                      if (controller.isSearchMode)
                        SearchTitle(
                          title: L10n.of(context)!.chats,
                          icon: const Icon(Icons.forum_outlined),
                        ),
                      if (client.prevBatch != null &&
                          rooms.isEmpty &&
                          !controller.isSearchMode) ...[
                        // #Pangea
                        // Padding(
                        //   padding: const EdgeInsets.all(32.0),
                        //   child: Icon(
                        //     CupertinoIcons.chat_bubble_2,
                        //     size: 128,
                        //     color:
                        //         Theme.of(context).colorScheme.onInverseSurface,
                        //   ),
                        // ),
                        Center(
                          child: ChatListBodyStartText(
                            controller: controller,
                          ),
                        ),
                        // Pangea#
                      ],
                    ],
                  ),
                ),
                if (client.prevBatch == null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Opacity(
                        opacity: (dummyChatCount - i) / dummyChatCount,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: titleColor,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: titleColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 36),
                              Container(
                                height: 14,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: subtitleColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 14,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: subtitleColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Container(
                            decoration: BoxDecoration(
                              color: subtitleColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            height: 12,
                            margin: const EdgeInsets.only(right: 22),
                          ),
                        ),
                      ),
                      childCount: dummyChatCount,
                    ),
                  ),
                if (client.prevBatch != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int i) {
                        if (!rooms[i]
                            .getLocalizedDisplayname(
                              MatrixLocals(L10n.of(context)!),
                            )
                            .toLowerCase()
                            .contains(
                              controller.searchController.text.toLowerCase(),
                            )) {
                          return const SizedBox.shrink();
                        }
                        final activeChat = controller.activeChat == rooms[i].id;
                        return ChatListItem(
                          rooms[i],
                          key: Key('chat_list_item_${rooms[i].id}'),
                          selected:
                              controller.selectedRoomIds.contains(rooms[i].id),
                          onTap: controller.selectMode == SelectMode.select
                              ? () => controller.toggleSelection(rooms[i].id)
                              : () => onChatTap(rooms[i], context),
                          onLongPress: () =>
                              controller.toggleSelection(rooms[i].id),
                          activeChat: activeChat,
                        );
                      },
                      childCount: rooms.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PublicRoomsHorizontalList extends StatelessWidget {
  const PublicRoomsHorizontalList({
    super.key,
    required this.publicRooms,
  });

  final List<PublicRoomsChunk>? publicRooms;

  @override
  Widget build(BuildContext context) {
    final publicRooms = this.publicRooms;
    return AnimatedContainer(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      height: publicRooms == null || publicRooms.isEmpty ? 0 : 106,
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      child: publicRooms == null
          ? null
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: publicRooms.length,
              itemBuilder: (context, i) => _SearchItem(
                title: publicRooms[i].name ??
                    publicRooms[i].canonicalAlias?.localpart ??
                    L10n.of(context)!.group,
                avatar: publicRooms[i].avatarUrl,
                onPressed: () => showAdaptiveBottomSheet(
                  context: context,
                  builder: (c) => PublicRoomBottomSheet(
                    roomAlias:
                        publicRooms[i].canonicalAlias ?? publicRooms[i].roomId,
                    outerContext: context,
                    chunk: publicRooms[i],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SearchItem extends StatelessWidget {
  final String title;
  final Uri? avatar;
  final void Function() onPressed;

  const _SearchItem({
    required this.title,
    this.avatar,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Avatar(
                mxContent: avatar,
                name: title,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
