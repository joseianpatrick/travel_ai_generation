import 'package:base_project/data/trip.dart';
import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/trips/trip_edit_store.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/shared/widgets/circle_icon_button.dart';
import 'package:base_project/shared/widgets/number_stepper.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

/// Colors assigned to newly added riders, cycling in order.
const List<int> _riderPalette = [
  0xFF007AFF,
  0xFFFF9500,
  0xFF34C759,
  0xFFAF52DE,
  0xFF5AC8FA,
  0xFFFF375F,
];

/// Manual editor for a trip's basics: headline details, riders, gear, budget.
/// Route days stay as generated (edit them via AI refine).
class TripEditScreen extends StatefulWidget {
  const TripEditScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends State<TripEditScreen> {
  late Trip _trip;

  final _name = TextEditingController();
  final _dates = TextEditingController();
  final _distance = TextEditingController();
  final _perRider = TextEditingController();
  final _group = TextEditingController();
  int _nights = 0;

  final List<_DayDraft> _days = [];
  final List<TextEditingController> _riderInitials = [];
  final List<int> _riderColors = [];
  final List<TextEditingController> _gear = [];
  final List<TextEditingController> _budgetLabels = [];
  final List<TextEditingController> _budgetAmounts = [];

  @override
  void initState() {
    super.initState();
    final tripsStore = sl<TripsStore>();
    final match = tripsStore.trips.where((t) => t.id == widget.tripId);
    // Fall back to an empty trip rather than tripsStore.activeTrip: on a
    // cold deep link that arrives before/without the requested trip loaded,
    // activeTrip could silently be a *different* trip the user was last
    // viewing, and this screen would edit the wrong one.
    _trip = match.isEmpty ? Trip.empty() : match.first;
    if (_trip.id.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Trip not found.')),
        );
      });
    }
    _name.text = _trip.name;
    _dates.text = _trip.datesLabel;
    _distance.text = _trip.distanceTotal;
    _perRider.text = _trip.totalPerRider;
    _group.text = _trip.totalGroup;
    _nights = _trip.nights;
    for (final day in _trip.days) {
      _days.add(_DayDraft(day));
    }
    for (final rider in _trip.riders) {
      _riderInitials.add(TextEditingController(text: rider.initials));
      _riderColors.add(rider.colorValue);
    }
    for (final item in _trip.gearItems) {
      _gear.add(TextEditingController(text: item));
    }
    for (final item in _trip.budgetItems) {
      _budgetLabels.add(TextEditingController(text: item.label));
      _budgetAmounts.add(TextEditingController(text: item.amount));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _dates,
      _distance,
      _perRider,
      _group,
      ..._riderInitials,
      ..._gear,
      ..._budgetLabels,
      ..._budgetAmounts,
    ]) {
      c.dispose();
    }
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  Trip _assembled() {
    return _trip
        .copyWith(
          name: _name.text.trim(),
          datesLabel: _dates.text.trim(),
          nights: _nights,
          distanceTotal: _distance.text.trim(),
          totalPerRider: _perRider.text.trim(),
          totalGroup: _group.text.trim(),
          days: [
            for (var index = 0; index < _days.length; index++)
              _days[index].toDay(index + 1),
          ],
          riders: [
            for (var i = 0; i < _riderInitials.length; i++)
              Rider(
                initials: _riderInitials[i].text.trim(),
                colorValue: _riderColors[i],
              ),
          ],
          gearItems: [
            for (final c in _gear)
              if (c.text.trim().isNotEmpty) c.text.trim(),
          ],
          budgetItems: [
            for (var i = 0; i < _budgetLabels.length; i++)
              BudgetItem(
                label: _budgetLabels[i].text.trim(),
                amount: _budgetAmounts[i].text.trim(),
              ),
          ],
        )
        .withStableItineraryIds();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip name is required.')));
      return;
    }
    final store = sl<TripEditStore>();
    final ok = await store.saveTrip(_assembled());
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(store.errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final store = sl<TripEditStore>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Text(
                    'Edit Trip',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  Observer(
                    builder: (context) => TextButton(
                      onPressed: store.isBusy ? null : _save,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: store.isBusy ? colors.sub : colors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _Field(label: 'Trip name', controller: _name),
                  _Field(label: 'Dates', controller: _dates),
                  _SectionLabel('Nights'),
                  NumberStepper(
                    value: '$_nights ${_nights == 1 ? 'night' : 'nights'}',
                    onDecrement: _nights > 0
                        ? () => setState(() => _nights--)
                        : null,
                    onIncrement: () => setState(() => _nights++),
                  ),
                  const SizedBox(height: 14),
                  _Field(label: 'Total distance', controller: _distance),
                  _Field(label: 'Total per rider', controller: _perRider),
                  _Field(label: 'Total for group', controller: _group),

                  const SizedBox(height: 8),
                  _ListHeader(label: 'Destinations', onAdd: _addDay),
                  for (var d = 0; d < _days.length; d++)
                    _DaySection(
                      key: ValueKey('day_${_days[d].dayNumber}_$d'),
                      draft: _days[d],
                      displayDayNumber: d + 1,
                      onChanged: () => setState(() {}),
                      onRemove: () =>
                          setState(() => _days.removeAt(d).dispose()),
                    ),

                  const SizedBox(height: 8),
                  _ListHeader(label: 'Riders', onAdd: _addRider),
                  for (var i = 0; i < _riderInitials.length; i++)
                    _RemovableRow(
                      key: ValueKey('rider_$i'),
                      onRemove: () => setState(() {
                        _riderInitials.removeAt(i).dispose();
                        _riderColors.removeAt(i);
                      }),
                      child: _MiniField(
                        controller: _riderInitials[i],
                        hint: 'Initials',
                        maxLength: 2,
                      ),
                    ),

                  const SizedBox(height: 8),
                  _ListHeader(label: 'Gear', onAdd: _addGear),
                  for (var i = 0; i < _gear.length; i++)
                    _RemovableRow(
                      key: ValueKey('gear_$i'),
                      onRemove: () =>
                          setState(() => _gear.removeAt(i).dispose()),
                      child: _MiniField(
                        controller: _gear[i],
                        hint: 'Gear item',
                      ),
                    ),

                  const SizedBox(height: 8),
                  _ListHeader(label: 'Budget', onAdd: _addBudget),
                  for (var i = 0; i < _budgetLabels.length; i++)
                    _RemovableRow(
                      key: ValueKey('budget_$i'),
                      onRemove: () => setState(() {
                        _budgetLabels.removeAt(i).dispose();
                        _budgetAmounts.removeAt(i).dispose();
                      }),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _MiniField(
                              controller: _budgetLabels[i],
                              hint: 'Label',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _MiniField(
                              controller: _budgetAmounts[i],
                              hint: 'Amount',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addDay() => setState(() {
    final nextNumber = _days.isEmpty ? 1 : _days.last.dayNumber + 1;
    _days.add(_DayDraft.blank(nextNumber));
  });

  void _addRider() => setState(() {
    _riderInitials.add(TextEditingController());
    _riderColors.add(_riderPalette[_riderColors.length % _riderPalette.length]);
  });

  void _addGear() => setState(() => _gear.add(TextEditingController()));

  void _addBudget() => setState(() {
    _budgetLabels.add(TextEditingController());
    _budgetAmounts.add(TextEditingController());
  });
}

/// Mutable editing state for one itinerary day. Keeps the map coordinates and
/// distance/duration as generated (those come from the AI) while letting the
/// user edit the destination, its stops, and where they'll stay.
class _DayDraft {
  _DayDraft(ItineraryDay day)
    : id = day.id,
      dayNumber = day.day,
      latitude = day.latitude,
      longitude = day.longitude,
      distance = day.distance,
      duration = day.duration,
      title = TextEditingController(text: day.title),
      stay = TextEditingController(text: day.stay),
      stayPrice = TextEditingController(text: day.stayPrice),
      stops = [
        for (final s in day.stops)
          _StopDraft(
            id: s.id,
            time: s.time,
            place: s.place,
            note: s.note,
            latitude: s.latitude,
            longitude: s.longitude,
            status: s.status,
          ),
      ];

  _DayDraft.blank(int number)
    : this(
        ItineraryDay.empty().copyWith(
          id: newItineraryEntityId('day'),
          day: number,
        ),
      );

  final String id;
  final int dayNumber;
  final double latitude;
  final double longitude;
  final String distance;
  final String duration;
  final TextEditingController title;
  final TextEditingController stay;
  final TextEditingController stayPrice;
  final List<_StopDraft> stops;

  ItineraryDay toDay(int displayDayNumber) => ItineraryDay(
    id: id,
    day: displayDayNumber,
    title: title.text.trim(),
    distance: distance,
    duration: duration,
    latitude: latitude,
    longitude: longitude,
    stay: stay.text.trim(),
    stayPrice: stayPrice.text.trim(),
    stops: [
      for (final s in stops)
        if (s.place.text.trim().isNotEmpty)
          TripStop(
            id: s.id,
            time: s.time.text.trim(),
            place: s.place.text.trim(),
            note: s.note.text.trim(),
            latitude: s.latitude,
            longitude: s.longitude,
            status: s.status,
          ),
    ],
  );

  void dispose() {
    title.dispose();
    stay.dispose();
    stayPrice.dispose();
    for (final s in stops) {
      s.dispose();
    }
  }
}

/// Mutable editing state for one stop within a day.
class _StopDraft {
  _StopDraft({
    this.id = '',
    String time = '',
    String place = '',
    String note = '',
    this.latitude,
    this.longitude,
    this.status = StopStatus.pending,
  }) : time = TextEditingController(text: time),
       place = TextEditingController(text: place),
       note = TextEditingController(text: note);

  final String id;
  final TextEditingController time;
  final TextEditingController place;
  final TextEditingController note;
  final double? latitude;
  final double? longitude;
  final StopStatus status;

  void dispose() {
    time.dispose();
    place.dispose();
    note.dispose();
  }
}

/// An editable card for one day: destination title, where you'll stay, and the
/// day's stops.
class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.draft,
    required this.displayDayNumber,
    required this.onChanged,
    required this.onRemove,
  });

  final _DayDraft draft;
  final int displayDayNumber;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAY $displayDayNumber',
                style: kalsadaMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.sub,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.remove_circle_outline, color: colors.sub),
                tooltip: 'Remove day',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MiniField(
            controller: draft.title,
            hint: 'Destination (e.g. Puerto Princesa → Port Barton)',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.hotel_outlined, size: 16, color: colors.sub),
              const SizedBox(width: 6),
              Text('Stay', style: _captionStyle(colors)),
            ],
          ),
          const SizedBox(height: 6),
          _MiniField(
            controller: draft.stay,
            hint: "Hotel or where you'll stay (optional)",
          ),
          const SizedBox(height: 8),
          _MiniField(
            controller: draft.stayPrice,
            hint: 'Price range (e.g. ₱1,500–2,500 / night)',
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stops', style: _captionStyle(colors)),
              TextButton.icon(
                onPressed: () {
                  draft.stops.add(_StopDraft(id: newItineraryEntityId('stop')));
                  onChanged();
                },
                icon: Icon(Icons.add, size: 16, color: colors.accent),
                label: Text(
                  'Add stop',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          for (var i = 0; i < draft.stops.length; i++)
            _StopEditor(
              key: ValueKey('stop_${draft.dayNumber}_$i'),
              stop: draft.stops[i],
              onRemove: () {
                draft.stops.removeAt(i).dispose();
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _StopEditor extends StatelessWidget {
  const _StopEditor({super.key, required this.stop, required this.onRemove});

  final _StopDraft stop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _MiniField(controller: stop.place, hint: 'Place'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _MiniField(controller: stop.time, hint: 'Time'),
              ),
              IconButton(
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.remove_circle_outline, color: colors.sub),
                tooltip: 'Remove stop',
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MiniField(controller: stop.note, hint: 'Note'),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          _MiniField(controller: controller, hint: label),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: InputDecoration(
          counterText: '',
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 15, color: colors.sub),
        ),
      ),
    );
  }
}

/// Style shared by every small "label above content" caption on this screen
/// (field labels, the day-card's Stay/Stops captions) so they stay in sync
/// instead of drifting apart as hand-copied [TextStyle] literals.
TextStyle _captionStyle(KalsadaColors colors) =>
    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.sub);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: _captionStyle(context.kalsada)),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, size: 18, color: colors.accent),
            label: Text(
              'Add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableRow extends StatelessWidget {
  const _RemovableRow({super.key, required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: child),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.remove_circle_outline, color: colors.sub),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
