import 'dart:async';

import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/planner/kalsada_catalog.dart';
import 'package:kalsada/features/planner/planner_store.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:kalsada/features/planner/widgets/trip_options_sheet.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/shared/widgets/primary_button.dart';
import 'package:kalsada/shared/widgets/theme_toggle_button.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:genui/genui.dart';
import 'package:go_router/go_router.dart';

const List<String> _suggestions = [
  '6-day Palawan group ride, 6 riders',
  'Weekend Cebu food trip for two',
  'Solo Banaue rice terraces trek',
];

/// The "Plan a Trip" tab: a GenUI conversation with the trip agent.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late SurfaceController _surfaceController;
  late TripAgentTransport _transport;
  late Conversation _conversation;
  StreamSubscription<ConversationEvent>? _eventsSubscription;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _surfaceController = SurfaceController(catalogs: [kalsadaCatalog]);
    _transport = sl<TripAgentTransport>();
    _conversation = Conversation(
      controller: _surfaceController,
      transport: _transport,
    );
    _eventsSubscription = _conversation.events.listen((event) {
      // Conversation swallows transport errors and reports them as events.
      if (event is ConversationError) {
        _handleAgentError(event.error);
        return;
      }
      _scrollToBottom();
    });
  }

  void _handleAgentError(Object error) {
    final message = error is TripAgentException
        ? error.message
        : 'Something went wrong generating your trip. Please try again.';
    sl<PlannerStore>().failGeneration(message);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _conversation.dispose();
    _transport.dispose();
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startGeneration(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty) return;
    final plannerStore = sl<PlannerStore>();
    if (plannerStore.isGenerating) return;
    _promptController.clear();
    plannerStore.startGeneration(text);
    _transport.pendingOptions = plannerStore.options;
    await _conversation.sendRequest(ChatMessage.user(text));
    final trip = _transport.lastGeneratedTrip;
    if (trip != null) {
      await plannerStore.completeGeneration(trip);
    }
    _scrollToBottom();
  }

  void _openItinerary() {
    final trip = sl<PlannerStore>().generatedTrip;
    if (trip.id.isEmpty) return;
    sl<TripsStore>().selectTrip(trip.id);
    context.pushNamed('itinerary', pathParameters: {'id': trip.id});
  }

  void _resetPlanner() {
    _transport.clearSurfaces();
    sl<PlannerStore>().reset();
  }

  Future<void> _openOptions() async {
    final store = sl<PlannerStore>();
    final updated = await showTripOptionsSheet(context, store.options);
    if (updated != null) store.updateOptions(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final plannerStore = sl<PlannerStore>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: ThemeToggleButton(),
                  ),
                  Text(
                    'Plan a Trip',
                    style: kalsadaHeadline(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Observer(
                builder: (context) {
                  if (plannerStore.isIdle) {
                    return _IdleSuggestions(
                      onPrompt: _startGeneration,
                      errorMessage: plannerStore.errorMessage,
                      onDismissError: plannerStore.clearError,
                    );
                  }
                  return _ConversationFeed(
                    scrollController: _scrollController,
                    surfaceController: _surfaceController,
                    conversation: _conversation,
                    prompt: plannerStore.prompt,
                    isGenerating: plannerStore.isGenerating,
                    isComplete: plannerStore.isComplete,
                    onOpenItinerary: _openItinerary,
                    onReset: _resetPlanner,
                  );
                },
              ),
            ),
            _OptionsPill(
              store: plannerStore,
              onTap: _openOptions,
            ),
            _PromptBar(
              controller: _promptController,
              onSend: _startGeneration,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable summary of the current [PlannerOptions] above the prompt bar.
class _OptionsPill extends StatelessWidget {
  const _OptionsPill({required this.store, required this.onTap});

  final PlannerStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: colors.fill,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Observer(
                      builder: (context) => Text(
                        store.options.summaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleSuggestions extends StatelessWidget {
  const _IdleSuggestions({
    required this.onPrompt,
    this.errorMessage = '',
    this.onDismissError,
  });

  final ValueChanged<String> onPrompt;
  final String errorMessage;
  final VoidCallback? onDismissError;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 18),
          child: Column(
            children: [
              Icon(Icons.auto_awesome, size: 30, color: colors.accent),
              const SizedBox(height: 10),
              Text(
                'Tell me about your trip, or try an idea below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colors.sub,
                ),
              ),
            ],
          ),
        ),
        if (errorMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withAlpha(90)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(fontSize: 13, color: colors.text),
                  ),
                ),
                if (onDismissError != null)
                  InkWell(
                    onTap: onDismissError,
                    child: Icon(Icons.close, size: 16, color: colors.sub),
                  ),
              ],
            ),
          ),
        for (final suggestion in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.fill,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPrompt(suggestion),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(fontSize: 14, color: colors.text),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConversationFeed extends StatelessWidget {
  const _ConversationFeed({
    required this.scrollController,
    required this.surfaceController,
    required this.conversation,
    required this.prompt,
    required this.isGenerating,
    required this.isComplete,
    required this.onOpenItinerary,
    required this.onReset,
  });

  final ScrollController scrollController;
  final SurfaceController surfaceController;
  final Conversation conversation;
  final String prompt;
  final bool isGenerating;
  final bool isComplete;
  final VoidCallback onOpenItinerary;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return ValueListenableBuilder<ConversationState>(
      valueListenable: conversation.state,
      builder: (context, state, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            for (final surfaceId in state.surfaces)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Surface(
                  surfaceContext: surfaceController.contextFor(surfaceId),
                ),
              ),
            if (isGenerating)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ThinkingDots(),
                ),
              ),
            if (isComplete) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  state.latestText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'View Full Itinerary',
                onPressed: onOpenItinerary,
                height: 48,
              ),
              TextButton(
                onPressed: onReset,
                child: Text(
                  'Plan another trip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PromptBar extends StatelessWidget {
  const _PromptBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.fill,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: controller,
                onSubmitted: onSend,
                style: TextStyle(fontSize: 15, color: colors.text),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Ask about your next trip…',
                  hintStyle: TextStyle(fontSize: 15, color: colors.sub),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSend(controller.text),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_upward,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Opacity(
                  opacity: _dotOpacity(i),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.sub,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value - index * 0.136) % 1.0;
    // Pulse: dim at rest, bright mid-cycle, mirroring the design keyframes.
    if (phase < 0.4) return 0.3 + 0.7 * (phase / 0.4);
    if (phase < 0.8) return 1.0 - 0.7 * ((phase - 0.4) / 0.4);
    return 0.3;
  }
}
