
-- Drop old permissive policies on stock_items
DROP POLICY IF EXISTS "Authenticated users can delete stock items" ON public.stock_items;
DROP POLICY IF EXISTS "Authenticated users can insert stock items" ON public.stock_items;
DROP POLICY IF EXISTS "Authenticated users can update stock items" ON public.stock_items;
DROP POLICY IF EXISTS "Authenticated users can view stock items" ON public.stock_items;

-- New role-aware policies for stock_items
CREATE POLICY "All authenticated can view stock items"
  ON public.stock_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "All authenticated can insert stock items"
  ON public.stock_items FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "All authenticated can update stock items"
  ON public.stock_items FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Only managers can delete stock items"
  ON public.stock_items FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));

-- Drop old permissive policies on stock_transactions
DROP POLICY IF EXISTS "Authenticated users can delete transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Authenticated users can insert transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Authenticated users can update transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Authenticated users can view transactions" ON public.stock_transactions;

-- New role-aware policies for stock_transactions
CREATE POLICY "All authenticated can view transactions"
  ON public.stock_transactions FOR SELECT TO authenticated USING (true);

CREATE POLICY "All authenticated can insert transactions"
  ON public.stock_transactions FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Only managers can update transactions"
  ON public.stock_transactions FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));

CREATE POLICY "Only managers can delete transactions"
  ON public.stock_transactions FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));
