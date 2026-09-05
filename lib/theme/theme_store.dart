import 'package:mobx/mobx.dart';

part 'theme_store.g.dart';

class ThemeStore = _ThemeStoreBase with _$ThemeStore;

abstract class _ThemeStoreBase with Store {
  @observable
  bool dark = false;

  @action
  void toggleDark() => dark = !dark;
}
