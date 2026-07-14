import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/community/community_models.dart';
import 'package:my_gym_bro/features/community/community_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';

/// Community tab — matches Figma screen 4 (pixel-perfect from CSS).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _showComposer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showComposer = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Scrollable feed ──
            NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                final direction = notification.direction;
                if (direction == ScrollDirection.reverse && _showComposer) {
                  setState(() => _showComposer = false);
                } else if (direction == ScrollDirection.forward &&
                    !_showComposer) {
                  setState(() => _showComposer = true);
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(child: _Header(l10n: l10n)),

                  // Stories row
                  const SliverToBoxAdapter(child: _StoriesRow()),

                  // Posts feed — real Supabase data (mock when offline).
                  ..._buildFeedSlivers(ref, l10n, colors),
                ],
              ),
            ),

            // ── Bottom composer bar — hides on scroll down, shows on scroll up ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: 21.w,
              right: 21.w,
              bottom: _showComposer ? 90.h : -60.h,
              child: _ComposerBar(l10n: l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the feed slivers from [communityFeedProvider], handling
  /// loading / error / empty states. Always pads the bottom for the composer.
  List<Widget> _buildFeedSlivers(
    WidgetRef ref,
    AppLocalizations l10n,
    AppColorsTheme colors,
  ) {
    Widget centered(Widget child) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 60.h),
            child: Center(child: child),
          ),
        );
    final bottomPad = SliverToBoxAdapter(child: SizedBox(height: 160.h));

    return ref.watch(communityFeedProvider).when(
          loading: () => [
            centered(CircularProgressIndicator(color: colors.accent)),
            bottomPad,
          ],
          error: (_, __) => [
            centered(Text(
              l10n.communityError,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
            )),
            bottomPad,
          ],
          data: (posts) {
            if (posts.isEmpty) {
              return [
                centered(Text(
                  l10n.communityEmpty,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 13.sp),
                )),
                bottomPad,
              ];
            }
            return [
              SliverList(
                delegate: SliverChildListDelegate([
                  ...posts.expand(
                    (post) => [_PostCard(post: post), SizedBox(height: 8.h)],
                  ),
                  SizedBox(height: 160.h),
                ]),
              ),
            ];
          },
        );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header: "Community" + search + notifications + comment + avatar
