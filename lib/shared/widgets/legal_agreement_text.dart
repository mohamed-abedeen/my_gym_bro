import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a legal page ([AppConstants.termsUrl] etc.) in the browser, with a
/// snackbar when it can't.
Future<void> openLegalLink(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on PlatformException {
    launched = false;
  }
  if (!launched) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenLink)));
  }
}

/// "By continuing, you confirm you're at least 16 and agree to our Terms of
/// Use. Our Privacy Policy explains how we handle your data." — both names
/// tappable. Shown wherever an account can be created (sign-up, sign-in).
class LegalAgreementText extends StatefulWidget {
  const LegalAgreementText({
    required this.style,
    required this.linkStyle,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final TextStyle style;

  /// Merged onto [style] for the two link names.
  final TextStyle linkStyle;
  final TextAlign textAlign;

  @override
  State<LegalAgreementText> createState() => _LegalAgreementTextState();
}

class _LegalAgreementTextState extends State<LegalAgreementText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => openLegalLink(context, AppConstants.termsUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => openLegalLink(context, AppConstants.privacyUrl);

  static const _termsSlot = '\u0001';
  static const _privacySlot = '\u0002';

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final link = widget.style.merge(widget.linkStyle);
    // Split the localized sentence around the two link slots, whatever
    // order the language puts them in.
    final template = l10n.legalAgreement(
      AppConstants.minUserAge,
      _termsSlot,
      _privacySlot,
    );
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    for (final char in template.split('')) {
      if (char == _termsSlot || char == _privacySlot) {
        if (buffer.isNotEmpty) spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
        final terms = char == _termsSlot;
        spans.add(
          TextSpan(
            text: terms ? l10n.termsOfUse : l10n.privacyPolicy,
            style: link,
            recognizer: terms ? _terms : _privacy,
          ),
        );
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) spans.add(TextSpan(text: buffer.toString()));

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }
}
