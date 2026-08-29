import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Pulls a share code out of a pasted link (`…mygymbro.app/s/<code>…`) or a
/// bare code. Returns null when nothing code-shaped is found.
String? extractShareCode(String input) {
  final text = input.trim().toLowerCase();
  final fromLink = RegExp('/s/([a-z0-9]{4,16})').firstMatch(text);
  if (fromLink != null) return fromLink.group(1);
  if (RegExp(r'^[a-z0-9]{4,16}$').hasMatch(text)) return text;
  return null;
}

/// Manual entry for a shared-routine link/code. This is the path that works
/// on every platform TODAY — tapped links can't open the app until the
/// universal-link domain config lands (SETUP-STATUS.md).
Future<void> showImportCodeDialog(BuildContext context) {
  final colors = AppColors.of(context);
  final controller = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      String? errorText;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: colors.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            l10n.importCodeTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: l10n.importCodeHint,
              hintStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.sp,
              ),
              errorText: errorText,
            ),
            onSubmitted: (_) => _submit(ctx, controller.text,
                onInvalid: () =>
                    setState(() => errorText = l10n.importCodeInvalid)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.todayPillText,
              ),
              onPressed: () => _submit(ctx, controller.text,
                  onInvalid: () =>
                      setState(() => errorText = l10n.importCodeInvalid)),
              child: Text(l10n.importCodeOpen),
            ),
          ],
        ),
      );
    },
  );
}

void _submit(
  BuildContext dialogContext,
  String input, {
  required VoidCallback onInvalid,
}) {
  final code = extractShareCode(input);
  if (code == null) {
    onInvalid();
    return;
  }
  Navigator.of(dialogContext).pop();
  dialogContext.push('/s/$code');
}
