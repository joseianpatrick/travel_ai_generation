/// Supabase project configuration.
///
/// Placeholder values keep the app running against the local in-memory
/// repository. Fill in the real project URL and anon key to switch the app
/// to Supabase (see `DependencyManager.setTripsStore`). Expected tables:
///
/// ```sql
/// create table trips (
///   id text primary key,
///   data jsonb not null,
///   updated_at timestamptz not null default now()
/// );
/// alter publication supabase_realtime add table trips;
///
/// create table trip_photos (
///   id text primary key,
///   data jsonb not null,
///   updated_at timestamptz not null default now(),
///   user_id uuid default auth.uid() references auth.users(id)
/// );
/// alter publication supabase_realtime add table trip_photos;
///
/// -- Private storage bucket. Objects are namespaced by the authenticated
/// -- user's id and only the object path is persisted in trip_photos.data.
/// insert into storage.buckets (id, name, public)
///   values ('trip-photos', 'trip-photos', false)
///   on conflict (id) do update set public = false;
///
/// create policy "users read own trip photos" on storage.objects
///   for select to authenticated using (
///     bucket_id = 'trip-photos' and
///     (storage.foldername(name))[1] = (select auth.uid()::text)
///   );
/// create policy "users upload own trip photos" on storage.objects
///   for insert to authenticated with check (
///     bucket_id = 'trip-photos' and
///     (storage.foldername(name))[1] = (select auth.uid()::text)
///   );
/// create policy "users delete own trip photos" on storage.objects
///   for delete to authenticated using (
///     bucket_id = 'trip-photos' and
///     (storage.foldername(name))[1] = (select auth.uid()::text)
///   );
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  /// The project URL, injected at build time via
  /// `--dart-define-from-file=.env` (see `.env.example`).
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable (or legacy anon) API key.
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const String tripsTable = 'trips';

  static const String photosTable = 'trip_photos';

  static const String photosBucket = 'trip-photos';

  /// Whether real credentials have been provided.
  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.isNotEmpty;
}
