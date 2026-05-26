import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/community/dm/dm_mock_data.dart';
import 'package:my_gym_bro/features/community/dm/dm_models.dart';
import 'package:my_gym_bro/features/community/dm/dm_providers.dart';
import 'package:my_gym_bro/features/community/dm/widgets/dm_conversation_tile.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_card.dart';

class DmInboxScreen extends ConsumerWidget {
  const DmInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    // TODO(dev): flip to false before shipping
    const kUseMockDm = true;
    final AsyncValue<List<DmConversation>> convosAsync = kUseMockDm
        ? AsyncValue.data(mockDmConversations)
        : ref.watch(dmConversationsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            SizedBox(height: 10.h),
            _SearchBar(),
            SizedBox(height: 16.h),
            Expanded(
              child: convosAsync.when(
                data: (convos) {
                  if (convos.isEmpty) {
                    return _EmptyState();
                  }
                  return ListView.separated(
                    itemCount: convos.length,
                    separatorBuilder:
                        (context, index) => Divider(
                          color: colors.separator,
                          height: 1,
                          indent: 94.w,
                          endIndent: 22.w,
                        ),
                    itemBuilder: (context, index) {
                      final convo = convos[index];
                      return DmConversationTile(
                        conversation: convo,
                        onTap: () {
                          ref
                              .read(activeDmConversationProvider.notifier)
                              .state = convo.id;
                          context.push(
                            AppRoutes.dmChat.replaceAll(
                              ':conversationId',
                              convo.id,
                            ),
                            extra: convo,
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, st) => Center(
                      child: Text(
                        'Error: $e',
                        style: TextStyle(color: colors.danger),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: 24.sp,
            ),
            onPressed: () => context.pop(),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              AppLocalizations.of(context).dmMessages,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 28.sp,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.edit_square,
              color: colors.textPrimary,
              size: 24.sp,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context).dmNewConversationUnavailable,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 44.h,
            decoration: BoxDecoration(
              color: AppColors.of(context).white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.of(context).white.withValues(alpha: 0.05)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(Icons.search, color: colors.textSecondary, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).dmSearch,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                    ),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: GlassCard(
          borderRadius: 24.r,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: colors.textSecondary,
                  size: 48.sp,
                ),
                SizedBox(height: 16.h),
                Text(
                  AppLocalizations.of(context).dmNoMessagesYet,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  AppLocalizations.of(context).dmStartChatting,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14.sp,
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
