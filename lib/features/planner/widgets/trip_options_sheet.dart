import 'package:kalsada/features/planner/planner_options.dart';
import 'package:kalsada/shared/widgets/number_stepper.dart';
import 'package:kalsada/shared/widgets/primary_button.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// Opens the trip-options sheet, returning the edited [PlannerOptions] or null
/// if the user dismissed it without applying.
Future<PlannerOptions?> showTripOptionsSheet(
  BuildContext context,
  PlannerOptions current,
) {
  return showModalBottomSheet<PlannerOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripOptionsSheet(initial: current),
  );
}

class _TripOptionsSheet extends StatefulWidget {
  const _TripOptionsSheet({required this.initial});

  final PlannerOptions initial;

  @override
  State<_TripOptionsSheet> createState() => _TripOptionsSheetState();
}

/// Longest trip the agent will plan; keeps the prompt (and Gemini's output
/// token budget) from blowing up on an unbounded stepper tap-fest.
const int _maxDays = 21;

class _TripOptionsSheetState extends State<_TripOptionsSheet> {
  late PlannerOptions _options = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
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
          Text(
            'Trip options',
            style: kalsadaHeadline(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Give the planner some context.',
            style: TextStyle(fontSize: 14, color: colors.sub),
          ),
          const SizedBox(height: 18),

          _SectionLabel('Travel mode'),
          Row(
            children: [
              for (final mode in TravelMode.values) ...[
                _OptionChip(
                  label: mode.label,
                  selected: _options.travelMode == mode,
                  onTap: () => setState(
                    () => _options = _options.copyWith(travelMode: mode),
                  ),
                ),
                if (mode != TravelMode.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),

          _SectionLabel('Roads'),
          _OptionChip(
            label: 'Avoid expressways',
            selected: _options.avoidExpressways,
            onTap: () => setState(
              () => _options = _options.copyWith(
                avoidExpressways: !_options.avoidExpressways,
              ),
            ),
          ),
          const SizedBox(height: 18),

          _SectionLabel('Group size'),
          NumberStepper(
            value:
                '${_options.groupSize} '
                '${_options.groupSize == 1 ? 'rider' : 'riders'}',
            onDecrement: _options.groupSize > 1
                ? () => setState(
                    () => _options = _options.copyWith(
                      groupSize: _options.groupSize - 1,
                    ),
                  )
                : null,
            onIncrement: _options.groupSize < 8
                ? () => setState(
                    () => _options = _options.copyWith(
                      groupSize: _options.groupSize + 1,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 18),

          _SectionLabel('Pace'),
          Row(
            children: [
              for (final pace in TripPace.values) ...[
                _OptionChip(
                  label: pace.label,
                  selected: _options.pace == pace,
                  onTap: () =>
                      setState(() => _options = _options.copyWith(pace: pace)),
                ),
                if (pace != TripPace.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),

          _SectionLabel('Lodging budget'),
          Row(
            children: [
              for (final budget in LodgingBudget.values) ...[
                _OptionChip(
                  label: budget.label,
                  selected: _options.lodgingBudget == budget,
                  onTap: () => setState(
                    () => _options = _options.copyWith(lodgingBudget: budget),
                  ),
                ),
                if (budget != LodgingBudget.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),

          _SectionLabel('Length'),
          NumberStepper(
            value: _options.days == null
                ? 'Auto'
                : '${_options.days} ${_options.days == 1 ? 'day' : 'days'}',
            onDecrement: _options.days == null
                ? null
                : () => setState(() {
                    final next = _options.days! - 1;
                    _options = next < 1
                        ? _options.copyWith(clearDays: true)
                        : _options.copyWith(days: next);
                  }),
            onIncrement: (_options.days ?? 0) >= _maxDays
                ? null
                : () => setState(
                    () => _options = _options.copyWith(
                      days: (_options.days ?? 0) + 1,
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(_options),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: kalsadaMono(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.sub,
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Material(
      color: selected ? colors.accent : colors.fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colors.text,
            ),
          ),
        ),
      ),
    );
  }
}

