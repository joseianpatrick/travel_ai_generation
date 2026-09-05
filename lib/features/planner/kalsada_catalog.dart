import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Catalog id announced to the agent in [CreateSurfaceMessage]s.
const String kalsadaCatalogId = 'com.kalsada.travel';

/// The widget vocabulary the trip agent may use to build generated UI.
final Catalog kalsadaCatalog = Catalog(
  [
    _tripOverviewCard,
    _routeCard,
    _budgetCard,
    _gearCard,
  ],
  catalogId: kalsadaCatalogId,
  systemPromptFragments: const [
    'Present a generated trip as, in order: TripOverviewCard, RouteCard, '
        'BudgetCard, and GearChecklistCard.',
  ],
);

/// Rounded card shell with the "✦ Generated · <label>" badge.
class _GeneratedCard extends StatelessWidget {
  const _GeneratedCard({required this.badge, required this.child});

  final String badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 10, color: colors.accent),
                const SizedBox(width: 5),
                Text(
                  badge.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

final CatalogItem _tripOverviewCard = CatalogItem(
  name: 'TripOverviewCard',
  dataSchema: S.object(
    description: 'Headline summary of a generated trip.',
    properties: {
      'name': S.string(description: 'Trip name.'),
      'dates': S.string(description: 'Human readable date range.'),
      'riders': S.integer(description: 'Number of riders.'),
      'nights': S.integer(description: 'Number of nights.'),
      'distance': S.string(description: 'Total distance, e.g. "612 km".'),
    },
    required: ['name', 'dates', 'riders', 'nights', 'distance'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final colors = itemContext.buildContext.kalsada;

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.sub)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ],
      ),
    );

    return _GeneratedCard(
      badge: 'Generated · Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['name']}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${data['dates']}',
            style: TextStyle(fontSize: 13, color: colors.sub),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Riders', '${data['riders']}'),
              stat('Nights', '${data['nights']}'),
              stat('Distance', '${data['distance']}'),
            ],
          ),
        ],
      ),
    );
  },
);

final CatalogItem _routeCard = CatalogItem(
  name: 'RouteCard',
  dataSchema: S.object(
    description: 'Day-by-day route of the trip.',
    properties: {
      'days': S.list(
        items: S.object(
          properties: {
            'day': S.integer(),
            'title': S.string(),
            'distance': S.string(),
          },
          required: ['day', 'title', 'distance'],
        ),
      ),
    },
    required: ['days'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final colors = itemContext.buildContext.kalsada;
    final days = (data['days'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList();

    return _GeneratedCard(
      badge: 'Generated · Route',
      child: Column(
        children: [
          for (final day in days)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.sep, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Day ${day['day']} · ${day['title']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${day['distance']}',
                    style: TextStyle(fontSize: 12, color: colors.sub),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  },
);

final CatalogItem _budgetCard = CatalogItem(
  name: 'BudgetCard',
  dataSchema: S.object(
    description: 'Per-rider budget breakdown of the trip.',
    properties: {
      'totalPerRider': S.string(),
      'totalGroup': S.string(),
      'riders': S.integer(),
      'items': S.list(
        items: S.object(
          properties: {'label': S.string(), 'amount': S.string()},
          required: ['label', 'amount'],
        ),
      ),
    },
    required: ['totalPerRider', 'totalGroup', 'riders', 'items'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final colors = itemContext.buildContext.kalsada;
    final items = (data['items'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList();

    return _GeneratedCard(
      badge: 'Generated · Budget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data['totalPerRider']}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text(
                'per rider',
                style: TextStyle(fontSize: 12, color: colors.sub),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${data['totalGroup']} total for ${data['riders']} riders',
            style: TextStyle(fontSize: 12, color: colors.sub),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['label']}',
                      style: TextStyle(fontSize: 13, color: colors.text),
                    ),
                  ),
                  Text(
                    '${item['amount']}',
                    style: TextStyle(fontSize: 13, color: colors.sub),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  },
);

final CatalogItem _gearCard = CatalogItem(
  name: 'GearChecklistCard',
  dataSchema: S.object(
    description: 'Suggested gear checklist for the trip.',
    properties: {
      'items': S.list(items: S.string()),
    },
    required: ['items'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final colors = itemContext.buildContext.kalsada;
    final items = (data['items'] as List? ?? const [])
        .whereType<String>()
        .toList();

    return _GeneratedCard(
      badge: 'Generated · Gear Checklist',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: colors.accent),
                  const SizedBox(width: 5),
                  Text(
                    item,
                    style: TextStyle(fontSize: 12, color: colors.text),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  },
);
