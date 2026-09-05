import 'dart:math' as math;

import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/shared/widgets/primary_button.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Branded intro shown on cold start before handing off to onboarding
/// (signed out) or the home shell (signed in), via a "Get Started" tap.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _actionFade;
  late final Animation<Offset> _actionSlide;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _brandFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _brandSlide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_brandFade);
    _actionFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _actionSlide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_actionFade);
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final isSignedIn = sl<AuthStore>().isSignedIn;
    context.go(isSignedIn ? '/home' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _GlowField(color: colors.accentSoft)),
          Positioned.fill(child: _CornerFrame(color: colors.sep)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PaperPlane(
                            glowColor: colors.accentSoft,
                            planeColor: colors.accent,
                          ),
                          const SizedBox(height: 32),
                          FadeTransition(
                            opacity: _brandFade,
                            child: SlideTransition(
                              position: _brandSlide,
                              child: _BrandBlock(colors: colors),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _actionFade,
                    child: SlideTransition(
                      position: _actionSlide,
                      child: PrimaryButton(
                        label: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _goNext,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FooterLabel(colors: colors),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slowly drifting, softly glowing gradient blobs standing in for the
/// original WebGL shader background, tinted with the app's accent color.
class _GlowField extends StatefulWidget {
  const _GlowField({required this.color});

  final Color color;

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            Align(
              alignment: Alignment(-0.6 + t * 0.5, -0.7 + t * 0.3),
              child: _blob(320),
            ),
            Align(
              alignment: Alignment(0.7 - t * 0.4, 0.8 - t * 0.5),
              child: _blob(260),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [widget.color, widget.color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Rotating, floating stand-in for the original Three.js paper-plane scene.
class _PaperPlane extends StatefulWidget {
  const _PaperPlane({required this.glowColor, required this.planeColor});

  final Color glowColor;
  final Color planeColor;

  @override
  State<_PaperPlane> createState() => _PaperPlaneState();
}

class _PaperPlaneState extends State<_PaperPlane>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinController, _floatController]),
      builder: (context, _) {
        final spin = _spinController.value * 2 * math.pi;
        final floatY = math.sin(_floatController.value * math.pi) * -10;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.glowColor,
                        widget.glowColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY(spin)
                    ..rotateZ(math.sin(spin) * 0.08),
                  child: Icon(
                    Icons.send_rounded,
                    size: 96,
                    color: widget.planeColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.colors});

  final KalsadaColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'KALSADA',
          style:
              kalsadaHeadline(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: colors.accent,
                height: 1,
              ).copyWith(
                shadows: [Shadow(color: colors.accentSoft, blurRadius: 24)],
              ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 16, color: colors.sub),
              children: [
                const TextSpan(text: 'Your Journey, '),
                TextSpan(
                  text: 'Reimagined',
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' by AI.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _FooterLabel extends StatelessWidget {
  const _FooterLabel({required this.colors});

  final KalsadaColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 32, height: 1, color: colors.sep),
        const SizedBox(width: 16),
        Text(
          'V0.1.0 · AI TRAVEL PLANNER',
          style: kalsadaMono(
            fontSize: 10,
            letterSpacing: 1.2,
            color: colors.sub,
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 32, height: 1, color: colors.sep),
      ],
    );
  }
}

/// Four L-shaped corner accents matching the mockup's atmosphere layer.
class _CornerFrame extends StatelessWidget {
  const _CornerFrame({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    const margin = 24.0;

    Widget corner({required bool top, required bool left}) {
      return Positioned(
        top: top ? margin : null,
        bottom: top ? null : margin,
        left: left ? margin : null,
        right: left ? null : margin,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: top ? BorderSide(color: color) : BorderSide.none,
              bottom: top ? BorderSide.none : BorderSide(color: color),
              left: left ? BorderSide(color: color) : BorderSide.none,
              right: left ? BorderSide.none : BorderSide(color: color),
            ),
            borderRadius: BorderRadius.only(
              topLeft: top && left ? const Radius.circular(16) : Radius.zero,
              topRight: top && !left ? const Radius.circular(16) : Radius.zero,
              bottomLeft: !top && left
                  ? const Radius.circular(16)
                  : Radius.zero,
              bottomRight: !top && !left
                  ? const Radius.circular(16)
                  : Radius.zero,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(top: true, left: true),
        corner(top: true, left: false),
        corner(top: false, left: true),
        corner(top: false, left: false),
      ],
    );
  }
}
