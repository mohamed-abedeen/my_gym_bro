import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

class CurrentSplitScreen extends ConsumerWidget {
  const CurrentSplitScreen({
    required this.scheduleId,
    required this.onBack,
    super.key,
  });

  final int scheduleId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SizedBox.expand(
        key: const Key('current_split_screen'),
        child: Align(
          alignment: Alignment.topLeft,
          child: Semantics(
            key: const Key('current_split_back_button'),
            button: true,
            label: AppLocalizations.of(context).back,
            onTap: onBack,
            excludeSemantics: true,
            child: IconButton(
              onPressed: onBack,
              tooltip: AppLocalizations.of(context).back,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
