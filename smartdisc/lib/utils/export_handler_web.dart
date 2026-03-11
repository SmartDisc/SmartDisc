import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Triggers a browser download of the export file (web).
Future<void> saveExportAndShare(
  List<int> bytes,
  String filename,
  BuildContext context,
) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Download started: $filename'),
    ),
  );
}
