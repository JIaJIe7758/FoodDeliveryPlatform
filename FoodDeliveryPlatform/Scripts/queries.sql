--Question 1
--Who are the highest-spending customers and how many addresses have they saved?
SELECT c.customer_account_id, 
c.full_name, 
COUNT(o.order_id) AS total_orders, 
SUM(o.total_amount) AS total_spent,
(SELECT COUNT(*)
FROM address a
WHERE a.customer_account_id= c.customer_account_id) AS saved_addresses)
FROM customer_account c
JOIN "order" o ON o.customer_account_id= c.customer_account_id
WHERE o.status= 'delivered'
GROUP BY c.customer_account_id, c.full_name
ORDER BY total_spent DESC
LIMIT 10; 

--Question 2
--Which payment type (card/mbway) is preferred ans which has the highest average order total.
SELECT pm.type,
COUNT(o.order_id) AS orders_made,
ROUND(AVG(o.total_amount),2) AS avg_order_total
FROM payment_method pm
JOIN "order" o ON o.payment_method_id= pm.payment_method_id
WHERE o.status= 'delivered'
GROUP BY pm.type
ORDER BY orders_made DESC;

--Question 3
--Who are the top drivers? Considering their delivered orders and their average driver rating.
SELECT d.driver_account_id,
d.full_name,
COUNT(o.order_id) AS delivered_orders,
ROUND(AVG(r.driver_rating),2) AS avg_driver_rating
FROM driver_account d
JOIN "order" o ON o.driver_account_id=d.driver_account_id
LEFT JOIN review r ON r.order_id= o.order_id
WHERE o.status='delivered'
GROUP BY d.driver_account_id, d.full_name
ORDER BY delivered_orders DESC
LIMIT 10;

--Question 4
--Which restaurant have the most revenue and completed orders?
SELECT r.restaurant_id,
r.name AS restaurant,
ra.company_name,
COUNT(o.order_id) AS completed_orders,
SUM(o.total_amount) AS revenue
FROM restaurant r
JOIN restaurant_account ra ON ra.restaurant_account_id = r.restaurant_account_id
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'delivered'
GROUP BY r.restaurant_id, r.name, ra.company_name
ORDER BY revenue DESC;

--Question 5
--Which menu items are the best-sellers and what is their food type?
SELECT mi.name AS menu_item,
ft.name AS food_type,
SUM(oi.quantity) AS units_sold
FROM menu_item mi
JOIN order_item oi ON oi.menu_item_id = mi.menu_item_id
JOIN "order" o ON o.order_id = oi.order_id
JOIN restaurant r ON r.restaurant_id = mi.restaurant_id
JOIN food_type ft ON ft.food_type_id = r.food_type_id
WHERE o.status = 'delivered'
GROUP BY mi.menu_item_id, mi.name, ft.name
ORDER BY units_sold DESC
LIMIT 10;

--Question 6
-- What is the average delivery time per restaurant, from slowest to fastest.
--Delivered_at and placed_at give us a time interval
SELECT r.name AS restaurant,
AVG(o.delivered_at-o.placed_at) AS avg_delivery_time
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'delivered'
GROUP BY r.restaurant_id, r.name
ORDER BY avg_delivery_time DESC;

--Question 7
--Which available menu items were never ordered?
SELECT mi.name, mi.price, r.name AS restaurant
FROM menu_item mi
JOIN restaurant r ON r.restaurant_id = mi.restaurant_id
WHERE mi.is_available = TRUE AND NOT EXISTS (SELECT*
FROM order_item oi
WHERE oi.menu_item_id = mi.menu_item_id);

--Question 8
--Which restaurants have the most negative reviews (1 or 2 stars)?
SELECT r.name AS restaurant, COUNT(*) AS negative_reviews
FROM review rv
JOIN "order" o ON o.order_id = rv.order_id
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
WHERE rv.restaurant_rating <= 2
GROUP BY r.restaurant_id, r.name
ORDER BY negative_reviews DESC;

--Question 9
--Which are the average order values with promotion in comparison with the full price?
SELECT (SELECT ROUND(AVG(o.total_amount), 2)
FROM "order" o 
WHERE o.status = 'delivered' AND o.promotion_id IS NULL) AS avg_full_price),
(SELECT ROUND(AVG(o.total_amount), 2)
FROM "order" o
WHERE o.status = 'delivered' AND o.promotion_id IS NOT NULL) AS avg_with_promotion;

