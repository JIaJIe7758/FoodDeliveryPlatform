BEGIN;

drop table if exists review cascade;
drop table if exists driver_location cascade;
drop table if exists order_item cascade;
drop table if exists customer_order cascade;
drop table if exists promotion cascade;
drop table if exists menu_item cascade;
drop table if exists restaurant cascade;
drop table if exists food_type cascade;
drop table if exists payment_method cascade;
drop table if exists address cascade;
drop table if exists restaurant_account cascade;
drop table if exists driver_account cascade;
drop table if exists customer_account cascade;
drop table if exists account cascade;


-- Centralizes authentication data shared by all account types.
-- Customer, driver and restaurant-specific attributes are stored
-- in separate tables to avoid unnecessary NULL values.
CREATE TABLE account (
    account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    account_type VARCHAR(10) NOT NULL
        CHECK (account_type IN ('customer', 'driver', 'restaurant')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Each profile uses the account_id as both its primary key
-- and foreign key, implementing a one-to-one relationship.
CREATE TABLE customer_account (
    customer_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id) ON DELETE CASCADE,
    full_name VARCHAR(100) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    nif CHAR(9) CHECK (nif ~ '^[0-9]{9}$'),
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE driver_account (
    driver_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id) ON DELETE CASCADE,
    full_name VARCHAR(100) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    availability VARCHAR(10) NOT NULL DEFAULT 'offline'
        CHECK (availability IN ('available', 'busy', 'offline')),
    location_sharing_consent BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE restaurant_account (
    restaurant_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id) ON DELETE CASCADE,
    telephone VARCHAR(20) NOT NULL,
    company_name VARCHAR(100) NOT NULL,
    nif CHAR(9) NOT NULL CHECK (nif ~ '^[0-9]{9}$')
);


-- A customer can register multiple delivery addresses.
CREATE TABLE address (
 address_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 customer_account_id integer NOT NULL REFERENCES customer_account(customer_account_id) ON DELETE CASCADE,
 street varchar(150) NOT NULL,
 postal_code char(8) NOT NULL CHECK (postal_code ~ '^[0-9]{4}-[0-9]{3}$'),
 city varchar(60) NOT NULL,
 latitude numeric(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude numeric(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE payment_method (
    payment_method_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_account_id integer NOT NULL REFERENCES customer_account(customer_account_id) ON DELETE CASCADE,
    type varchar(10) NOT NULL CHECK (type IN ('card', 'mbway')),
    provider_token varchar(255) NOT NULL,
    display_label varchar(50) NOT NULL
);

CREATE TABLE food_type (
 food_type_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name varchar(50) NOT NULL UNIQUE
);

-- Restaurant accounts are separated from physical restaurants,
-- allowing one account to manage multiple establishments.
CREATE TABLE restaurant (
 restaurant_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 restaurant_account_id integer NOT NULL REFERENCES restaurant_account(restaurant_account_id) ON DELETE RESTRICT,
 food_type_id integer NOT NULL REFERENCES food_type(food_type_id),
 name varchar(100) NOT NULL,
 telephone varchar(20) NOT NULL,
 street varchar(150) NOT NULL,
 postal_code char(8) NOT NULL CHECK (postal_code ~ '^[0-9]{4}-[0-9]{3}$'),
 city varchar(60) NOT NULL,
 latitude numeric(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude numeric(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
 delivery_fee numeric(6,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
 status varchar(10) NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive'))
);

CREATE TABLE menu_item (
 menu_item_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 restaurant_id integer NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
 name varchar(100) NOT NULL,
 category varchar(50) NOT NULL,
 price numeric(8,2) NOT NULL CHECK (price >= 0),
 is_available boolean NOT NULL DEFAULT true
);


-- Promotions can be restaurant-specific or platform-wide.
-- A NULL restaurant_id represents a platform-wide promotion.
-- Percentage discounts are limited to 100%.
CREATE TABLE promotion (
 promotion_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 restaurant_id integer REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
 type varchar(15) NOT NULL CHECK (type IN ('percentage','fixed-amount')),
 value numeric(8,2) NOT NULL CHECK (value >= 0),
 coupon_code varchar(30) NOT NULL UNIQUE,
 start_date date NOT NULL,
 end_date date NOT NULL,
 CHECK (end_date >= start_date),
 CHECK (NOT (type = 'percentage' AND value > 100))
);


-- Driver and promotion references are optional, as orders may be
-- placed without an assigned driver or an applied promotion.
CREATE TABLE customer_order (
 order_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 customer_account_id integer NOT NULL REFERENCES customer_account(customer_account_id),
 restaurant_id integer NOT NULL REFERENCES restaurant(restaurant_id),
 driver_account_id integer REFERENCES driver_account(driver_account_id),
 promotion_id integer REFERENCES promotion(promotion_id),
 payment_method_id integer NOT NULL REFERENCES payment_method(payment_method_id),
 payment_status varchar(10) NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending','failed','paid','refunded')),
 total_amount numeric(10,2) NOT NULL CHECK (total_amount >= 0),
 delivery_fee numeric(6,2) NOT NULL CHECK (delivery_fee >= 0),
 delivery_address varchar(255) NOT NULL,
 status varchar(12) NOT NULL DEFAULT 'placed' CHECK (status IN ('placed','accepted','preparing','delivering','delivered','cancelled')),
 placed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 delivered_at timestamp,
 discount_amount numeric(8,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
 CHECK (delivered_at >= placed_at),
 CHECK (NOT (status = 'delivered' AND delivered_at IS NULL))
);


-- Unit prices are stored separately from menu prices to preserve
-- the original price charged when an order was placed.
-- The composite primary key prevents duplicate menu items within the same order.
CREATE TABLE order_item (
 order_id integer NOT NULL REFERENCES customer_order(order_id) ON DELETE CASCADE,
 menu_item_id integer NOT NULL REFERENCES menu_item(menu_item_id),
 quantity integer NOT NULL CHECK (quantity >= 1),
 unit_price numeric(8,2) NOT NULL CHECK (unit_price >= 0),
 PRIMARY KEY (order_id, menu_item_id)
);

CREATE TABLE driver_location (
 location_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 driver_account_id integer NOT NULL REFERENCES driver_account(driver_account_id) ON DELETE CASCADE,
 latitude numeric(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude numeric(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
 location_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Each order can have at most one review, enforced by UNIQUE(order_id).
-- Driver ratings are optional because some orders may not have an assigned driver.
CREATE TABLE review (
 review_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 order_id integer NOT NULL UNIQUE REFERENCES customer_order(order_id) ON DELETE CASCADE,
 restaurant_rating smallint NOT NULL CHECK (restaurant_rating BETWEEN 1 AND 5),
 driver_rating smallint CHECK (driver_rating BETWEEN 1 AND 5),
 comment varchar(500),
 created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Additional business rules requiring cross-table validation
-- are implemented separately using triggers.


-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1: profile tables match the account type
--   *A customer_account can only be created for an account of type 'customer' same for "driver" and "restaurant"
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_profile_account_type()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    actual_type VARCHAR(10);
    account_id_value INTEGER;
BEGIN

    IF TG_TABLE_NAME = 'customer_account' THEN
        account_id_value := NEW.customer_account_id;

    ELSIF TG_TABLE_NAME = 'driver_account' THEN
        account_id_value := NEW.driver_account_id;

    ELSIF TG_TABLE_NAME = 'restaurant_account' THEN
        account_id_value := NEW.restaurant_account_id;

    END IF;

    SELECT account_type
    INTO actual_type
    FROM account
    WHERE account_id = account_id_value;

    IF actual_type IS DISTINCT FROM TG_ARGV[0] THEN
        RAISE EXCEPTION 'Account type must be %', TG_ARGV[0];
    END IF;

    RETURN NEW;

END;
$$;


-- ---------------------------------------------------------------------
-- Trigger 2: prevent multiple active orders per driver
--   * A driver can only have one active order at a time
--   * Active orders include accepted, preparing and delivering
--   * Delivered and cancelled orders do not count as active
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_driver_active_order()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.driver_account_id IS NOT NULL
       AND NEW.status IN ('accepted', 'preparing', 'delivering') THEN

        IF EXISTS (
            SELECT 1
            FROM customer_order
            WHERE driver_account_id = NEW.driver_account_id
              AND status IN ('accepted', 'preparing', 'delivering')
              AND order_id != NEW.order_id
        ) THEN
            RAISE EXCEPTION 'Driver already has an active order';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_driver_active_order
BEFORE INSERT OR UPDATE ON customer_order
FOR EACH ROW
EXECUTE FUNCTION check_driver_active_order();

COMMIT;

