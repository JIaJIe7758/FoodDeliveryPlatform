BEGIN;



--POPULATING "ACCOUNT" TABLE
INSERT INTO account (email, password, account_type)
SELECT
    'customer' || i || '@example.com',
    'hash',
    'customer'
FROM generate_series(1, 200) AS i;

INSERT INTO account (email, password, account_type)
SELECT
    'driver' || i || '@example.com',
    'hash',
    'driver'
FROM generate_series(1, 50) AS i;

INSERT INTO account (email, password, account_type)
SELECT
    'restaurant' || i || '@example.com',
    'hash',
    'restaurant'
FROM generate_series(1, 20) AS i;

--SELECT * FROM account;


--POPULATING ('CUSTOMER_ACCOUNT', 'RESTAURANT_ACCOUNT', 'DRIVER_ACCOUNT') TABLES

INSERT INTO customer_account (customer_account_id, full_name, telephone, nif, marketing_consent)
SELECT
	account_id,
	'Customer' || account_id,
	'9' || LPAD(account_id::TEXT, 8, '0'),
	LPAD(account_id::TEXT, 9, '0'),
	CASE 
		WHEN RANDOM() < 0.5 THEN TRUE
		ELSE FALSE
	END
FROM account
WHERE account_type = 'customer';

--SELECT * FROM customer_account ;

INSERT INTO restaurant_account (restaurant_account_id, telephone, company_name, nif)
SELECT 
	 account_id,
    '9' || LPAD(account_id::TEXT, 8, '0'),
    'Restaurant Company ' || account_id,
    LPAD(account_id::TEXT, 9, '0')
FROM account
WHERE account_type = 'restaurant';

--SELECT * FROM restaurant_account;

INSERT INTO driver_account 
	(driver_account_id, full_name, telephone, 
	vehicle_type, availability, location_sharing_consent)
SELECT
    account_id,
    'Driver ' || account_id,
    '9' || LPAD(account_id::TEXT, 8, '0'),
    CASE WHEN account_id % 2 = 0 THEN 'motorcycle'
         ELSE 'bicycle' END,
    CASE WHEN account_id % 3 = 0 THEN 'offline'
         WHEN account_id % 3 = 1 THEN 'available'
         ELSE 'busy' END,
    account_id % 2 = 0
FROM account
WHERE account_type = 'driver';

--SELECT * FROM driver_account;

--POPULATING "ADDRESS" TABLE
INSERT INTO address
(
    customer_account_id,
    street,
    postal_code,
    city,
    latitude,
    longitude
)
SELECT
    customer_account_id,
    'Street ' || customer_account_id,
    '1000-' || LPAD((customer_account_id % 1000)::TEXT, 3, '0'),

    CASE
        WHEN customer_account_id % 5 = 0 THEN 'Lisbon'
        WHEN customer_account_id % 5 = 1 THEN 'Porto'
        WHEN customer_account_id % 5 = 2 THEN 'Setubal'
        WHEN customer_account_id % 5 = 3 THEN 'Coimbra'
        ELSE 'Braga'
    END,

    CASE
        WHEN customer_account_id % 5 = 0 THEN 38.7223
        WHEN customer_account_id % 5 = 1 THEN 41.1579
        WHEN customer_account_id % 5 = 2 THEN 38.5244
        WHEN customer_account_id % 5 = 3 THEN 40.2033
        ELSE 41.5454
    END,

    CASE
        WHEN customer_account_id % 5 = 0 THEN -9.1393
        WHEN customer_account_id % 5 = 1 THEN -8.6291
        WHEN customer_account_id % 5 = 2 THEN -8.8882
        WHEN customer_account_id % 5 = 3 THEN -8.4103
        ELSE -8.4265
    END

FROM customer_account;

--SELECT * FROM address;

--POPULATING "PAYMENT_METHOD" TABLE
INSERT INTO payment_method (customer_account_id, type, provider_token, display_label)
SELECT
	 customer_account_id,
    CASE
        WHEN customer_account_id % 2 = 0 THEN 'card'
        ELSE 'mbway'
    END,
    'token_' || customer_account_id,
    CASE
        WHEN customer_account_id % 2 = 0 THEN 'Visa'
        ELSE 'MB WAY'
    END
FROM customer_account;

--SELECT * FROM payment_method;

--POPULATING "FOOD_TYPE" TABLE
INSERT INTO food_type (name)
VALUES 
	('Portuguese'),
	('Italian'),
	('Chinese'),
	('Japanese'),
	('American');

--SELECT * FROM food_type;

