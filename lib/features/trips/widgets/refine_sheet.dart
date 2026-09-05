import 'package:kalsada/data/trip.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/trips/trip_edit_store.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

const List<String> _refineSuggestions = [
  'Make it cheaper',
  'Add a rest day',
  'More food stops',
  'Make it more scenic',
];

/// Opens the AI-refine sheet for [trip]: a free-text instruction the model
/// applies to the existing plan, saving the revision in place.
Future<void> showRefineSheet(BuildContext context, Trip trip) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RefineSheet(trip: trip),
  );
}

class _RefineSheet extends StatefulWidget {
  const _RefineSheet({required this.trip});

  final Trip trip;

  @override
  State<_RefineSheet> createState() => _RefineSheetState();
}

class _RefineSheetState extends State<_RefineSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String instruction) async {
    final text = instruction.trim();
    if (text.isEmpty) return;
    final store = sl<TripEditStore>();
    if (store.isBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await store.refineTrip(widget.trip, text);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Trip updated.' : store.errorMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final store = sl<TripEditStore>();
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.ter,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'Refine with AI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tell the planner what to change.',
            style: TextStyle(fontSize: 14, color: colors.sub),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _refineSuggestions)
                Material(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _submit(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(fontSize: 14, color: colors.text),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
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
                    controller: _controller,
                    onSubmitted: _submit,
                    style: TextStyle(fontSize: 15, color: colors.text),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'e.g. swap day 2 for a beach',
                      hintStyle: TextStyle(fontSize: 15, color: colors.sub),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Observer(
                builder: (context) => Material(
                  color: colors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: store.isBusy
                        ? null
                        : () => _submit(_controller.text),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: store.isBusy
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
