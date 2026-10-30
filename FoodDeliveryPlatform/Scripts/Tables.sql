CREATE TABLE account (
    account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    account_type VARCHAR(10) NOT NULL
        CHECK (account_type IN ('customer', 'driver', 'restaurant')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customer_account (
    customer_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id),
    full_name VARCHAR(100) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    nif CHAR(9) CHECK (nif ~ '^[0-9]{9}$'),
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE driver_account (
    driver_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id),
    full_name VARCHAR(100) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    availability VARCHAR(10) NOT NULL DEFAULT 'offline'
        CHECK (availability IN ('available', 'busy', 'offline')),
    location_sharing_consent BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE restaurant_account (
    restaurant_account_id INTEGER PRIMARY KEY
        REFERENCES account(account_id),
    telephone VARCHAR(20) NOT NULL,
    company_name VARCHAR(100) NOT NULL,
    nif CHAR(9) NOT NULL CHECK (nif ~ '^[0-9]{9}$')
);