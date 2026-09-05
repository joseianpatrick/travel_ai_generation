import 'package:kalsada/theme/theme_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts in light mode and toggles', () {
    final store = ThemeStore();
    expect(store.dark, isFalse);

    store.toggleDark();
    expect(store.dark, isTrue);

    store.toggleDark();
    expect(store.dark, isFalse);
  });
}
