import 'package:flutter/material.dart';
import 'highscore_popup.dart';

/// Helper to show highscore popup overlay
/// 
/// Example usage after creating a throw:
/// ```dart
/// final result = await apiService.createThrow(...);
/// if (result['is_new_record'] == true && result['record_type'] != null) {
///   showHighscorePopup(context, result['record_type'] as String);
/// }
/// ```
void showHighscorePopup(BuildContext context, String recordType) {
  final overlay = Overlay.of(context);
  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => HighscorePopup(
      recordType: recordType,
      onDismiss: () => overlayEntry.remove(),
    ),
  );
  overlay.insert(overlayEntry);
}

