
-- Create role enum
CREATE TYPE public.app_role AS ENUM ('manager', 'worker');

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL DEFAULT 'worker',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- RLS policies for user_roles
CREATE POLICY "Users can view their own role"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Managers can view all roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));

CREATE POLICY "Managers can insert roles"
  ON public.user_roles FOR INSERT
  TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'manager'));

CREATE POLICY "Managers can update roles"
  ON public.user_roles FOR UPDATE
  TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));

CREATE POLICY "Managers can delete roles"
  ON public.user_roles FOR DELETE
  TO authenticated
  USING (public.has_role(auth.uid(), 'manager'));

-- Create notifications table
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  is_read BOOLEAN NOT NULL DEFAULT false,
  stock_item_id UUID REFERENCES public.stock_items(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can delete their own notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Function to create notifications for all authenticated users when stock changes
CREATE OR REPLACE FUNCTION public.notify_stock_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_name TEXT;
  notif_title TEXT;
  notif_message TEXT;
  notif_type TEXT;
  user_record RECORD;
BEGIN
  -- Get item name
  SELECT name INTO item_name FROM public.stock_items WHERE id = NEW.stock_item_id;

  IF NEW.transaction_type = 'received' THEN
    notif_title := 'Stock Received';
    notif_message := item_name || ': ' || NEW.quantity || ' units received';
    notif_type := 'stock_received';
  ELSIF NEW.transaction_type = 'issued' THEN
    notif_title := 'Stock Issued';
    notif_message := item_name || ': ' || NEW.quantity || ' units issued';
    notif_type := 'stock_issued';
  ELSIF NEW.transaction_type = 'damaged' THEN
    notif_title := 'Damaged Items';
    notif_message := item_name || ': ' || NEW.quantity || ' units reported damaged';
    notif_type := 'damaged';
  ELSE
    notif_title := 'Stock Update';
    notif_message := item_name || ': ' || NEW.quantity || ' units (' || NEW.transaction_type || ')';
    notif_type := 'info';
  END IF;

  -- Notify all users with roles
  FOR user_record IN SELECT DISTINCT ur.user_id FROM public.user_roles ur
  LOOP
    INSERT INTO public.notifications (user_id, title, message, type, stock_item_id)
    VALUES (user_record.user_id, notif_title, notif_message, notif_type, NEW.stock_item_id);
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_stock_transaction_created
  AFTER INSERT ON public.stock_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_stock_change();

-- Function to check low stock and notify
CREATE OR REPLACE FUNCTION public.check_low_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_record RECORD;
BEGIN
  IF NEW.quantity_on_hand <= NEW.minimum_stock_level AND NEW.quantity_on_hand > 0
     AND (OLD.quantity_on_hand IS NULL OR OLD.quantity_on_hand > NEW.minimum_stock_level) THEN
    FOR user_record IN SELECT DISTINCT ur.user_id FROM public.user_roles ur
    LOOP
      INSERT INTO public.notifications (user_id, title, message, type, stock_item_id)
      VALUES (user_record.user_id, 'Low Stock Alert', NEW.name || ' is running low (' || NEW.quantity_on_hand || ' remaining)', 'low_stock', NEW.id);
    END LOOP;
  END IF;

  IF NEW.quantity_on_hand <= 0 AND (OLD.quantity_on_hand IS NULL OR OLD.quantity_on_hand > 0) THEN
    FOR user_record IN SELECT DISTINCT ur.user_id FROM public.user_roles ur
    LOOP
      INSERT INTO public.notifications (user_id, title, message, type, stock_item_id)
      VALUES (user_record.user_id, 'Out of Stock', NEW.name || ' is out of stock!', 'out_of_stock', NEW.id);
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_stock_level_change
  AFTER UPDATE ON public.stock_items
  FOR EACH ROW
  EXECUTE FUNCTION public.check_low_stock();

-- Auto-assign worker role on signup
CREATE OR REPLACE FUNCTION public.assign_default_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'worker')
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_default_role();

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
