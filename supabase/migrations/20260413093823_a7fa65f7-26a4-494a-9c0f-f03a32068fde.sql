
-- Trigger: notify on every stock transaction insert
CREATE TRIGGER trg_notify_stock_change
AFTER INSERT ON public.stock_transactions
FOR EACH ROW
EXECUTE FUNCTION public.notify_stock_change();

-- Trigger: check low/out-of-stock on stock_items update
CREATE TRIGGER trg_check_low_stock
AFTER UPDATE ON public.stock_items
FOR EACH ROW
EXECUTE FUNCTION public.check_low_stock();
