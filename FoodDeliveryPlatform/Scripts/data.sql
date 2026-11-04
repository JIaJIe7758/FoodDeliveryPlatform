

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


SELECT * FROM account;


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

SELECT * FROM customer_account ;

INSERT INTO restaurant_account (restaurant_account_id, telephone, company_name, nif)
SELECT 
	 account_id,
    '9' || LPAD(account_id::TEXT, 8, '0'),
    'Restaurant Company ' || account_id,
    LPAD(account_id::TEXT, 9, '0')
FROM account
WHERE account_type = 'restaurant';

SELECT * FROM restaurant_account;

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

SELECT * FROM driver_account;

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

SELECT * FROM address;

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

SELECT * FROM payment_method;

--POPULATING "FOOD_TYPE" TABLE
INSERT INTO food_type (name)
VALUES 
	('Portuguese'),
	('Italian'),
	('Chinese'),
	('Japanese'),
	('American');

SELECT * FROM food_type;

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

SELECT * FROM restaurant;

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

SELECT * FROM menu_item;

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

SELECT * FROM promotion;








