-- DEV AND DEMO SEED (runs on `supabase db reset`; for a cloud project paste it
-- into the SQL editor once). Migrations never seed these values: the approved
-- ones (commission 10%, deposit 20%, multiplier 1.5) come from the migration
-- 20261124011500, the rest below are PLACEHOLDERS an admin changes later
-- (docs/api-contract.md section 3.1).
INSERT INTO public.app_settings(key, value) VALUES
    ('return_grace_hours', '24'),
    ('legal_action_period_days', '14'),
    ('request_expiry_hours', '48'),
    ('min_declared_value', '2000'),
    ('min_deposit_amount', '1000'),      -- illustrative, docs/business-rules.md
    ('auto_approve_orders', 'true')
ON CONFLICT (key) DO NOTHING;

-- One published, active terms version per audience so create_booking_request
-- works. Prototype wording only: Sapati's legal team replaces it.
INSERT INTO public.terms_documents(title, version, content, status, audience, is_active, published_at)
SELECT a || ' terms', '1',
    'Prototype terms, not legal advice. Sapati operates the Rental platform. ' ||
    CASE a
        WHEN 'general' THEN 'Payments are manual and verified by an admin. There is no escrow or insurance.'
        WHEN 'borrower' THEN 'You return the item on time and in the condition you received it.'
        ELSE 'You describe the item honestly and hand it over only against the handover code.'
    END ||
    CASE WHEN a = 'general' THEN '' ELSE
        ' Using another person''s ID, submitting a false or altered identity document or photo, or letting someone else use your verified account is misuse of identity. It can lead to account suspension and may be punishable according to the law. Sapati may keep and pass on the evidence it holds where the law requires.'
    END,
    'published', a, TRUE, NOW()
FROM unnest(ARRAY['general', 'borrower', 'renter']) AS a
WHERE NOT EXISTS (SELECT 1 FROM public.terms_documents t WHERE t.audience = a);
