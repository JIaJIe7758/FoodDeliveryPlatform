-- =====================================================================
-- Online Food Delivery Platform

-- Procedures 

-- The stored functions required are the same functions that are created inside question 13 and question 17 of queries.sql;
-- We use CREATE OR REPLACE so that when we run both the procedures and the queries files, it does not give an ("function already exists") error.

-- The order for running the files is: schema.sql -> data.sql -> procedures.sql -> queries.sql

-- Some implementation choices and decisions we made: 
-- We used functions and not procedures.
-- A function receives values and RETURNS a result, so it can be used inside a SELECT.
-- A procedure performs an action (insert, update, delete), so it returns nothing and is called with CALL, so we cant use it with SELECT.
-- So, in our case a function is the right choice because we want to READ data and return an output.
-- A procedure would make sense for tasks that change data, and we were not interested in that.

--  The functions use PL/pgSQL, written between $$ ... $$.
--  We also changed the name of the orders table, and is now called customer_order, since ORDER is a reserved word in SQL, so "order" would always need double quotes).
 
-- ---------------------------------------------------------------------
-- F1. fn_calculate_order_total
-- Business rule (constraint 3.3 of the requirements):
--     total = sum(unit_price * quantity) + delivery_fee - discount
--
-- Some decisions we made:
-- The function uses the unit_price stored in order_item and the delivery_fee and discount_amount stored in customer_order. 
-- These values are copied when the order is placed, so later price changes do not affect past orders.
-- To have in consideration: an order with no items makes SUM return NULL, so the result is NULL. In valid data every order has at least one item.

-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calculate_order_total(p_order_id INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
    v_items    NUMERIC;
    v_fee      NUMERIC;
    v_discount NUMERIC;
BEGIN
    SELECT delivery_fee, discount_amount
    INTO v_fee, v_discount
    FROM customer_order
    WHERE order_id = p_order_id;
 
    SELECT SUM(quantity * unit_price)
    INTO v_items
    FROM order_item
    WHERE order_id = p_order_id;
 
    RETURN v_items + v_fee - v_discount;
END;
$$ LANGUAGE plpgsql;
 
 
-- ---------------------------------------------------------------------
-- F2. fn_search_restaurants (FR8)
-- This function searches active restaurants by name, food type and city.
--
-- Things to have in consideration:
-- A parameter set to NULL means that there is no filter on that field. The same function works for any combination of the 3 filters.
-- Only restaurants with status 'active' are returned because an order can only be placed with an active restaurant.
-- The three filters use LIKE, so the caller can use the % wildcard in any of them.
-- Without %, LIKE only matches the exact text.
-- LIKE is case-sensitive, so 'porto' does not match 'Porto'.
-- The output columns are named res_id, res_name, ..., because in a RETURNS TABLE the output names also act as variables inside the
-- function. If we called them name or city, PostgreSQL could not tell them apart from the columns r.name and r.city, it would be an ambiguous column.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_search_restaurants(
        p_name VARCHAR, p_food_type VARCHAR, p_city VARCHAR)
RETURNS TABLE (res_id INTEGER, res_name VARCHAR,
               res_food_type VARCHAR, res_city VARCHAR)
AS $$
BEGIN
    RETURN QUERY
    SELECT r.restaurant_id, r.name, ft.name, r.city
    FROM restaurant r
    JOIN food_type ft ON ft.food_type_id = r.food_type_id
    WHERE r.status = 'active'
      AND (p_name      IS NULL OR r.name  LIKE p_name)
      AND (p_food_type IS NULL OR ft.name LIKE p_food_type)
      AND (p_city      IS NULL OR r.city  LIKE p_city);
END;
$$ LANGUAGE plpgsql;
 
