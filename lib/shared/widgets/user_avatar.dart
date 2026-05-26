import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Reusable circular avatar with network image + icon fallback.
///
/// Shows a [CachedNetworkImage] when [url] is non-null, otherwise
/// renders a person icon on a filled circle background.
class UserAvatar extends StatelessWidget {

  const UserAvatar({
    required this.size, super.key,
    this.url,
    this.placeholderColor,
    this.iconColor,
  });
  /// Image URL (nullable — shows fallback icon when null).
  final String? url;

  /// Diameter of the avatar in logical pixels (before `.w` scaling).
  final double size;

  /// Background colour of the fallback circle. Defaults to `AppColors.of(context).avatarPlaceholder`.
  final Color? placeholderColor;

  /// Icon and placeholder colour. Defaults to the theme's `onSurface`.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurface;
    final effectiveBgColor = placeholderColor ?? AppColors.of(context).avatarPlaceholder;
    final iconSize = (size * 0.55).sp;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (url != null) {
      return Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: size.w,
            height: size.w,
            fit: BoxFit.cover,
            memCacheWidth: (size.w * dpr).toInt(),
            memCacheHeight: (size.w * dpr).toInt(),
            placeholder: (_, __) => Icon(
              Icons.person_rounded,
              color: effectiveIconColor,
              size: iconSize,
            ),
            errorWidget: (_, __, ___) => Icon(
              Icons.person_rounded,
              color: effectiveIconColor,
              size: iconSize,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        color: effectiveIconColor,
        size: iconSize,
      ),
    );
  }
}