--POPULATING "RESTAURANT" TABLE
INSERT INTO restaurant (
    restaurant_account_id,
    food_type_id,
    name,
    telephone,
    street,
    postal_code,
    city,
    latitude,
    longitude,
    delivery_fee,
    status
)
SELECT
    restaurant_account_id,
    (restaurant_account_id % 5) + 1,
    'Restaurant ' || restaurant_account_id,
    telephone,
    'Street ' || restaurant_account_id,
    '1000-' || LPAD((restaurant_account_id % 1000)::TEXT, 3, '0'),
    CASE
        WHEN restaurant_account_id % 5 = 0 THEN 'Lisbon'
        WHEN restaurant_account_id % 5 = 1 THEN 'Porto'
        WHEN restaurant_account_id % 5 = 2 THEN 'Setubal'
        WHEN restaurant_account_id % 5 = 3 THEN 'Coimbra'
        ELSE 'Braga'
    END,
    CASE
        WHEN restaurant_account_id % 5 = 0 THEN 38.7223
        WHEN restaurant_account_id % 5 = 1 THEN 41.1579
        WHEN restaurant_account_id % 5 = 2 THEN 38.5244
        WHEN restaurant_account_id % 5 = 3 THEN 40.2033
        ELSE 41.5454
     END,

     CASE
        WHEN restaurant_account_id % 5 = 0 THEN -9.1393
        WHEN restaurant_account_id % 5 = 1 THEN -8.6291
        WHEN restaurant_account_id % 5 = 2 THEN -8.8882
        WHEN restaurant_account_id % 5 = 3 THEN -8.4103
        ELSE -8.4265
 	 END,
    ROUND((1 + RANDOM() * 4)::NUMERIC, 2),
    CASE
        WHEN restaurant_account_id % 5 = 0 THEN 'inactive'
        ELSE 'active'
    END
FROM restaurant_account;

--SELECT * FROM restaurant;

--POPULATING "MENU_ITEM" TABLE
INSERT INTO menu_item (
    restaurant_id,
    name,
    category,
    price,
    is_available
)
SELECT
    restaurant.restaurant_id,
    
    CASE
        WHEN food_type.name = 'Portuguese' THEN
            CASE generate_series
                WHEN 1 THEN 'Bacalhau'
                WHEN 2 THEN 'Francesinha'
                WHEN 3 THEN 'Bifana'
                WHEN 4 THEN 'Caldo Verde'
                ELSE 'Pastel de Nata'
            END
        WHEN food_type.name = 'Italian' THEN
            CASE generate_series
                WHEN 1 THEN 'Pizza'
                WHEN 2 THEN 'Lasagna'
                WHEN 3 THEN 'Carbonara'
                WHEN 4 THEN 'Risotto'
                ELSE 'Tiramisu'
            END
        WHEN food_type.name = 'Chinese' THEN
            CASE generate_series
                WHEN 1 THEN 'Fried Rice'
                WHEN 2 THEN 'Dumplings'
                WHEN 3 THEN 'Noodles'
                WHEN 4 THEN 'Peking Duck'
                ELSE 'Milk Tea'
            END
        WHEN food_type.name = 'Japanese' THEN
            CASE generate_series
                WHEN 1 THEN 'Sushi'
                WHEN 2 THEN 'Ramen'
                WHEN 3 THEN 'Tempura'
                WHEN 4 THEN 'Udon'
                ELSE 'Mochi'
            END
        WHEN food_type.name = 'American' THEN
            CASE generate_series
                WHEN 1 THEN 'Burger'
                WHEN 2 THEN 'Hot Dog'
                WHEN 3 THEN 'BBQ Ribs'
                WHEN 4 THEN 'Chicken Wings'
                ELSE 'Cheesecake'
            END
    END,
    CASE
        WHEN generate_series = 5 THEN 'Dessert'
        ELSE 'Main Course'
    END,
    ROUND((5 + RANDOM() * 15)::NUMERIC, 2),
    RANDOM() < 0.8
FROM restaurant,
     generate_series(1, 5),
     food_type
WHERE restaurant.food_type_id = food_type.food_type_id;

--SELECT * FROM menu_item;

