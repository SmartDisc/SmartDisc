import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

/// Saves export bytes to the app documents directory and shows a snackbar with Open/Share (mobile/desktop).
Future<void> saveExportAndShare(
  List<int> bytes,
  String filename,
  BuildContext context,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, filename));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Row(
        children: [
          const Expanded(child: Text('Export saved.')),
          TextButton(
            onPressed: () => OpenFilex.open(file.path),
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () => Share.shareXFiles(
              [XFile(file.path)],
              text: 'SmartDisc export',
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    ),
  );
}
