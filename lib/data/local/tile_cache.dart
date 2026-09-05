import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';

/// Builds the persistent disk store backing the map's offline tile cache.
/// Must be awaited once, before [runApp], so the store is ready by the time
/// MapScreen's first TileLayer builds.
Future<HiveCacheStore> buildTileCacheStore() async {
  final dir = await getTemporaryDirectory();
  return HiveCacheStore(dir.path, hiveBoxName: 'kalsada_map_tiles');
}
