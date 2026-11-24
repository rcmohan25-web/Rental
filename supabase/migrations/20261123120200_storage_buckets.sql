-- =============================================================================
-- Phase 0, migration 3 of 4: storage buckets and storage policies
-- Owner: Srijan.
--
-- Bucket            Public  Who writes                         Who reads
-- ----------------  ------  ---------------------------------  ---------------------------
-- item-photos       yes     the Renter, in their own folder    everyone (public URLs)
-- kyc-documents     no      the user, in their own folder      admins only
-- handover-evidence no      the booking's Renter               Renter, Borrower, admins
-- payment-proofs    no      the booking's Borrower             Borrower and admins
--
-- Path rules (the first folder of the object name is the access key):
--   item-photos        <user_id>/<anything>              e.g. 7c1e.../a1b2.jpg
--   kyc-documents      <user_id>/<anything>              e.g. 7c1e.../id-1699.jpg
--   handover-evidence  <booking_id>/<anything>
--   payment-proofs     <booking_id>/<anything>
-- Upload with a NEW file name each time (no upsert). Users cannot overwrite or
-- delete private files, which keeps the evidence trail intact.
--
-- Size and type limits are enforced by the bucket itself: 5 MB, images only.
-- The storage tables already have RLS enabled by Supabase; do not enable it here.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('item-photos',       'item-photos',       true,  5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('kyc-documents',     'kyc-documents',     false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('handover-evidence', 'handover-evidence', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('payment-proofs',    'payment-proofs',    false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- item-photos (public bucket)
-- -----------------------------------------------------------------------------

create policy "item_photos_public_read"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'item-photos');

create policy "item_photos_insert_own_folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.is_active_user()
  );

create policy "item_photos_update_own_folder"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "item_photos_delete_own_folder"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- -----------------------------------------------------------------------------
-- kyc-documents (private). Users upload; only admins can look.
-- -----------------------------------------------------------------------------

create policy "kyc_documents_insert_own_folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.is_active_user()
  );

create policy "kyc_documents_admin_read"
  on storage.objects for select to authenticated
  using (bucket_id = 'kyc-documents' and public.is_admin());

create policy "kyc_documents_admin_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'kyc-documents' and public.is_admin());

-- -----------------------------------------------------------------------------
-- handover-evidence (private)
-- The folder name is the booking id. The booking lookup below runs under the
-- caller's own RLS, so a user only matches bookings they take part in.
-- -----------------------------------------------------------------------------

create policy "handover_evidence_renter_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'handover-evidence'
    and exists (
      select 1 from public.bookings b
      where b.id::text = (storage.foldername(name))[1]
        and b.lender_id = (select auth.uid())
        and b.status in ('payment_verified', 'handed_over', 'returned', 'disputed')
    )
  );

create policy "handover_evidence_participants_read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'handover-evidence'
    and (
      public.is_admin()
      or exists (
        select 1 from public.bookings b
        where b.id::text = (storage.foldername(name))[1]
          and (b.lender_id = (select auth.uid()) or b.borrower_id = (select auth.uid()))
      )
    )
  );

-- -----------------------------------------------------------------------------
-- payment-proofs (private)
-- The Borrower uploads proof while payment is due (or while it is being
-- checked, to replace a bad photo). Only the Borrower and admins can read it;
-- the Renter never sees payment proof.
-- -----------------------------------------------------------------------------

create policy "payment_proofs_borrower_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and exists (
      select 1 from public.bookings b
      where b.id::text = (storage.foldername(name))[1]
        and b.borrower_id = (select auth.uid())
        and b.status in ('awaiting_payment', 'payment_submitted')
    )
  );

create policy "payment_proofs_borrower_and_admin_read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (
      public.is_admin()
      or exists (
        select 1 from public.bookings b
        where b.id::text = (storage.foldername(name))[1]
          and b.borrower_id = (select auth.uid())
      )
    )
  );
