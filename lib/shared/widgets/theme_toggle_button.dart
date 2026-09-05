import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/shared/widgets/circle_icon_button.dart';
import 'package:kalsada/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

/// Sun/moon toggle that flips the app between light and dark mode.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeStore = sl<ThemeStore>();
    return Observer(
      builder: (context) => CircleIconButton(
        icon: themeStore.dark
            ? Icons.dark_mode
            : Icons.light_mode_outlined,
        tooltip: themeStore.dark
            ? 'Switch to light mode'
            : 'Switch to dark mode',
        onPressed: themeStore.toggleDark,
      ),
    );
  }
}
