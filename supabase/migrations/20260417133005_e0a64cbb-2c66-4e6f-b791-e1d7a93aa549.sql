-- Ensure triggers exist for automatic notifications on stock changes

-- Drop if exist to avoid duplicates
DROP TRIGGER IF EXISTS trg_notify_stock_change ON public.stock_transactions;
DROP TRIGGER IF EXISTS trg_check_low_stock ON public.stock_items;
DROP TRIGGER IF EXISTS trg_assign_default_role ON auth.users;

-- Trigger: notify all users when a stock transaction is created
CREATE TRIGGER trg_notify_stock_change
AFTER INSERT ON public.stock_transactions
FOR EACH ROW
EXECUTE FUNCTION public.notify_stock_change();

-- Trigger: check low stock after stock_items update
CREATE TRIGGER trg_check_low_stock
AFTER UPDATE ON public.stock_items
FOR EACH ROW
EXECUTE FUNCTION public.check_low_stock();

-- Trigger: assign default 'worker' role on signup (will be overridden by signup metadata if provided)
CREATE TRIGGER trg_assign_default_role
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.assign_default_role();

-- Update assign_default_role to read role from raw_user_meta_data if present
CREATE OR REPLACE FUNCTION public.assign_default_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  selected_role public.app_role;
BEGIN
  -- Read role from signup metadata, default to 'worker'
  BEGIN
    selected_role := COALESCE(
      (NEW.raw_user_meta_data ->> 'role')::public.app_role,
      'worker'::public.app_role
    );
  EXCEPTION WHEN OTHERS THEN
    selected_role := 'worker'::public.app_role;
  END;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, selected_role)
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$function$;