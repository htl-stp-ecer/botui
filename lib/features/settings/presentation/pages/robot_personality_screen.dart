import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/utils/colors/device_color_generator.dart';
import 'package:stpvelox/core/utils/colors/robot_color_scheme.dart';
import 'package:stpvelox/core/utils/robot_personality.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/presentation/screens/robot_face/robot_face_animation_manager.dart';
import 'package:stpvelox/presentation/screens/robot_face/robot_face_painter.dart';

class RobotPersonalityScreen extends ConsumerStatefulWidget {
  const RobotPersonalityScreen({super.key});

  @override
  ConsumerState<RobotPersonalityScreen> createState() =>
      _RobotPersonalityScreenState();
}

class _RobotPersonalityScreenState extends ConsumerState<RobotPersonalityScreen>
    with TickerProviderStateMixin {
  late final RobotFaceAnimationManager _animationManager;
  bool _personalityApplied = false;

  @override
  void initState() {
    super.initState();
    _animationManager = RobotFaceAnimationManager(vsync: this);
    _animationManager.startAnimations();
  }

  @override
  void dispose() {
    _animationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personalityAsync = ref.watch(robotPersonalityProvider);
    final colorSchemeAsync = ref.watch(robotColorSchemeProvider);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Personality'),
      body: SafeArea(
        child: personalityAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
          data: (personality) => colorSchemeAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
            data: (colorScheme) {
              if (!_personalityApplied) {
                _animationManager.expressionStateManager
                    .setPersonality(personality);
                _personalityApplied = true;
              }
              return _buildContent(personality, colorScheme);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    RobotPersonality personality,
    RobotColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _buildPreview(personality, colorScheme),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: _buildDetails(personality, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(
    RobotPersonality personality,
    RobotColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _animationManager.blinkAnimation,
          _animationManager.gazeAnimation,
        ]),
        builder: (context, _) {
          return CustomPaint(
            painter: RobotFacePainter(
              blinkValue: _animationManager.blinkAnimation.value,
              gazeOffset: _animationManager.gazeAnimation.value,
              stateManager: _animationManager.expressionStateManager,
              colorScheme: colorScheme,
              personality: personality,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  Widget _buildDetails(
    RobotPersonality personality,
    RobotColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTraitHeader(personality, colorScheme),
            const SizedBox(height: 16),
            _buildRow(
              Icons.remove_red_eye,
              'Eye shape',
              _eyeShapeLabel(personality.eyeShape),
              colorScheme.eyeColor,
            ),
            _buildRow(
              Icons.adjust,
              'Pupil style',
              _pupilStyleLabel(personality.pupilStyle),
              colorScheme.eyeAccentColor,
            ),
            _buildRow(
              Icons.horizontal_rule,
              'Eyebrows',
              _eyebrowStyleLabel(personality.eyebrowStyle),
              colorScheme.eyebrowColor,
            ),
            _buildRow(
              Icons.aspect_ratio,
              'Eye size',
              'W ${personality.eyeWidthFactor.toStringAsFixed(2)}x · '
                  'H ${personality.eyeHeightFactor.toStringAsFixed(2)}x',
              Colors.white70,
            ),
            _buildRow(
              Icons.auto_awesome,
              'Cosmetics',
              personality.cosmetics.isEmpty
                  ? 'None'
                  : personality.cosmetics
                      .map(_cosmeticLabel)
                      .join(', '),
              colorScheme.effectColor,
            ),
            _buildRow(
              Icons.palette,
              'Palette',
              '${colorScheme.paletteName} · ${colorScheme.variantName}',
              colorScheme.eyeColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitHeader(
    RobotPersonality personality,
    RobotColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.eyeColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.eyeColor, width: 2),
          ),
          child: Icon(
            _traitIcon(personality.trait),
            color: colorScheme.eyeColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _traitLabel(personality.trait),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _traitDescription(personality.trait),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(IconData icon, String label, String value, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _traitLabel(PersonalityTrait trait) {
    switch (trait) {
      case PersonalityTrait.cheerful:
        return 'Cheerful';
      case PersonalityTrait.grumpy:
        return 'Grumpy';
      case PersonalityTrait.sleepy:
        return 'Sleepy';
      case PersonalityTrait.nervous:
        return 'Nervous';
      case PersonalityTrait.chill:
        return 'Chill';
      case PersonalityTrait.dramatic:
        return 'Dramatic';
      case PersonalityTrait.brainy:
        return 'Brainy';
      case PersonalityTrait.playful:
        return 'Playful';
    }
  }

  String _traitDescription(PersonalityTrait trait) {
    switch (trait) {
      case PersonalityTrait.cheerful:
        return 'Happy, excited, lots of love.';
      case PersonalityTrait.grumpy:
        return 'Angry, annoyed, skeptical.';
      case PersonalityTrait.sleepy:
        return 'Tired, neutral, rarely excited.';
      case PersonalityTrait.nervous:
        return 'Surprised, confused, dizzy.';
      case PersonalityTrait.chill:
        return 'Neutral, curious, mischievous.';
      case PersonalityTrait.dramatic:
        return 'Big feelings: surprised, sad, in love.';
      case PersonalityTrait.brainy:
        return 'Focused, curious, skeptical.';
      case PersonalityTrait.playful:
        return 'Mischievous, excited, loving.';
    }
  }

  IconData _traitIcon(PersonalityTrait trait) {
    switch (trait) {
      case PersonalityTrait.cheerful:
        return Icons.sentiment_very_satisfied;
      case PersonalityTrait.grumpy:
        return Icons.sentiment_very_dissatisfied;
      case PersonalityTrait.sleepy:
        return Icons.bedtime;
      case PersonalityTrait.nervous:
        return Icons.sentiment_dissatisfied;
      case PersonalityTrait.chill:
        return Icons.sentiment_neutral;
      case PersonalityTrait.dramatic:
        return Icons.theater_comedy;
      case PersonalityTrait.brainy:
        return Icons.psychology;
      case PersonalityTrait.playful:
        return Icons.celebration;
    }
  }

  String _eyeShapeLabel(EyeShape shape) {
    switch (shape) {
      case EyeShape.rounded:
        return 'Rounded';
      case EyeShape.standard:
        return 'Standard';
      case EyeShape.angular:
        return 'Angular';
      case EyeShape.pill:
        return 'Pill';
      case EyeShape.blocky:
        return 'Blocky';
    }
  }

  String _pupilStyleLabel(PupilStyle style) {
    switch (style) {
      case PupilStyle.tallRect:
        return 'Tall rectangle';
      case PupilStyle.circle:
        return 'Circle';
      case PupilStyle.diamond:
        return 'Diamond';
      case PupilStyle.horizontalBar:
        return 'Horizontal bar';
      case PupilStyle.cross:
        return 'Cross';
      case PupilStyle.solid:
        return 'Solid';
    }
  }

  String _eyebrowStyleLabel(EyebrowStyle style) {
    switch (style) {
      case EyebrowStyle.standard:
        return 'Standard';
      case EyebrowStyle.curved:
        return 'Curved';
      case EyebrowStyle.thin:
        return 'Thin';
      case EyebrowStyle.thick:
        return 'Thick';
      case EyebrowStyle.split:
        return 'Split';
      case EyebrowStyle.notched:
        return 'Notched';
    }
  }

  String _cosmeticLabel(Cosmetic cosmetic) {
    switch (cosmetic) {
      case Cosmetic.antenna:
        return 'Antenna';
      case Cosmetic.scar:
        return 'Scar';
      case Cosmetic.freckles:
        return 'Freckles';
      case Cosmetic.blush:
        return 'Blush';
      case Cosmetic.circuitLines:
        return 'Circuit lines';
      case Cosmetic.earNodes:
        return 'Ear nodes';
      case Cosmetic.crownDots:
        return 'Crown dots';
      case Cosmetic.chinMark:
        return 'Chin mark';
    }
  }
}
