import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class HighscorePopup extends StatefulWidget {
  final String recordType;
  final VoidCallback onDismiss;

  const HighscorePopup({
    super.key,
    required this.recordType,
    required this.onDismiss,
  });

  @override
  State<HighscorePopup> createState() => _HighscorePopupState();
}

class _HighscorePopupState extends State<HighscorePopup>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // 3 Sekunden total
    );

    // Scale: schnell hochkommen (erste 300ms)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.1, curve: Curves.elasticOut),
      ),
    );
    
    // Opacity: bleibt bei 1.0 für 2.5 Sekunden, dann langsam verschwinden
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.83, 1.0, curve: Curves.easeOut), // Letzte 0.5 Sekunden fade out
      ),
    );

    _animationController.forward();
    _confettiController.play();

    // Nach 3 Sekunden dismiss
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getRecordLabel() {
    switch (widget.recordType) {
      case 'rotation':
        return 'Rotation';
      case 'hoehe':
        return 'Höhe';
      case 'acceleration':
        return 'Beschleunigung';
      default:
        return 'Highscore';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 1.57, // Up
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
          ),
        ),
        // Popup
        Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 64,
                            color: AppColors.bluePrimary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'HIGHSCORE!',
                            style: AppFont.headline.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Neuer Rekord: ${_getRecordLabel()}',
                            style: AppFont.subheadline.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