--POPULATING "PROMOTION" TABLE
INSERT INTO promotion (
    restaurant_id,
    type,
    value,
    coupon_code,
    start_date,
    end_date
)
VALUES
(NULL, 'percentage', 15.00, 'WELCOME15', '2026-01-01', '2026-12-31'),
(NULL, 'percentage', 25.00, 'SUMMER25', '2026-06-01', '2026-08-31'),
(NULL, 'percentage', 30.00, 'CHRISTMAS30', '2026-12-01', '2026-12-31'),
(NULL, 'percentage', 10.00, 'SPRING10', '2026-03-01', '2026-05-31'),
(NULL, 'percentage', 15.00, 'AUTUMN15', '2026-09-01', '2026-11-30'),
(NULL, 'percentage', 20.00, 'WEEKEND20', '2026-07-04', '2026-07-05'),
(NULL, 'percentage', 50.00, 'FLASH50', '2026-08-15', '2026-08-16'),
(NULL, 'percentage', 12.00, 'STUDENT12', '2026-01-01', '2026-12-31'),
(NULL, 'fixed-amount', 3.00, 'SAVE3', '2026-01-01', '2026-03-31'),
(NULL, 'fixed-amount', 7.00, 'SAVE7', '2026-04-01', '2026-06-30'),
(NULL, 'fixed-amount', 10.00, 'SAVE10', '2026-07-01', '2026-09-30'),
(NULL, 'fixed-amount', 15.00, 'SAVE15', '2026-10-01', '2026-12-31'),
(NULL, 'fixed-amount', 2.00, 'FIRSTORDER2', '2026-01-01', '2026-12-31'),
(NULL, 'fixed-amount', 5.00, 'HOLIDAY5', '2026-12-20', '2026-12-31'),
(NULL, 'fixed-amount', 8.00, 'SPECIAL8', '2026-05-01', '2026-05-15');

--SELECT * FROM promotion;


--SEED FOR "CUSTOMER_ORDER" TABLE
CREATE TEMP TABLE tmp_order_seed ON COMMIT DROP AS
WITH
customers AS (
    SELECT customer_account_id,
           ROW_NUMBER() OVER (ORDER BY customer_account_id) AS rn
    FROM customer_account
    WHERE EXISTS (SELECT 1 FROM payment_method pm
                  WHERE pm.customer_account_id = customer_account.customer_account_id)
),
restaurants AS (
    SELECT restaurant_id, delivery_fee,
           ROW_NUMBER() OVER (ORDER BY restaurant_id) AS rn
    FROM restaurant r
    WHERE EXISTS (SELECT 1 FROM menu_item mi WHERE mi.restaurant_id = r.restaurant_id)
),
drivers AS (
    SELECT driver_account_id,
           ROW_NUMBER() OVER (ORDER BY driver_account_id) AS rn
    FROM driver_account
),
counts AS (
    SELECT (SELECT COUNT(*) FROM customers) AS nc,
           (SELECT COUNT(*) FROM restaurants) AS nr,
           (SELECT COUNT(*) FROM drivers) AS nd
)
SELECT
    gs.i AS seed_no,
    c.customer_account_id,
    r.restaurant_id,
    CASE
        WHEN gs.i <= 200 OR (gs.i BETWEEN 211 AND 220)
        THEN d.driver_account_id
        ELSE NULL
    END AS driver_account_id,
    pm.payment_method_id,
    mi.menu_item_id,
    mi.price AS unit_price,
    (1 + gs.i % 3)::INTEGER AS quantity,
    r.delivery_fee,
    CASE
        WHEN gs.i % 4 = 0 THEN p_pct.promotion_id
        WHEN gs.i % 7 = 0 THEN p_fixed.promotion_id
        ELSE NULL
    END AS promotion_id,
    CASE
        WHEN gs.i <= 200 THEN 'delivered'
        WHEN gs.i <= 220 THEN 'cancelled'
        ELSE 'placed'
    END AS status,
    TIMESTAMP '2026-10-01 08:00:00' + gs.i * INTERVAL '30 minutes' AS placed_at,
    CASE WHEN gs.i <= 200 THEN
        TIMESTAMP '2026-10-01 08:00:00' + gs.i * INTERVAL '30 minutes'
        + (20 + gs.i % 55) * INTERVAL '1 minute'
    ELSE NULL END AS delivered_at,
    ('Test delivery address ' || gs.i)::VARCHAR(255) AS delivery_address
