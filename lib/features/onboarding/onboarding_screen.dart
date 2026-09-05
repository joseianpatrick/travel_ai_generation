import 'package:base_project/shared/widgets/primary_button.dart';
import 'package:base_project/shared/widgets/trip_photo_banner.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _OnboardSlide {
  const _OnboardSlide({
    required this.stripeA,
    required this.stripeB,
    required this.caption,
    required this.title,
    required this.body,
  });

  final Color stripeA;
  final Color stripeB;
  final String caption;
  final String title;
  final String body;
}

const List<_OnboardSlide> _slides = [
  _OnboardSlide(
    stripeA: Color(0xFF2B6F63),
    stripeB: Color(0xFF245C52),
    caption: 'PALAWAN COASTLINE · PHOTO',
    title: 'Kalsada',
    body: 'Plan group rides and trips together — routes, budgets, and gear, '
        'sorted in seconds.',
  ),
  _OnboardSlide(
    stripeA: Color(0xFF1F5F8B),
    stripeB: Color(0xFF194B6E),
    caption: 'AI ITINERARY · PHOTO',
    title: 'Describe it, get a plan',
    body: 'Tell Kalsada about your trip and watch a full itinerary generate '
        'in seconds — routes, stops, and timing included.',
  ),
  _OnboardSlide(
    stripeA: Color(0xFF8A5A2B),
    stripeB: Color(0xFF6E4520),
    caption: 'ROUTE MAP · PHOTO',
    title: 'Routes, mapped out',
    body: 'See day-by-day routes and distances plotted on the map, synced '
        'with your itinerary.',
  ),
  _OnboardSlide(
    stripeA: Color(0xFF5B3B8A),
    stripeB: Color(0xFF472E6E),
    caption: 'GROUP GEAR · PHOTO',
    title: 'Ride together, sorted',
    body: 'Split budgets, track gear checklists, and keep the whole crew on '
        'the same page.',
  ),
];

/// Multi-slide intro carousel ending in the sign-up / sign-in actions.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  bool get _isLast => _step == _slides.length - 1;

  void _next() =>
      setState(() => _step = (_step + 1).clamp(0, _slides.length - 1));

  void _skip() => setState(() => _step = _slides.length - 1);

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final slide = _slides[_step];
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: TripPhotoBanner(
                    key: ValueKey(_step),
                    height: double.infinity,
                    caption: slide.caption,
                    gradientOverlay: true,
                    stripeA: slide.stripeA,
                    stripeB: slide.stripeB,
                  ),
                ),
                if (!_isLast)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 10,
                    right: 16,
                    child: Material(
                      color: const Color(0x52000000),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _skip,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(_step),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: kalsadaHeadline(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide.body,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: colors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          width: i == _step ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _step ? colors.accent : colors.sep,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        if (i < _slides.length - 1) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (_isLast) ...[
                    PrimaryButton(
                      label: 'Get Started',
                      onPressed: () => context.goNamed('signup'),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () => context.goNamed('signin'),
                        child: Text(
                          'I already have an account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    PrimaryButton(label: 'Next', onPressed: _next),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
