import 'package:flutter/material.dart';
import '../styles/app_font.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history, size: 72),
            SizedBox(height: 12),
            Text('History', style: AppFont.headline),
            SizedBox(height: 8),
            Text('Past throws and sessions are shown here.'),
          ],
        ),
      ),
    );
  }
}
