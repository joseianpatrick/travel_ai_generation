import 'package:kalsada/data/local/tile_cache.dart';
import 'package:kalsada/data/supabase/supabase_config.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/router/app_router.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:kalsada/theme/theme_store.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  final tileCacheStore = await buildTileCacheStore();
  sl.registerSingleton<HiveCacheStore>(tileCacheStore);
  DependencyManager().init();
  sl<AuthStore>().initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeStore = sl<ThemeStore>();
    return Observer(
      builder: (context) => MaterialApp.router(
        title: 'Kalsada',
        theme: kalsadaTheme(Brightness.light),
        darkTheme: kalsadaTheme(Brightness.dark),
        themeMode: themeStore.dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    );
  }
}
