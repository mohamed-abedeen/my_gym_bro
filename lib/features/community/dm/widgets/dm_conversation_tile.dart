import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/constants.dart';
import '../../../../shared/responsive.dart';
import '../dm_models.dart';

class DmConversationTile extends StatelessWidget {
  final DmConversation conversation;
  final VoidCallback onTap;

  const DmConversationTile({super.key, required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 58.w,
              height: 58.h,
              decoration: BoxDecoration(
                color: colors.panelBackground,
                shape: BoxShape.circle,
              ),
              child: conversation.otherAvatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        conversation.otherAvatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _FallbackAvatar(colors: colors),
                      ),
                    )
                  : _FallbackAvatar(colors: colors),
            ),
            SizedBox(width: 14.w),
            // Middle text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.otherUserName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    conversation.lastMessageText ?? AppLocalizations.of(context).dmSentMessage,
                    style: TextStyle(
                      color: hasUnread ? colors.textPrimary : colors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            // Right column (timestamp + unread dot)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    _formatTime(context, conversation.lastMessageAt!),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                SizedBox(height: 6.h),
                if (hasUnread)
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(time.year, time.month, time.day);
    
    if (msgDay == today) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    
    final daysDiff = today.difference(msgDay).inDays;
    if (daysDiff == 1) return AppLocalizations.of(context).yesterday;
    if (daysDiff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}

class _FallbackAvatar extends StatelessWidget {
  final AppColorsTheme colors;
  const _FallbackAvatar({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.person, color: colors.textSecondary, size: 28.sp);
  }
}
