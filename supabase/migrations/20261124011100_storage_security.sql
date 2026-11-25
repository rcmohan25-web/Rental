-- Keep bucket names and uploader prefixes. Additional booking-id path segment
-- links new workflow evidence to its booking without moving any existing files.
UPDATE storage.buckets SET file_size_limit = 5242879,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
    WHERE id IN ('item-photos', 'kyc', 'handover', 'payment-proof');

DROP POLICY kyc_select_own ON storage.objects;
CREATE POLICY kyc_admin_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'kyc' AND public.is_admin());
DROP POLICY handover_select_own ON storage.objects;
CREATE POLICY handover_admin_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'handover' AND public.is_admin());
CREATE POLICY payment_admin_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'payment-proof' AND public.is_admin());

DROP POLICY kyc_insert_own ON storage.objects;
CREATE POLICY kyc_insert_own ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kyc' AND (storage.foldername(name))[1] = auth.uid()::TEXT AND public.is_active_user());
DROP POLICY handover_insert_own ON storage.objects;
CREATE POLICY handover_insert_own ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'handover' AND (storage.foldername(name))[1] = auth.uid()::TEXT
        AND public.is_active_user() AND EXISTS (SELECT 1 FROM public.bookings b
            WHERE b.id::TEXT = (storage.foldername(name))[2] AND b.lender_id = auth.uid()
            AND b.status IN ('payment_verified', 'handed_over', 'returned', 'disputed')));
DROP POLICY payment_proof_insert_own ON storage.objects;
CREATE POLICY payment_proof_insert_own ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'payment-proof' AND (storage.foldername(name))[1] = auth.uid()::TEXT
        AND public.is_active_user() AND EXISTS (SELECT 1 FROM public.bookings b
            WHERE b.id::TEXT = (storage.foldername(name))[2] AND b.borrower_id = auth.uid()
            AND b.status IN ('awaiting_payment', 'payment_submitted')));
DROP POLICY item_photos_insert_own ON storage.objects;
CREATE POLICY item_photos_insert_own ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'item-photos' AND (storage.foldername(name))[1] = auth.uid()::TEXT AND public.is_active_user());
DROP POLICY item_photos_update_own ON storage.objects;
CREATE POLICY item_photos_update_own ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'item-photos' AND (storage.foldername(name))[1] = auth.uid()::TEXT AND public.is_active_user())
    WITH CHECK (bucket_id = 'item-photos' AND (storage.foldername(name))[1] = auth.uid()::TEXT AND public.is_active_user());
DROP POLICY item_photos_delete_own ON storage.objects;
CREATE POLICY item_photos_delete_own ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'item-photos' AND (storage.foldername(name))[1] = auth.uid()::TEXT AND public.is_active_user());
