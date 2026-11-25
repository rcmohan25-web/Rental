-- Guard all existing approval paths, including auto-approval, without changing
-- their signatures or inventing an admin rejection destination.
CREATE FUNCTION rental_private.booking_transition_prerequisites()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN('renter_accepted','awaiting_payment','payment_submitted') THEN
        PERFORM rental_private.require_booking_integrity(OLD.id,'renter');
        IF NEW.status='payment_submitted' THEN
            PERFORM rental_private.require_booking_integrity(OLD.id,'borrower');
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER booking_transition_prerequisites BEFORE UPDATE OF status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION rental_private.booking_transition_prerequisites();

CREATE FUNCTION rental_private.evidence_paths_valid(p_booking UUID,p_uploader UUID,p_paths TEXT[])
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT coalesce(cardinality(p_paths)>0
        AND cardinality(p_paths)=(SELECT count(DISTINCT x) FROM unnest(p_paths) x)
        AND NOT EXISTS(SELECT 1 FROM unnest(p_paths) x WHERE x IS NULL
            OR split_part(x,'/',1)<>p_uploader::TEXT OR split_part(x,'/',2)<>p_booking::TEXT
            OR length(split_part(x,'/',3))=0
            OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='handover' AND name=x)),FALSE);
$$;
CREATE OR REPLACE FUNCTION public.check_evidence_paths(p_booking_id UUID,p_paths TEXT[])
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NOT rental_private.evidence_paths_valid(p_booking_id,auth.uid(),p_paths)
        THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_booking(p_booking_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings; h public.handover_records; r public.handover_records; v_ledger JSONB;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    PERFORM rental_private.require_booking_integrity(b.id,'renter');
    PERFORM rental_private.require_booking_integrity(b.id,'borrower');
    IF b.status='completed' THEN
        IF (SELECT count(*) FROM public.ledger_entries WHERE booking_id=b.id)<>2
            OR NOT EXISTS(SELECT 1 FROM public.ledger_entries WHERE booking_id=b.id AND kind='lender_earning'
                AND user_id=b.lender_id AND amount=b.lender_earning)
            OR NOT EXISTS(SELECT 1 FROM public.ledger_entries WHERE booking_id=b.id AND kind='deposit_refund'
                AND user_id=b.borrower_id AND amount=b.deposit_amount)
            THEN RAISE EXCEPTION 'LEDGER_MISMATCH'; END IF;
        SELECT jsonb_agg(jsonb_build_object('id',id,'kind',kind,'amount',amount,'status',status) ORDER BY kind)
            INTO v_ledger FROM public.ledger_entries WHERE booking_id=b.id;
        RETURN jsonb_build_object('id',b.id,'status','completed','already_settled',TRUE,'ledger',v_ledger);
    END IF;
    IF b.status<>'returned' OR b.returned_at IS NULL THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF (SELECT count(*) FROM public.booking_payments WHERE booking_id=b.id AND status='verified')<>1
        OR NOT EXISTS(SELECT 1 FROM public.booking_payments p WHERE p.booking_id=b.id AND p.status='verified'
            AND p.submitted_by=b.borrower_id AND p.amount_received=b.rental_fee+b.deposit_amount
            AND p.reviewed_at IS NOT NULL AND p.reviewed_by IS NOT NULL
            AND length(btrim(p.reference))>0 AND split_part(p.proof_path,'/',1)=b.borrower_id::TEXT
            AND split_part(p.proof_path,'/',2)=b.id::TEXT
            AND EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='payment-proof' AND name=p.proof_path))
        THEN RAISE EXCEPTION 'PAYMENT_NOT_VERIFIED'; END IF;
    SELECT * INTO h FROM public.handover_records WHERE booking_id=b.id AND stage='pickup';
    IF NOT FOUND OR h.recorded_by<>b.lender_id OR h.checklist IS NULL
        OR jsonb_typeof(h.checklist)<>'object' OR h.checklist='{}'::JSONB
        OR h.borrower_face_path=ANY(h.item_photo_paths) OR h.borrower_id_photo_path=ANY(h.item_photo_paths)
        OR NOT rental_private.evidence_paths_valid(b.id,b.lender_id,h.item_photo_paths)
        OR NOT rental_private.evidence_paths_valid(b.id,b.lender_id,ARRAY[h.borrower_face_path,h.borrower_id_photo_path])
        THEN RAISE EXCEPTION 'HANDOVER_MISSING'; END IF;
    SELECT * INTO r FROM public.handover_records WHERE booking_id=b.id AND stage='return';
    IF NOT FOUND OR r.recorded_by<>b.lender_id OR r.recorded_at<h.recorded_at
        OR b.returned_at<>r.recorded_at
        OR NOT rental_private.evidence_paths_valid(b.id,b.lender_id,r.item_photo_paths)
        THEN RAISE EXCEPTION 'RETURN_EVIDENCE_MISSING'; END IF;
    -- Even resolved damage requires the separately approved case-settlement path.
    IF r.no_issues IS DISTINCT FROM TRUE
        OR EXISTS(SELECT 1 FROM public.damage_reports WHERE booking_id=b.id)
        OR EXISTS(SELECT 1 FROM public.receipt_confirmations WHERE booking_id=b.id AND NOT condition_ok)
        THEN RAISE EXCEPTION 'OPEN_CASE_EXISTS'; END IF;
    IF (b.returned_at AT TIME ZONE 'Asia/Kathmandu')::DATE>b.end_date THEN RAISE EXCEPTION 'LATE_RULE_NOT_APPROVED'; END IF;
    IF EXISTS(SELECT 1 FROM public.ledger_entries WHERE booking_id=b.id) THEN RAISE EXCEPTION 'LEDGER_MISMATCH'; END IF;
    INSERT INTO public.ledger_entries(booking_id,user_id,kind,amount) VALUES
        (b.id,b.lender_id,'lender_earning',b.lender_earning),(b.id,b.borrower_id,'deposit_refund',b.deposit_amount);
    UPDATE public.bookings SET status='completed' WHERE id=b.id;
    SELECT jsonb_agg(jsonb_build_object('id',id,'kind',kind,'amount',amount,'status',status) ORDER BY kind)
        INTO v_ledger FROM public.ledger_entries WHERE booking_id=b.id;
    INSERT INTO public.audit_log(actor_id,action,target_id,before_value,after_value)
        VALUES(auth.uid(),'settle_booking',b.id::TEXT,jsonb_build_object('status',b.status),
            jsonb_build_object('status','completed','ledger',v_ledger));
    RETURN jsonb_build_object('id',b.id,'status','completed','already_settled',FALSE,'ledger',v_ledger);
END;
$$;
REVOKE ALL ON FUNCTION public.settle_booking(UUID) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.settle_booking(UUID) TO authenticated;