// ═══════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 22.w, right: 16.w, top: 6.h),
      child: Row(
        children: [
          // Title — expanded to push icons to the right
          Expanded(
            child: Text(
              l10n.tabCommunity,
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Search icon
          Icon(Icons.search, color: colors.textPrimary, size: 24.sp),
          SizedBox(width: 14.w),

          // Notifications icon
          Icon(
            Icons.notifications_outlined,
            color: colors.textPrimary,
            size: 24.sp,
          ),
          SizedBox(width: 16.w),

          // Profile avatar in glass circle — 48x48 per Figma
          LiquidGlassButton(
            width: 48.w,
            height: 48.h,
            opacity: 0.65,
            radius: 296.r,
            onTap: () => GoRouter.of(context).push('/profile'),
            child: UserAvatar(size: 44, iconColor: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stories row: own avatar + friend story circles with green ring
// ═══════════════════════════════════════════════════════════════════
class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 22.w, right: 22.w, top: 12.h),
        children: [
          // Own avatar with + button
          _OwnStoryAvatar(),
          SizedBox(width: 16.w),
          // Friend stories with green gradient ring
          const _FriendStory(index: 0),
          SizedBox(width: 16.w),
          const _FriendStory(index: 1),
          SizedBox(width: 16.w),
          const _FriendStory(index: 2),
          SizedBox(width: 16.w),
          const _FriendStory(index: 3),
        ],
      ),
    );
  }
}

class _OwnStoryAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 85.w,
      height: 100.h,
      child: Stack(
        children: [
          // Avatar
          Container(
            width: 85.w,
            height: 85.h,
            decoration: BoxDecoration(
              color: colors.avatarPlaceholderDark,
              borderRadius: BorderRadius.circular(42.5.r),
            ),
            child: Icon(Icons.person, color: colors.textSecondary, size: 40.sp),
          ),
          // Green + button
          Positioned(
            right: 0,
            bottom: 10.h,
            child: Container(
              width: 22.w,
              height: 22.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.storyRingStart, AppColors.storyRingEnd],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: AppColors.of(context).black, size: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendStory extends StatelessWidget {
  const _FriendStory({required this.index});
  final int index;

  static const _avatarColors = [
    AppColors.categoryGreen,
    AppColors.categoryBrown,
    AppColors.categoryBlue,
    AppColors.categoryTan,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 93.w,
      height: 100.h,
      child: Center(
        child: Container(
          width: 93.w,
          height: 93.h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.storyRingAltStart, AppColors.storyRingAltEnd],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 89.w,
              height: 89.h,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 85.w,
                  height: 85.h,
                  decoration: BoxDecoration(
                    color: _avatarColors[index % _avatarColors.length],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: colors.textSecondary,
                    size: 36.sp,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Post card: author row + image + interaction bar + description
// ═══════════════════════════════════════════════════════════════════
class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
          child: Row(
            children: [
              // Avatar
              UserAvatar(size: 35, iconColor: colors.textSecondary),
              SizedBox(width: 6.w),
              // Name
              Flexible(
                child: Text(
                  post.authorName,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // Menu icon (list)
              Icon(Icons.menu_rounded, color: colors.textPrimary, size: 18.sp),
            ],
          ),
        ),

        // Post image — the post's photo when present, else a placeholder.
        SizedBox(
          width: double.infinity,
          height: 297.h,
          child: post.imageUrl == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.avatarPlaceholderDarker,
                        colors.avatarPlaceholderDark,
                        colors.avatarPlaceholderDarker,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fitness_center,
                      color: colors.textSecondary,
                      size: 48.sp,
                    ),
                  ),
                )
              : post.imageUrl!.startsWith('assets/')
                  ? Image.asset(post.imageUrl!, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: colors.avatarPlaceholderDarker),
                      errorWidget: (_, __, ___) =>
                          ColoredBox(color: colors.avatarPlaceholderDarker),
                    ),
        ),

        SizedBox(height: 10.h),

        // Interaction bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: Row(
            children: [
              // Glassy pill with likes + comments + bookmarks
              _GlassPill(
                height: 29.h,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like toggle (bicep + count)
                    GestureDetector(
                      onTap: post.id.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(communityRepositoryProvider)
                                  .toggleLike(post.id,
                                      currentlyLiked: post.likedByMe);
                              ref.invalidate(communityFeedProvider);
                            },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/bicep.png',
                            width: 20.w,
                            height: 20.h,
                            color: post.likedByMe ? colors.accent : null,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            post.likes,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: colors.textPrimary,
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      post.comments,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Icon(
                      Icons.bookmark_border_rounded,
                      color: colors.textPrimary,
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      post.bookmarks,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Glassy share button
              _GlassPill(
                width: 30.w,
                height: 29.h,
                child: Icon(
                  Icons.send_rounded,
                  color: colors.textPrimary,
                  size: 14.sp,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),

        // Description
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            post.description,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: colors.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Top comments preview
        if (post.topComments.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  post.topComments
                      .map(
                        (c) => Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Commenter avatar
                              Container(
                                width: 22.w,
                                height: 22.h,
                                decoration: BoxDecoration(
                                  color: colors.avatarPlaceholder,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: colors.textSecondary,
                                  size: 12.sp,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${c.name}  ',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: c.text,
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w400,
                                          color: colors.subtitleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],

        SizedBox(height: 8.h),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom composer bar: frosted glass pill — same aesthetic as nav
// ═══════════════════════════════════════════════════════════════════
class _ComposerBar extends ConsumerWidget {
  const _ComposerBar({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillH = 52.h;
    final pillR = 296.r;

    return GestureDetector(
      onTap: () => _showComposeSheet(context, ref),
      child: SizedBox(
        width: double.infinity,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Frosted glass pill shell ──
            GlassSurface(
              width: double.infinity,
              height: pillH,
              radius: pillR,
              tint: isDark
                  ? colors.white.withValues(alpha: 0.08)
                  : colors.white.withValues(alpha: 0.55),
              shadow: BoxShadow(
                color: colors.black.withValues(alpha: isDark ? 0.30 : 0.15),
                blurRadius: 28.w,
                offset: Offset(0, 10.h),
              ),
              child: const SizedBox.expand(),
            ),

            // ── Content row ──
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Row(
                  children: [
                    // Avatar
                    UserAvatar(size: 35, iconColor: colors.textSecondary),
                    SizedBox(width: 8.w),
                    // Placeholder text
                    Text(
                      l10n.whatOnYourMind,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    // Image icon
                    Icon(
                      Icons.image_outlined,
                      color: colors.textPrimary,
                      size: 18.sp,
                    ),
                    SizedBox(width: 4.w),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComposeSheet(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.h,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  UserAvatar(size: 36, iconColor: colors.textSecondary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.whatOnYourMind,
                        hintStyle: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: colors.textSecondary,
                    size: 24.sp,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      Navigator.of(ctx).pop();
                      if (text.isEmpty) return;
                      await ref
                          .read(communityRepositoryProvider)
                          .createPost(content: text);
                      // Refresh the feed so the new post appears immediately.
                      ref.invalidate(communityFeedProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.storyRingEnd,
                      foregroundColor: colors.black,
                      shape: const StadiumBorder(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 10.h,
                      ),
                    ),
                    child: Text(
                      l10n.post,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Frosted glass pill — backdrop blur for interaction buttons
// ═══════════════════════════════════════════════════════════════════
class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.height, required this.child, this.width,
  });
  final double? width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(296.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          height: height,
          padding: width == null
              ? EdgeInsets.symmetric(horizontal: 12.w)
              : null,
          decoration: BoxDecoration(
            color: AppColors.of(context).white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(296.r),
            border: Border.all(
              color: AppColors.of(context).white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
