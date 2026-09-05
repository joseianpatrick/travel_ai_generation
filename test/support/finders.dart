import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matches a [Text] widget by its label, ignoring display-only casing
/// transforms (e.g. `PrimaryButton`/`AuthTextField` render labels via
/// `.toUpperCase()`) so assertions can read as the actual copy.
Finder findLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.data?.toUpperCase() == label.toUpperCase(),
);
