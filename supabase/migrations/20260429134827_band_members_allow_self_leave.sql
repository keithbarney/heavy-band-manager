CREATE POLICY "Users can leave their band"
  ON public.band_members
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());;