--Question 10
--Which drivers have a consistent top service of at least 5 five-star ratings on delivered orders?
SELECT d.driver_account_id,
d.full_name,
COUNT(*) AS five_star_deliveries
FROM driver_account d
JOIN "order" o ON o.driver_account_id = d.driver_account_id
JOIN review r ON r.order_id = o.order_id
WHERE o.status = 'delivered' AND r.driver_rating = 5
GROUP BY d.driver_account_id, d.full_name
HAVING COUNT(*) >= 5
ORDER BY five_star_deliveries DESC;

--Question 11:
--What revenue was lost to cancellations and at what stage did it happen?
--When no driver is assigned that means that the order was cancelled before the delivery started.
SELECT CASE WHEN o.driver_account_id IS null
THEN 'Before driver assigned'
ELSE 'After driver assigned' END AS cancellation_stage,
COUNT(*) AS cancelled_orders,
SUM(o.total_amount) AS lost_revenue
FROM "order" o
WHERE o.status = 'cancelled'
GROUP BY CASE WHEN o.driver_account_id IS null
THEN 'Before driver assigned'
ELSE 'After driver assigned' END;

--Question 12
--Which active restaurants have a delivery fee below the average fee of their own city?
SELECT r.name, r.city, r.delivery_fee
FROM restaurant r
WHERE r.status = 'active'AND r.delivery_fee < (SELECT AVG(r2.delivery_fee)
FROM restaurant r2
WHERE r2.city = r.city)
ORDER BY r.city, r.delivery_fee;

--Question 13
--Search active restaurants by name, food type and city.
--We create the function fn_search_restaurants.
--A parameter set to NULL means that there is no filter on that field.
CREATE OR REPLACE FUNCTION fn_search_restaurants(p_name VARCHAR, p_food_type VARCHAR, p_city VARCHAR)
RETURNS TABLE (res_id INTEGER, res_name VARCHAR,res_food_type VARCHAR, res_city VARCHAR)
AS $$
BEGIN
RETURN QUERY
SELECT r.restaurant_id, r.name, ft.name, r.city
FROM restaurant r
JOIN food_type ft ON ft.food_type_id = r.food_type_id
WHERE r.status = 'active'
AND (p_name IS NULL OR r.name LIKE p_name)
AND (p_food_type IS NULL OR ft.name LIKE p_food_type)
AND (p_city IS NULL OR r.city  ILIKE p_city);
END;
$$ LANGUAGE plpgsql;
--Now we call the function we created
SELECT * FROM fn_search_restaurants('%Pizza%', 'Italian', 'Lisboa');

--Question 14
--Who are the loyal customers and what total amount do they spend? 
--We consider ad loyal customers, the customers who had orders delivered from at least 3 different restaurants).
SELECT c.customer_account_id, 
c.full_name,
COUNT(DISTINCT o.restaurant_id) AS different_restaurants,
COUNT(o.order_id) AS total_orders,
SUM(o.total_amount) AS total_spent
FROM customer_account c
JOIN "order" o ON o.customer_account_id = c.customer_account_id
WHERE o.status = 'delivered'
GROUP BY c.customer_account_id, c.full_name
HAVING COUNT(DISTINCT o.restaurant_id) >= 3
ORDER BY total_spent DESC;

--Question 15
--Number of restaurants and average delivery fees, only combinations 
--with more than 1 restaurant, and per city and per food.
SELECT r.city, 
ft.name AS food_type,
COUNT(r.restaurant_id) AS number_of_restaurants,
ROUND(AVG(r.delivery_fee), 2) AS avg_delivery_fee
FROM restaurant r
JOIN food_type ft ON ft.food_type_id = r.food_type_id
GROUP BY r.city, ft.name
HAVING COUNT(r.restaurant_id) > 1;

--Question 16
--Latest position of each driver that is online and shares their location
SELECT d.full_name, 
dl.latitude, 
dl.longitude, 
dl.location_time
FROM driver_account d
JOIN driver_location dl ON dl.driver_account_id = d.driver_account_id
WHERE d.availability <> 'offline'
AND d.location_sharing_consent = TRUE
AND dl.location_time = (SELECT MAX(dl2.location_time) 
FROM driver_location dl2 
WHERE dl2.driver_account_id = d.driver_account_id);

