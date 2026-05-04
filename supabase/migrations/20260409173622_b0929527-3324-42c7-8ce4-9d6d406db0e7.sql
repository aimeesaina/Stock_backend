
-- Create stock_items table
CREATE TABLE public.stock_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General',
  unit TEXT NOT NULL DEFAULT 'pcs',
  quantity_received INTEGER NOT NULL DEFAULT 0,
  quantity_issued INTEGER NOT NULL DEFAULT 0,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  minimum_stock_level INTEGER NOT NULL DEFAULT 0,
  expiry_date DATE,
  status TEXT NOT NULL DEFAULT 'in_stock' CHECK (status IN ('in_stock', 'low_stock', 'out_of_stock', 'expired')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view stock items" ON public.stock_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert stock items" ON public.stock_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update stock items" ON public.stock_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete stock items" ON public.stock_items FOR DELETE TO authenticated USING (true);

-- Create stock_transactions table
CREATE TABLE public.stock_transactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  stock_item_id UUID NOT NULL REFERENCES public.stock_items(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('received', 'issued', 'adjustment')),
  quantity INTEGER NOT NULL,
  reference TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.stock_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view transactions" ON public.stock_transactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert transactions" ON public.stock_transactions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update transactions" ON public.stock_transactions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete transactions" ON public.stock_transactions FOR DELETE TO authenticated USING (true);

-- Timestamp trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_stock_items_updated_at
  BEFORE UPDATE ON public.stock_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
