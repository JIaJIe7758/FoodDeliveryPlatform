

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

--POPULATING ""

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

--POPULATING "FOOD_TYPE" TABLE
INSERT INTO



