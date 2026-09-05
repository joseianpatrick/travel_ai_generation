-- Trip photos contain user content and must not be anonymously readable.
-- Object paths use: {auth.uid()}/{tripId}/{timestamp}.{extension}.
-- The client persists that path and displays photos via short-lived signed
-- URLs (PhotoUploadService.createSignedUrl), so no public read is needed.

insert into storage.buckets (id, name, public)
values ('trip-photos', 'trip-photos', false)
on conflict (id) do update set public = false;

-- Drop the original bucket-wide policies: they only checked bucket_id, so
-- any authenticated user could upload into or delete from anyone's folder,
-- and reads were open to anon. Policies are permissive (OR'd), so leaving
-- them in place would defeat the owner-scoped ones below.
drop policy if exists "Public can read trip photos" on storage.objects;
drop policy if exists "Authenticated can upload trip photos" on storage.objects;
drop policy if exists "Authenticated can delete trip photos" on storage.objects;

drop policy if exists "users read own trip photos" on storage.objects;
create policy "users read own trip photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'trip-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "users upload own trip photos" on storage.objects;
create policy "users upload own trip photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'trip-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "users delete own trip photos" on storage.objects;
create policy "users delete own trip photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'trip-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
