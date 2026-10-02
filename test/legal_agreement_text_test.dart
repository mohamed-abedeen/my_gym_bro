import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:my_gym_bro/shared/widgets/legal_agreement_text.dart';

void main() {
  for (final code in ['en', 'de', 'es', 'fr']) {
    testWidgets('states the minimum age and links Terms + Privacy ($code)',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(Locale(code));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: LegalAgreementText(
              style: TextStyle(),
              linkStyle: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final span = text.textSpan! as TextSpan;
      final plain = span.toPlainText();
      expect(plain, contains('${AppConstants.minUserAge}'));
      expect(plain, contains(l10n.termsOfUse));
      expect(plain, contains(l10n.privacyPolicy));
      // No placeholder sentinels leak into the sentence.
      expect(plain, isNot(contains('\u0001')));
      expect(plain, isNot(contains('\u0002')));

      final links = span.children!
          .whereType<TextSpan>()
          .where((s) => s.recognizer != null)
          .map((s) => s.text)
          .toList();
      expect(links, unorderedEquals([l10n.termsOfUse, l10n.privacyPolicy]));
    });
  }
}