FROM generate_series(1, 240) AS gs(i)
CROSS JOIN counts ct
JOIN customers c ON c.rn = ((gs.i - 1) % NULLIF(LEAST(ct.nc, 40), 0)) + 1
JOIN restaurants r ON r.rn = (((gs.i - 1) / 40) % NULLIF(ct.nr, 0)) + 1
LEFT JOIN drivers d ON d.rn = ((gs.i - 1) % NULLIF(LEAST(ct.nd, 20), 0)) + 1
JOIN LATERAL (
    SELECT payment_method_id
    FROM payment_method
    WHERE customer_account_id = c.customer_account_id
    ORDER BY payment_method_id LIMIT 1
) pm ON TRUE
JOIN LATERAL (
    SELECT menu_item_id, price
    FROM menu_item
    WHERE restaurant_id = r.restaurant_id
    ORDER BY is_available DESC, menu_item_id
    LIMIT 1
) mi ON TRUE
LEFT JOIN LATERAL (
    SELECT promotion_id FROM promotion
    WHERE restaurant_id IS NULL AND type = 'percentage'
      AND start_date <= DATE '2026-10-01'
      AND end_date >= DATE '2026-10-06'
    ORDER BY promotion_id LIMIT 1
) p_pct ON TRUE
LEFT JOIN LATERAL (
    SELECT promotion_id FROM promotion
    WHERE restaurant_id IS NULL AND type = 'fixed-amount'
      AND value <= 2
      AND start_date <= DATE '2026-10-01'
      AND end_date >= DATE '2026-10-06'
    ORDER BY promotion_id LIMIT 1
) p_fixed ON TRUE;


-- POPULATING "CUSTOMER_ORDER" TABLE
-- total_amount is the FINAL price: items + delivery_fee - discount_amount.
INSERT INTO customer_order (
    customer_account_id, restaurant_id, driver_account_id, promotion_id,
    payment_method_id, payment_status, total_amount, delivery_fee,
    delivery_address, status, placed_at, delivered_at, discount_amount
)
SELECT
    s.customer_account_id,
    s.restaurant_id,
    s.driver_account_id,
    s.promotion_id,
    s.payment_method_id,
    CASE WHEN s.status = 'delivered' THEN 'paid' ELSE 'pending' END,
    ROUND(s.quantity * s.unit_price + s.delivery_fee - calc.discount, 2),
    s.delivery_fee,
    s.delivery_address,
    s.status,
    s.placed_at,
    s.delivered_at,
    calc.discount
FROM tmp_order_seed s
LEFT JOIN promotion p ON p.promotion_id = s.promotion_id
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN p.type = 'percentage' THEN ROUND(s.quantity * s.unit_price * p.value / 100, 2)
        WHEN p.type = 'fixed-amount' THEN LEAST(p.value, s.quantity * s.unit_price)
        ELSE 0::NUMERIC
    END AS discount
) calc;

--SELECT * FROM customer_order;

-- POPULATING "ORDER_ITEM" TABLE
INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price)
SELECT o.order_id, s.menu_item_id, s.quantity, s.unit_price
FROM tmp_order_seed s
JOIN customer_order o
  ON o.placed_at = s.placed_at
 AND o.customer_account_id = s.customer_account_id
 AND o.delivery_address = s.delivery_address;

-- POPULATING "REVIEW" TABLE
-- First 20 orders receive 5-star driver ratings; other ratings vary.
INSERT INTO review (order_id, restaurant_rating, driver_rating, comment, created_at)
SELECT
    o.order_id,
    CASE WHEN s.seed_no <= 100 THEN 5
         WHEN s.seed_no % 11 = 0 THEN 1
         WHEN s.seed_no % 9 = 0 THEN 2
         ELSE 4 END,
    CASE WHEN s.seed_no <= 120 THEN 5
         WHEN s.seed_no % 10 = 0 THEN 3
         ELSE 4 END,
    'Review for test order ' || s.seed_no,
    s.delivered_at + INTERVAL '1 hour'
FROM tmp_order_seed s
JOIN customer_order o
  ON o.placed_at = s.placed_at
 AND o.customer_account_id = s.customer_account_id
 AND o.delivery_address = s.delivery_address
WHERE s.status = 'delivered';

-- POPULATING "DRIVER_LOCATION" TABLE
-- Only drivers who have consented to location sharing.
INSERT INTO driver_location (driver_account_id, latitude, longitude, location_time)
SELECT
    d.driver_account_id,
    ROUND((38.70 + (d.driver_account_id % 20) * 0.002)::NUMERIC, 6),
    ROUND((-9.15 + (d.driver_account_id % 20) * 0.002)::NUMERIC, 6),
    CURRENT_TIMESTAMP - (g.i * INTERVAL '10 minutes')
FROM driver_account d
CROSS JOIN generate_series(1, 3) AS g(i)
WHERE d.location_sharing_consent = TRUE;


COMMIT;


SELECT * FROM order_item;
SELECT * FROM review;
SELECT COUNT(*) FROM driver_location;

