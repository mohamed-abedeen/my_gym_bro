import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';
import '../../../shared/widgets/oc_glass_btn.dart';
import 'dm_models.dart';
import 'dm_providers.dart';
import 'widgets/dm_bubble.dart';
import 'widgets/schedule_share_sheet.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  final DmConversation conversation;

  const DmChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  RealtimeChannel? _realtimeChannel;
  SupabaseClient? _supabaseClient;

  @override
  void initState() {
    super.initState();
    // Initial fetch + subscribe to Realtime for new inbound messages
    Future.microtask(() {
      final repo = ref.read(dmRepositoryProvider);
      if (repo != null) {
        _supabaseClient = repo.supabase;
        repo.fetchMessages(widget.conversation.id);
        _realtimeChannel = repo.subscribeMessages(widget.conversation.id);
      }
    });
  }

  @override
  void dispose() {
    // Clean up Realtime subscription to prevent leaks
    if (_realtimeChannel != null && _supabaseClient != null) {
      _supabaseClient!.removeChannel(_realtimeChannel!);
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _scrollToBottomAfterFrame();

    try {
      await ref.read(dmRepositoryProvider)?.sendTextMessage(
            widget.conversation.id,
            text,
          );
    } catch (_) {
      if (mounted) _showSendError();
    }
  }

  void _scrollToBottomAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    // Close the attachment sheet first so the camera/gallery opens cleanly
    if (mounted) Navigator.of(context).pop();

    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 80,
    );
    if (xFile == null) return;

    _scrollToBottomAfterFrame();
    try {
      await ref.read(dmRepositoryProvider)?.sendImageMessage(
            widget.conversation.id,
            File(xFile.path),
          );
    } catch (_) {
      if (mounted) _showSendError();
    }
  }

  void _showAttachmentSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: colors.panelBackground.withValues(alpha: 0.92),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Action row — icon circles instead of plain list tiles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AttachOption(
                        icon: Icons.camera_alt_rounded,
                        label: AppLocalizations.of(context).dmCamera,
                        color: colors.accent,
                        onTap: () => _pickAndSendImage(ImageSource.camera),
                      ),
                      _AttachOption(
                        icon: Icons.photo_library_rounded,
                        label: AppLocalizations.of(context).dmGallery,
                        color: colors.success,
                        onTap: () => _pickAndSendImage(ImageSource.gallery),
                      ),
                      _AttachOption(
                        icon: Icons.fitness_center_rounded,
                        label: AppLocalizations.of(context).dmSchedule,
                        color: colors.amber,
                        onTap: () {
                          Navigator.of(context).pop();
                          showScheduleShareSheet(
                            context,
                            onShare: (id, name, days) async {
                              _scrollToBottomAfterFrame();
                              try {
                                await ref
                                    .read(dmRepositoryProvider)
                                    ?.sendScheduleMessage(
                                      widget.conversation.id,
                                      name,
                                      days
                                          .asMap()
                                          .entries
                                          .map((e) => SharedScheduleDay(
                                                dayIndex: e.key,
                                                label: e.value == 'Rest'
                                                    ? null
                                                    : e.value,
                                                isRestDay: e.value == 'Rest',
                                              ))
                                          .toList(),
                                    );
                              } catch (_) {
                                if (mounted) _showSendError();
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSendError() {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).dmSendFailed),
        backgroundColor: colors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final messagesAsync =
        ref.watch(dmMessagesProvider(widget.conversation.id));

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Safe-area top spacer
          SizedBox(height: MediaQuery.of(context).padding.top),

          _ChatHeader(conversation: widget.conversation),

          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChatState(
                    name: widget.conversation.otherUserName,
                  );
                }

                // DAO returns ASC (oldest first).
                // ListView(reverse: true) renders index 0 at the bottom,
                // so feed the list as-is — index 0 = oldest at bottom.
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 16.h,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // In reverse mode: index 0 = last item in list (newest)
                    final msg = messages[messages.length - 1 - index];
                    final showTime = _shouldShowTimestamp(
                      messages,
                      messages.length - 1 - index,
                    );

                    return Column(
                      children: [
                        if (showTime)
                          _TimestampLabel(time: msg.createdAt),
                        DmBubble(
                          message: msg,
                          onSaveSchedule: msg.isMine
                              ? null
                              : () => _handleSaveSchedule(msg),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    'Failed to load messages.\n$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Input bar
          _ChatInputBar(
            controller: _textController,
            onSend: _sendMessage,
            onAttach: _showAttachmentSheet,
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  /// Whether to show a date/time divider above this message.
  bool _shouldShowTimestamp(List<DmMessage> messages, int index) {
    if (index == 0) return true; // oldest message always gets a stamp
    final prev = messages[index - 1];
    final current = messages[index];
    return current.createdAt.difference(prev.createdAt).inMinutes > 5;
  }

  Future<void> _handleSaveSchedule(DmMessage msg) async {
    final repo = ref.read(dmRepositoryProvider);
    final sched = msg.sharedSchedule;
    if (repo == null || sched == null) return;

    await repo.saveReceivedSchedule(sched);
    if (mounted) {
      final colors = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).dmSavedToSchedules),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAT HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _ChatHeader extends ConsumerWidget {
  final DmConversation conversation;

  const _ChatHeader({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.separator.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              ref.read(activeDmConversationProvider.notifier).state = null;
              context.pop();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 20.sp,
              ),
            ),
          ),

          SizedBox(width: 4.w),

          // Avatar — cached, 44×44
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: colors.panelBackground,
              shape: BoxShape.circle,
            ),
            child: conversation.otherAvatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: conversation.otherAvatarUrl!,
                      width: 44.w,
                      height: 44.w,
                      fit: BoxFit.cover,
                      memCacheWidth: (44.w * dpr).toInt(),
                      memCacheHeight: (44.w * dpr).toInt(),
                      placeholder: (_, __) => Icon(
                        Icons.person_rounded,
                        color: colors.textSecondary,
                        size: 22.sp,
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        color: colors.textSecondary,
                        size: 22.sp,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    color: colors.textSecondary,
                    size: 22.sp,
                  ),
          ),

          SizedBox(width: 12.w),

          // Name
          Expanded(
            child: Text(
              conversation.otherUserName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Share — liquid glass
          OcGlassBtn(
            type: OcGlassBtnType.share,
            size: 40,
            onTap: () {
              // Future: share conversation
            },
          ),
          SizedBox(width: 8.w),
          // Delete — liquid glass (red-tinted)
          OcGlassBtn(
            type: OcGlassBtnType.delete,
            size: 40,
            onTap: () {
              // Future: delete conversation
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMESTAMP LABEL
// ═══════════════════════════════════════════════════════════════════════════

class _TimestampLabel extends StatelessWidget {
  final DateTime time;

  const _TimestampLabel({required this.time});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(time.year, time.month, time.day);
    final daysDiff = today.difference(msgDay).inDays;

    String label;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');

    if (daysDiff == 0) {
      label = 'Today $h:$m';
    } else if (daysDiff == 1) {
      label = 'Yesterday $h:$m';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      label = '${time.day} ${months[time.month - 1]}, $h:$m';
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: colors.cardElevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY CHAT STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyChatState extends StatelessWidget {
  final String name;

  const _EmptyChatState({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: colors.accent,
                size: 32.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              AppLocalizations.of(context).dmStartConversation(name),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 15.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAT INPUT BAR
// ═══════════════════════════════════════════════════════════════════════════

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          top: BorderSide(
            color: colors.separator.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Attach button
          GestureDetector(
            onTap: onAttach,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: colors.cardElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: colors.textPrimary,
                size: 22.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // Text field — glass-style
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: 44.h, maxHeight: 120.h),
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: colors.separator.withValues(alpha: 0.3),
                ),
              ),
              padding: EdgeInsets.only(left: 16.w, right: 4.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: AppLocalizations.of(context).dmMessageHint,
                        hintStyle: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ),
                  // Send button — animated color
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText ? onSend : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: hasText
                                ? colors.accent
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: hasText
                                ? Colors.black
                                : colors.textSecondary,
                            size: 20.sp,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ATTACHMENT OPTION (used in the bottom-sheet grid)
// ═══════════════════════════════════════════════════════════════════════════

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
