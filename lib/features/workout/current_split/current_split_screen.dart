import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          child: IconButton(
            key: const Key('current_split_back_button'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
    );
  }
}
