import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';

/// Community tab — matches Figma screen 4 (pixel-perfect from CSS).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _showComposer = true;

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

                  // Posts feed
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _PostCard(
                        authorName: 'Aziz Rhuma',
                        likes: '10k',
                        comments: '324',
                        bookmarks: '67',
                        description:
                            'A fundamental compound movement that builds massive lower-body power and functional strength. By mimicking a natural sitting motion, it engages multiple muscle groups simultaneously, boosting metabolism and improving overall athletic performance.',
                        topComments: const [
                          _CommentData(
                            'Omar',
                            'This is insane bro, keep pushing!',
                          ),
                          _CommentData(
                            'Ali',
                            'What weight are you squatting here?',
                          ),
                          _CommentData('Nasser', 'Form looks clean 💪'),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      _PostCard(
                        authorName: 'Omar',
                        likes: '5.2k',
                        comments: '142',
                        bookmarks: '31',
                        description:
                            'Building strength one rep at a time. Consistency is key to unlocking your full potential.',
                        topComments: const [
                          _CommentData('Aziz', 'Let\'s go champ!'),
                          _CommentData(
                            'Khaled',
                            'Consistency is everything 🔥',
                          ),
                          _CommentData(
                            'Yusuf',
                            'Need to train with you sometime',
                          ),
                        ],
                      ),
                      // Bottom padding for composer + nav
                      SizedBox(height: 160.h),
                    ]),
                  ),
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
}

// ═══════════════════════════════════════════════════════════════════
// Header: "Community" + search + notifications + comment + avatar
// ═══════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  const _Header({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 22.w, right: 16.w, top: 6.h, bottom: 0),
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
          SizedBox(width: 14.w),

          // Comment icon (DMs)
          GestureDetector(
            onTap: () {
              // using GoRouter's context.push so shell hides bottom nav
              GoRouter.of(context).push('/dm');
            },
            child: Icon(
              Icons.chat_bubble_outline,
              color: colors.textPrimary,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 16.w),

          // Profile avatar in glass circle — 48x48 per Figma
          LiquidGlassButton(
            width: 48.w,
            height: 48.h,
            opacity: 0.65,
            radius: 296.r,
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(33.r),
              ),
              child: Icon(Icons.person, color: colors.textPrimary, size: 24.sp),
            ),
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
          _FriendStory(index: 0),
          SizedBox(width: 16.w),
          _FriendStory(index: 1),
          SizedBox(width: 16.w),
          _FriendStory(index: 2),
          SizedBox(width: 16.w),
          _FriendStory(index: 3),
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
              color: Colors.grey[800],
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
                  colors: [Color(0xFFD0FF00), Color(0xFF12FF00)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: Colors.black, size: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendStory extends StatelessWidget {
  final int index;
  const _FriendStory({required this.index});

  static const _avatarColors = [
    Color(0xFF4A6741),
    Color(0xFF6B4423),
    Color(0xFF3D5A80),
    Color(0xFF7B6B4F),
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
              colors: [Color(0xFFD2FF00), Color(0xFF0DFF00)],
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
class _PostCard extends StatelessWidget {
  final String authorName;
  final String likes;
  final String comments;
  final String bookmarks;
  final String description;
  final List<_CommentData> topComments;

  const _PostCard({
    required this.authorName,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.description,
    this.topComments = const [],
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 35.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(42.5.r),
                ),
                child: Icon(
                  Icons.person,
                  color: colors.textSecondary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 6.w),
              // Name
              Text(
                authorName,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              // Menu icon (list)
              Icon(Icons.menu_rounded, color: colors.textPrimary, size: 18.sp),
            ],
          ),
        ),

        // Post image placeholder (full-width gym image — 297px per Figma)
        Container(
          width: double.infinity,
          height: 297.h,
          color: Colors.grey[900],
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder gradient simulating gym image
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[850] ?? Colors.grey[900]!,
                      Colors.grey[800]!,
                      Colors.grey[900]!,
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
              ),
            ],
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
                width: 186.w,
                height: 29.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/bicep.png',
                      width: 20.w,
                      height: 20.h,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      likes,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
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
                      comments,
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
                      bookmarks,
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
            description,
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
        if (topComments.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  topComments
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
                                  color: Colors.grey[700],
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

class _CommentData {
  final String name;
  final String text;
  const _CommentData(this.name, this.text);
}

// ═══════════════════════════════════════════════════════════════════
// Bottom composer bar: glass pill with avatar + text + image icon
// ═══════════════════════════════════════════════════════════════════
class _ComposerBar extends StatelessWidget {
  final AppLocalizations l10n;
  const _ComposerBar({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(296.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          height: 48.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(296.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 35.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(42.5.r),
                ),
                child: Icon(
                  Icons.person,
                  color: colors.textSecondary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 5.w),
              // Text
              Text(
                l10n.whatOnYourMind,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              // Image icon
              Icon(
                Icons.image_outlined,
                color: colors.textPrimary,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Frosted glass pill — backdrop blur for interaction buttons
// ═══════════════════════════════════════════════════════════════════
class _GlassPill extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _GlassPill({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(296.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(296.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
