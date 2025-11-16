import 'package:flutter/material.dart';
import '../styles/app_font.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.analytics, size: 72),
            SizedBox(height: 12),
            Text('Analysis', style: AppFont.headline),
            SizedBox(height: 8),
            Text('Detailed analytics and charts will appear here.'),
          ],
        ),
      ),
    );
  }
}
