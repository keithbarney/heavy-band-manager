CREATE OR REPLACE FUNCTION public.delete_band(p_band_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM bands WHERE id = p_band_id AND leader_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Only the band leader can delete a band';
  END IF;

  DELETE FROM bands WHERE id = p_band_id;
END;
$function$;;
