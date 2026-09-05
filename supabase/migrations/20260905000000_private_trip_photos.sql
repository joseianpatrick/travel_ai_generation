-- Trip photos contain user content and must not be anonymously readable.
-- New object paths use: {auth.uid()}/{tripId}/{timestamp}.{extension}.

insert into storage.buckets (id, name, public)
values ('trip-photos', 'trip-photos', false)
on conflict (id) do update set public = false;

drop policy if exists "users read own trip photos" on storage.objects;
create policy "users read own trip photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'trip-photos'
  and (
    (storage.foldername(name))[1] = (select auth.uid()::text)
    or exists (
      select 1
      from public.trip_photos
      where user_id = (select auth.uid())
        and data ->> 'url' like '%/trip-photos/' || storage.objects.name || '%'
    )
  )
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
  and (
    (storage.foldername(name))[1] = (select auth.uid()::text)
    or exists (
      select 1
      from public.trip_photos
      where user_id = (select auth.uid())
        and data ->> 'url' like '%/trip-photos/' || storage.objects.name || '%'
    )
  )
);
