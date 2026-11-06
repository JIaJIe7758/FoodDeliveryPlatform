-- ---------------------------------------------------------------------
-- Trigger 1: validations on review
--   * only delivered orders can be reviewed
--   * a driver rating only makes sense if the order had a driver
-- Why a trigger: the rule depends on the status of ANOTHER table
-- (customer_order); a CHECK can only look at the row being inserted.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_review()
RETURNS TRIGGER AS $$
DECLARE
    order_status  VARCHAR(12);
    order_driver  INTEGER;
BEGIN
    SELECT status, driver_account_id
    INTO order_status, order_driver
    FROM customer_order
    WHERE order_id = NEW.order_id;

    IF order_status <> 'delivered' THEN
        RAISE EXCEPTION 'Order % is not delivered, so it cannot be reviewed', NEW.order_id;
    END IF;

    IF NEW.driver_rating IS NOT NULL AND order_driver IS NULL THEN
        RAISE EXCEPTION 'Order % has no driver, so driver_rating must be empty', NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_review ON review;
CREATE TRIGGER trg_check_review
BEFORE INSERT OR UPDATE ON review
FOR EACH ROW
EXECUTE FUNCTION check_review();


-- ---------------------------------------------------------------------
-- Trigger 2: validations on order_item
--   * the item must belong to the restaurant of the order
--   * an unavailable item cannot be added to an order being placed
--   * unit_price is copied from the menu when it is not given
--     (price at purchase time: later menu changes do not affect the order)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_order_item()
RETURNS TRIGGER AS $$
DECLARE
    order_rest    INTEGER;
    order_status  VARCHAR(12);
    item_rest     INTEGER;
    item_price    NUMERIC(8,2);
    item_avail    BOOLEAN;
BEGIN
    SELECT restaurant_id, status
    INTO order_rest, order_status
    FROM customer_order
    WHERE order_id = NEW.order_id;

    SELECT restaurant_id, price, is_available
    INTO item_rest, item_price, item_avail
    FROM menu_item
    WHERE menu_item_id = NEW.menu_item_id;

    IF item_rest <> order_rest THEN
        RAISE EXCEPTION 'Menu item % does not belong to the restaurant of order %',
            NEW.menu_item_id, NEW.order_id;
    END IF;

    -- availability only matters while the order is being placed; historical
    -- orders may contain items that are unavailable today
    IF TG_OP = 'INSERT' AND order_status = 'placed' AND NOT item_avail THEN
        RAISE EXCEPTION 'Menu item % is not available', NEW.menu_item_id;
    END IF;

    IF NEW.unit_price IS NULL THEN
        NEW.unit_price := item_price;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_order_item ON order_item;
CREATE TRIGGER trg_check_order_item
BEFORE INSERT OR UPDATE ON order_item
FOR EACH ROW
EXECUTE FUNCTION check_order_item();


-- ---------------------------------------------------------------------
-- Trigger 3: keeps the order amounts consistent
--   total_amount = sum(quantity * unit_price) + delivery_fee - discount_amount
--   * percentage coupon: percentage of the items value
--   * fixed-amount coupon: fixed value, never above the items value
-- It runs AFTER the item is saved and recalculates the whole order, so it
-- also works when an item is updated or removed.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_order_totals()
RETURNS TRIGGER AS $$
DECLARE
    order_value  INTEGER;
    subtotal     NUMERIC(10,2);
    discount     NUMERIC(8,2) := 0;
    promo_type   VARCHAR(15);
    promo_value  NUMERIC(8,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        order_value := OLD.order_id;
    ELSE
        order_value := NEW.order_id;
    END IF;

    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO subtotal
    FROM order_item
    WHERE order_id = order_value;

    SELECT p.type, p.value
    INTO promo_type, promo_value
    FROM customer_order o
    JOIN promotion p ON p.promotion_id = o.promotion_id
    WHERE o.order_id = order_value;

    IF promo_type = 'percentage' THEN
        discount := ROUND(subtotal * promo_value / 100, 2);
    ELSIF promo_type = 'fixed-amount' THEN
        discount := LEAST(promo_value, subtotal);
    END IF;

    UPDATE customer_order
    SET discount_amount = discount,
        total_amount    = subtotal + delivery_fee - discount
    WHERE order_id = order_value;

    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_order_totals ON order_item;
CREATE TRIGGER trg_update_order_totals
AFTER INSERT OR UPDATE OR DELETE ON order_item
FOR EACH ROW
EXECUTE FUNCTION update_order_totals();