--Question 17
--Checking to see if the stored total in each order is the same as the calculated total at the end.
--For that we created the function fn_calculate_order_total: total= sum(unit_price* quantity) + delivery_fee - discont.
--A difference of 0 means that the order is consistent.
CREATE OR REPLACE FUNCTION fn_calculate_order_total(p_order_id INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
v_items NUMERIC;
v_fee NUMERIC;
v_discount NUMERIC;
BEGIN
SELECT delivery_fee, discount_amount
INTO v_fee, v_discount
FROM "order"
WHERE order_id = p_order_id;
 
SELECT SUM(quantity * unit_price)
INTO v_items
FROM order_item
WHERE order_id = p_order_id;
 
RETURN v_items + v_fee - v_discount;
END;
$$ LANGUAGE plpgsql;
 
SELECT o.order_id,
o.total_amount AS stored_total,
fn_calculate_order_total(o.order_id) AS calculated_total,
o.total_amount - fn_calculate_order_total(o.order_id) AS difference
FROM "order" o
ORDER BY o.order_id
LIMIT 10;

--Question 18
--We will create a 10% coupon, valid for 30 days, for every active restaurant that does not have any promotion yet
INSERT INTO promotion (type, value, coupon_code, start_date, end_date, restaurant_id)
SELECT 'percentage', 10, 'WELCOME10-' || r.restaurant_id, CURRENT_DATE, CURRENT_DATE + INTERVAL '30' DAY, r.restaurant_id
FROM restaurant r
WHERE r.status = 'active' AND NOT EXISTS (select*  FROM promotion p
WHERE p.restaurant_id = r.restaurant_id);

--Question 19
--Update the price to an increase of 5% of the price of the available items 
--of active restaurants that have at least 5 reviews and an average rating of 4.5 or more.
UPDATE menu_item
SET price = ROUND(price * 1.05, 2)
WHERE is_available = TRUE
AND restaurant_id IN (SELECT o.restaurant_id 
FROM "order" o
JOIN review rv    ON rv.order_id = o.order_id
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
WHERE r.status = 'active'
GROUP BY o.restaurant_id
HAVING COUNT(rv.review_id) >= 5
AND AVG(rv.restaurant_rating) >= 4.5);
 

--Question 20
--Delete saved payments that were never used in any order, but only for customers who
--already order with another method
DELETE FROM payment_method pm
WHERE NOT EXISTS (SELECT 1
FROM "order" o
WHERE o.payment_method_id = pm.payment_method_id)
AND EXISTS (SELECT 1
FROM "order" o2
WHERE o2.customer_account_id = pm.customer_account_id);

--VIEWS
--1. Spending per customer
CREATE OR REPLACE VIEW v_customer_spending AS
SELECT c.customer_account_id, c.full_name, COUNT(o.order_id)   AS total_orders, SUM(o.total_amount) AS total_spent
FROM customer_account c
JOIN "order" o ON o.customer_account_id = c.customer_account_id
WHERE o.status = 'delivered'
GROUP BY c.customer_account_id, c.full_name;

--2. Restaurant performance, having in consideration its orders, revenue and its delivery time
CREATE OR REPLACE VIEW v_restaurant_performance AS
SELECT r.restaurant_id, r.name AS restaurant,
COUNT(o.order_id)   AS completed_orders,
SUM(o.total_amount) AS revenue,
AVG(o.delivered_at - o.placed_at) AS avg_delivery_time
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'delivered'
GROUP BY r.restaurant_id, r.name;

--3. Driver performance, having in consideration its deliveries and average rating
CREATE OR REPLACE VIEW v_driver_performance AS
SELECT d.driver_account_id, d.full_name, COUNT(o.order_id) AS delivered_orders,ROUND(AVG(r.driver_rating), 2) AS avg_driver_rating
FROM driver_account d
JOIN "order" o ON o.driver_account_id = d.driver_account_id
LEFT JOIN review r ON r.order_id = o.order_id
WHERE o.status = 'delivered'
GROUP BY d.driver_account_id, d.full_name;

--4. Units sold per menu, having also in consideration the items never ordered
CREATE OR REPLACE VIEW v_menu_item_sales AS
SELECT mi.menu_item_id, mi.name AS menu_item, r.name AS restaurant, SUM(oi.quantity) AS units_sold
FROM menu_item mi
JOIN restaurant r ON r.restaurant_id = mi.restaurant_id
JOIN order_item oi ON oi.menu_item_id = mi.menu_item_id
GROUP BY mi.menu_item_id, mi.name, r.name;

--5. The cancelled orders and lost revenue per restaurant
CREATE OR REPLACE VIEW v_cancelled_orders AS
SELECT r.restaurant_id, r.name AS restaurant, COUNT(o.order_id) AS cancelled_orders,SUM(o.total_amount) AS lost_revenue
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'cancelled'
GROUP BY r.restaurant_id, r.name;










