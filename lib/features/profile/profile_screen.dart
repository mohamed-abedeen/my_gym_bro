import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/community/community_mock_data.dart';
import 'package:my_gym_bro/features/profile/profile_providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/social/follow_providers.dart';
import 'package:my_gym_bro/features/workout/exercise_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';
import 'package:path_provider/path_provider.dart';

/// Enhanced Profile screen — Figma "Profile" design.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider);
    final enrichedSessions = ref.watch(enrichedAllSessionsProvider);
    final streak = ref.watch(streakProvider);
    final gender = ref.watch(userGenderProvider);
    final tabIndex = ref.watch(profileTabProvider);

    final displayName = profile.whenOrNull(data: (p) => p?.displayName) ?? '';
    final avatarUrl = profile.whenOrNull(data: (p) => p?.avatarUrl);
    final bannerUrl = profile.whenOrNull(data: (p) => p?.bannerUrl);
    final streakCount = streak.whenOrNull(data: (s) => s) ?? 0;
    final anatomyGender =
        gender == 'female' ? AnatomyGender.female : AnatomyGender.male;

    return Scaffold(
      backgroundColor: colors.background,
      body: _ProfileBody(
        sessions: enrichedSessions.valueOrNull ?? [],
        sessionsLoading: enrichedSessions.isLoading,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
        streakCount: streakCount,
        anatomyGender: anatomyGender,
        tabIndex: tabIndex,
        l10n: l10n,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile Body — scrollable content
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.sessions,
    required this.sessionsLoading,
    required this.displayName,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.streakCount,
    required this.anatomyGender,
    required this.tabIndex,
    required this.l10n,
  });

  final List<EnrichedSession> sessions;
  final bool sessionsLoading;
  final String displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final int streakCount;
  final AnatomyGender anatomyGender;
  final int tabIndex;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return CustomScrollView(
      slivers: [
        // ── Banner + header overlay ──
        SliverToBoxAdapter(
          child: _BannerSection(
            displayName: displayName,
            avatarUrl: avatarUrl,
            bannerUrl: bannerUrl,
            streakCount: streakCount,
            l10n: l10n,
          ),
        ),

        // ── Tab pills ──
        SliverToBoxAdapter(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 1,
                color: const Color(0xFF252525),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: _TabPills(tabIndex: tabIndex, l10n: l10n),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),

        // ── Tab content ──
        if (tabIndex == 0) ...[
          // Status tab
          if (sessionsLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 80.h),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.w,
                  ),
                ),
              ),
            )
          else if (sessions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 80.h),
                child: Center(
                  child: Text(
                    l10n.noSessionsYet,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ProfileSessionCard(
                  enriched: sessions[index],
                  anatomyGender: anatomyGender,
                  l10n: l10n,
                  initiallyExpanded: index == 0,
                  index: index,
                ),
                childCount: sessions.length,
              ),
            ),
        ] else if (tabIndex == 1) ...[
          // Achievement tab — 3-column grid
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.contentPaddingH.w,
            ),
            sliver: const _AchievementGrid(),
          ),
        ] else ...[
          // Posts tab — user's posts
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ProfilePostCard(
                post: CommunityMockData.posts[index],
                displayName: displayName,
                avatarUrl: avatarUrl,
              ),
              childCount: CommunityMockData.posts.length,
            ),
          ),
        ],

        // Bottom padding for nav pill clearance
        SliverToBoxAdapter(child: SizedBox(height: 120.h)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Banner Section — cover image + gradient + avatar + stats
// ═══════════════════════════════════════════════════════════════════════════

class _BannerSection extends ConsumerStatefulWidget {
  const _BannerSection({
    required this.displayName,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.streakCount,
    required this.l10n,
  });

  final String displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final int streakCount;
  final AppLocalizations l10n;

  @override
  ConsumerState<_BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends ConsumerState<_BannerSection> {
  // Optimistic local path — overrides widget.bannerUrl until DB stream catches up.
  // Cleared once widget.bannerUrl matches so restarts always reflect DB state.
  String? _localBannerPath;

  @override
  void didUpdateWidget(_BannerSection old) {
    super.didUpdateWidget(old);
    if (_localBannerPath != null &&
        widget.bannerUrl == _localBannerPath) {
      // DB stream has caught up — drop optimistic override
      _localBannerPath = null;
    }
  }

  Future<void> _pickBannerImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Use XFile.readAsBytes() — works with both file paths and content URIs
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    // Unique filename per pick so Flutter's image cache never serves stale data
    final docsDir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final destPath = '${docsDir.path}/profile_banner_$ts.$ext';
    await File(destPath).writeAsBytes(bytes);
    if (!mounted) return;

    // Update UI immediately (optimistic), then persist to DB.
    setState(() => _localBannerPath = destPath);

    // Read the profile directly from the DB rather than from the StreamProvider
    // cache — after the async image-picker gap (app backgrounded), the stream
    // provider may still be in a transitional state and valueOrNull returns null,
    // which silently skipped the save and caused the banner to revert on next
    // navigation or restart.
    final dao = ref.read(userProfileDaoProvider);
    final profile = await dao.getFirst();
    if (profile == null) return;
    await dao.updateBannerUrl(profile.localId, destPath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const bannerH = 196.0;
    const avatarSize = 102.0;
    const avatarRingSize = 112.0;
    const avatarTop = 158.0;

    final bannerPath = _localBannerPath ?? widget.bannerUrl;

    return SizedBox(
      height: avatarTop + avatarRingSize + 80.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Banner image ──
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bannerH.h,
            child: bannerPath != null
                ? Image.file(
                    File(bannerPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => _defaultBanner(colors),
                  )
                : _defaultBanner(colors),
          ),

          // ── Minimal top scrim — just enough to keep buttons readable ──
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 72.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Back button ──
          Positioned(
            left: 12.w,
            top: MediaQuery.of(context).padding.top + 8.h,
            child: LiquidGlassButton(
              width: 44.w,
              height: 44.h,
              opacity: 0.15,
              radius: 22.r,
              onTap: () => Navigator.of(context).pop(),
              child: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: 28.sp,
              ),
            ),
          ),

          // ── Display name (top header) ──
          Positioned(
            left: 60.w,
            top: MediaQuery.of(context).padding.top + 18.h,
            child: Text(
              widget.displayName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // ── Menu icon (top right) ──
          Positioned(
            right: 16.w,
            top: MediaQuery.of(context).padding.top + 8.h,
            child: LiquidGlassButton(
              width: 44.w,
              height: 44.h,
              opacity: 0.15,
              radius: 22.r,
              child: Icon(
                Icons.menu_rounded,
                color: colors.textPrimary,
                size: 22.sp,
              ),
            ),
          ),

          // ── Edit banner button ──
          Positioned(
            right: 16.w,
            top: (bannerH - 36).h,
            child: GestureDetector(
              onTap: _pickBannerImage,
              child: Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16.sp,
                ),
              ),
            ),
          ),

          // ── Avatar ring (background circle) ──
          Positioned(
            left: 12.w,
            top: avatarTop.h,
            child: Container(
              width: avatarRingSize.w,
              height: avatarRingSize.w,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: UserAvatar(
                  size: avatarSize,
                  url: widget.avatarUrl,
                ),
              ),
            ),
          ),

          // ── Stats row (Following / Followers / Streak) ──
          Positioned(
            left: 130.w,
            right: 16.w,
            top: (avatarTop + 30).h,
            child: _StatsRow(streakCount: widget.streakCount, l10n: widget.l10n),
          ),
        ],
      ),
    );
  }

  Widget _defaultBanner(AppColorsTheme colors) {
    return Image.asset(
      'assets/images/gym_banner.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.cardElevated,
              colors.accent.withValues(alpha: 0.3),
              colors.cardElevated,
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats Row — Following | Followers | Streak
// ═══════════════════════════════════════════════════════════════════════════

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.streakCount, required this.l10n});

  final int streakCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    // "Following" comes from the local cache so it's instant and offline-safe;
    // "Followers" is authoritative from the server (who follows me), falling
    // back to 0 when offline / pre-fetch.
    final followingCount =
        ref.watch(followingIdsProvider).valueOrNull?.length ?? 0;
    final myProfile = ref.watch(myPublicProfileProvider).valueOrNull;
    final followersCount = myProfile?.followerCount ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatColumn(value: '$followingCount', label: l10n.following),
        Container(
          width: 1,
          height: 22.h,
          color: const Color(0xFF282828),
        ),
        _StatColumn(value: '$followersCount', label: l10n.followers),
        Container(
          width: 1,
          height: 22.h,
          color: const Color(0xFF282828),
        ),
        // Streak with fire icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: colors.amber,
              size: 14.sp,
            ),
            SizedBox(width: 2.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$streakCount',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.streak,
                  style: TextStyle(
                    color: const Color(0xFF8E8E8E),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF8E8E8E),
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab Pills — Status / Achievement / Posts
// ═══════════════════════════════════════════════════════════════════════════

class _TabPills extends ConsumerWidget {
  const _TabPills({required this.tabIndex, required this.l10n});

  final int tabIndex;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final tabs = [l10n.lastSession, l10n.achievement, l10n.posts];

    return Row(
      children: List.generate(tabs.length, (i) {
        final isSelected = tabIndex == i;
        final isLast = i == tabs.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8.w),
            child: GestureDetector(
              onTap: () =>
                  ref.read(profileTabProvider.notifier).state = i,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent
                      : colors.panelBackground,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? colors.background
                        : colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile Session Card — expandable with anatomy + exercises + stats
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileSessionCard extends ConsumerStatefulWidget {
  const _ProfileSessionCard({
    required this.enriched,
    required this.anatomyGender,
    required this.l10n,
    required this.index,
    this.initiallyExpanded = false,
  });

  final EnrichedSession enriched;
  final AnatomyGender anatomyGender;
  final AppLocalizations l10n;
  final int index;
  final bool initiallyExpanded;

  @override
  ConsumerState<_ProfileSessionCard> createState() =>
      _ProfileSessionCardState();
}

class _ProfileSessionCardState extends ConsumerState<_ProfileSessionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _chevronAnim;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.35, curve: Curves.easeIn),
    );
    _chevronAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (expanded == _isExpanded) return;
    _isExpanded = expanded;
    if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    WidgetRef ref,
    int sessionId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          l10n.deleteWorkout,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.deleteWorkoutConfirm,
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(sessionDaoProvider).deleteSession(sessionId);
    ref
      ..invalidate(enrichedAllSessionsProvider)
      ..invalidate(enrichedRecentSessionsProvider)
      ..invalidate(recentSessionsProvider)
      ..invalidate(weeklyStatsProvider)
      ..invalidate(lifetimeStatsProvider)
      ..invalidate(activityStatsProvider)
      ..invalidate(streakProvider)
      ..invalidate(muscleRecoveryProvider)
      ..invalidate(recordsProvider)
      ..invalidate(consecutiveRestDaysProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = widget.enriched.session;
    final durationMin = (s.durationSeconds ?? 0) ~/ 60;
    final durationH = durationMin ~/ 60;
    final durationM = durationMin % 60;
    final durationStr =
        durationH > 0 ? '${durationH}h ${durationM}m' : '${durationM}m';
    final unit = ref.watch(weightUnitProvider);
    final volume = convertFromKg(s.totalVolume ?? 0, unit).round();
    final weightUnit = weightUnitLabel(unit);

    // Listen for provider changes to drive animation — not inside build logic
    ref.listen<int>(profileExpandedSessionProvider, (prev, next) {
      _setExpanded(next == widget.index);
    });

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.contentPaddingH.w,
        vertical: 6.h,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final current = ref.read(profileExpandedSessionProvider);
          ref.read(profileExpandedSessionProvider.notifier).state =
              current == widget.index ? -1 : widget.index;
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _expandAnim.value;
            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  colors.cardElevated,
                  colors.background,
                  t,
                ),
                borderRadius: BorderRadius.circular(25.r),
              ),
              clipBehavior: Clip.hardEdge,
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 16.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _expandAnim,
                            builder: (context, _) {
                              final t = _expandAnim.value;
                              final fontSize =
                                  lerpDouble(20.sp, 24.sp, t)!;
                              return Text(
                                t > 0.5
                                    ? widget.l10n.lastSession
                                    : widget.enriched.workoutName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          SizeTransition(
                            sizeFactor: _expandAnim,
                            axisAlignment: -1,
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  widget.enriched.workoutName,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _chevronAnim,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textPrimary,
                        size: 28.sp,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expandable content ──
              SizeTransition(
                sizeFactor: _expandAnim,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),

                      // ── Anatomy body ──
                      Center(
                        child: AnatomyBody(
                          muscleStates:
                              muscleStatesForSession(widget.enriched),
                          height: 340.h,
                          gender: widget.anatomyGender,
                          basePngPath: ref.watch(activeSkinPathProvider),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // ── Stats grid ──
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.contentPaddingH.w,
                        ),
                        child: _SessionStatsGrid(
                          volume: volume,
                          weightUnit: weightUnit,
                          durationStr: durationStr,
                          exerciseCount:
                              widget.enriched.exercises.length,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // ── Exercise list ──
                      ...widget.enriched.exercises.map((ex) {
                        final timeStr = ex.startedAt != null
                            ? DateFormat('h:mma')
                                .format(ex.startedAt!)
                                .toLowerCase()
                            : '${ex.sets} sets';

                        return GestureDetector(
                          onTap: () => showExerciseDetailSheet(
                            context,
                            exercise: ex,
                            session: widget.enriched.session,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                20.w, 0, 16.w, 12.h),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.exerciseThumb.r,
                                  ),
                                  child: ex.gifUrl != null
                                      ? CachedNetworkImage(
                                          cacheManager: ExerciseGifCache.instance,
                                          imageUrl: ex.gifUrl!,
                                          width: 58.w,
                                          height: 58.h,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              Container(
                                            width: 58.w,
                                            height: 58.h,
                                            color: colors.separator,
                                          ),
                                          errorWidget:
                                              (_, __, ___) =>
                                                  _ExercisePlaceholder(),
                                        )
                                      : _ExercisePlaceholder(),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: colors.textPrimary,
                                  size: 16.sp,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      SizedBox(height: 8.h),

                      // ── Footer ──
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(20.w, 0, 16.w, 16.h),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.l10n.totalVolume} $volume$weightUnit',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${widget.l10n.totalTime} $durationStr',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Delete button
                            LiquidGlassButton(
                              width: 48.w,
                              height: 48.h,
                              opacity: 0.15,
                              radius: 24.r,
                              onTap: () => _confirmDeleteSession(
                                context,
                                ref,
                                widget.enriched.session.localId,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            LiquidGlassButton(
                              width: 48.w,
                              height: 48.h,
                              opacity: 0.15,
                              radius: 24.r,
                              child: Icon(
                                Icons.ios_share_rounded,
                                color: colors.textPrimary,
                                size: 20.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Collapsed date (fades out as content expands) ──
              SizeTransition(
                sizeFactor: ReverseAnimation(_expandAnim),
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: ReverseAnimation(_fadeAnim),
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(20.w, 4.h, 16.w, 16.h),
                    child: Text(
                      DateFormat('d / M / yyyy').format(s.startedAt),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Session Stats Grid — 2x2 layout matching Figma
// Volume / Avg Strength / Total Duration / Records
// ═══════════════════════════════════════════════════════════════════════════

class _SessionStatsGrid extends StatelessWidget {
  const _SessionStatsGrid({
    required this.volume,
    required this.weightUnit,
    required this.durationStr,
    required this.exerciseCount,
  });

  final int volume;
  final String weightUnit;
  final String durationStr;
  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Row 1: Volume + Avg Strength
        Row(
          children: [
            Expanded(
              child: _StatCell(
                label: l10n.volume,
                value: '$volume  $weightUnit',
              ),
            ),
            SizedBox(width: 32.w),
            Expanded(
              child: _StatCell(
                label: l10n.avgStrength,
                value: '${exerciseCount > 0 ? (volume ~/ exerciseCount) : 0}',
                trendValue: '5+',
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // Row 2: Total Duration + Records
        Row(
          children: [
            Expanded(
              child: _StatCell(
                label: l10n.totalDuration,
                value: durationStr,
                trendValue: '120%',
              ),
            ),
            SizedBox(width: 32.w),
            Expanded(
              child: _StatCell(
                label: l10n.records,
                value: '5',
                trendValue: '-2',
                isPositive: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.trendValue,
    this.isPositive = true,
  });

  final String label;
  final String value;
  final String? trendValue;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (trendValue != null) ...[
          Text(
            trendValue!,
            style: TextStyle(
              color: isPositive
                  ? colors.trendPositive
                  : colors.trendNegative,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: 2.w),
          Transform.rotate(
            angle: isPositive
                ? AppAngles.quarterTurnCcw
                : AppAngles.quarterTurnCw,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: isPositive
                  ? colors.trendPositive
                  : colors.trendNegative,
              size: 24.sp,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Achievement Grid — 3-column grid of rounded cards, Figma spec:
// card 115x187, radius 23, bg #1C1C1E, label 11sp bold white centered below
// ═══════════════════════════════════════════════════════════════════════════

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Placeholder count — will be replaced with real achievement data
    const itemCount = 9;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        // Card (187) + gap (8) + label (~16) = ~211 total height per cell
        childAspectRatio: 115 / 211,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Column(
          children: [
            // Achievement card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: colors.panelBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // Label
            Text(
              AppLocalizations.of(context).achievement,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        childCount: itemCount,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile Post Card — Figma Posts tab design
// Author row (avatar + name + menu) → full-width image → interaction bar →
// description text. No comments section in profile view.
// ═══════════════════════════════════════════════════════════════════════════

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.displayName,
    required this.avatarUrl,
  });

  final CommunityPost post;
  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Author row ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
          child: Row(
            children: [
              UserAvatar(size: 35, url: avatarUrl, iconColor: colors.textSecondary),
              SizedBox(width: 6.w),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert_rounded, color: colors.textPrimary, size: 18.sp),
            ],
          ),
        ),

        // ── Post image ──
        Container(
          width: double.infinity,
          height: 297.h,
          color: colors.avatarPlaceholderDarker,
          child: Container(
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
          ),
        ),

        SizedBox(height: 10.h),

        // ── Interaction bar ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: Row(
            children: [
              // Engagement pill (likes + comments + bookmarks)
              _InteractionPill(
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
                      post.likes,
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
              // Share button
              _InteractionPill(
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

        // ── Description ──
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

        SizedBox(height: 20.h),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Interaction Pill — glass-style pill for post engagement bar
// ═══════════════════════════════════════════════════════════════════════════

class _InteractionPill extends StatelessWidget {
  const _InteractionPill({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(296.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.panelBackground,
            borderRadius: BorderRadius.circular(296.r),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Exercise Placeholder (reused from log_bottom_sheet pattern)
// ═══════════════════════════════════════════════════════════════════════════

class _ExercisePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 58.w,
      height: 58.h,
      decoration: BoxDecoration(
        color: colors.separator,
        borderRadius: BorderRadius.circular(AppRadius.exerciseThumb.r),
      ),
      child: Icon(
        Icons.fitness_center_rounded,
        color: colors.textSecondary,
        size: 24.sp,
      ),
    );
  }
}
