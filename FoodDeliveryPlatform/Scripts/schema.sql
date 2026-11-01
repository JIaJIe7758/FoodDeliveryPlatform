-- =====================================================================
-- IBD 26/27 - D2 - Food Delivery Platform
-- schema.sql : complete database schema (tables, constraints, indexes, triggers)
-- DBMS       : PostgreSQL (version 13+)
-- Run with   : psql -d <database> -f schema.sql   (or Alt+X in DBeaver)
--              The script can be re-run: it drops everything first.
-- =====================================================================

-- =====================================================================
-- 0. CLEAN UP (reverse order of dependencies, safe to re-run)
-- =====================================================================
drop table if exists order_status_history cascade;
drop table if exists review               cascade;
drop table if exists driver_location      cascade;
drop table if exists order_item           cascade;
drop table if exists customer_order       cascade;
drop table if exists promotion            cascade;
drop table if exists menu_item            cascade;
drop table if exists restaurant           cascade;
drop table if exists food_type            cascade;
drop table if exists payment_method       cascade;
drop table if exists address              cascade;
drop table if exists restaurant_account   cascade;
drop table if exists driver_account       cascade;
drop table if exists customer_account     cascade;
drop table if exists account              cascade;

drop function if exists fn_profile_account_type()         cascade;
drop function if exists fn_customer_order_before()        cascade;
drop function if exists fn_order_item_before()            cascade;
drop function if exists fn_order_item_recalc()            cascade;
drop function if exists fn_customer_order_status_history() cascade;
drop function if exists fn_review_before()                cascade;
drop function if exists fn_driver_location_before()       cascade;


-- =====================================================================
-- 1. USER ACCESS
-- =====================================================================

-- Login data shared by every user.
create table account (
    account_id    integer generated always as identity,
    email         varchar(255) not null,
    password      varchar(255) not null,            -- always a hash
    account_type  varchar(10)  not null,
    created_at    timestamp    not null default current_timestamp,
    constraint pk_account primary key (account_id),
    constraint uq_account_email unique (email),
    constraint ck_account_type check (account_type in ('customer', 'driver', 'restaurant'))
);

-- Specialization of account (disjoint): each profile shares the primary key
-- of account. Trigger trg_*_account_type (section 3) guarantees that the
-- account has the matching type (e.g. a customer_account can only point to
-- an account whose account_type is 'customer').
-- Insert order: first the row in account, then the profile with the same id.

create table customer_account (
    customer_account_id integer      primary key
        references account (account_id) on delete cascade,
    full_name           varchar(100) not null,
    telephone           varchar(20)  not null,
    nif                 char(9),                     -- optional
    marketing_consent   boolean      not null default false,
    constraint uq_customer_account_nif unique (nif),
    constraint ck_customer_account_nif check (nif ~ '^[0-9]{9}$')
);

create table driver_account (
    driver_account_id        integer      primary key
        references account (account_id) on delete cascade,
    full_name                varchar(100) not null,
    telephone                varchar(20)  not null,
    vehicle_type             varchar(20)  not null,
    availability             varchar(10)  not null default 'offline',
    location_sharing_consent boolean      not null default false,
    constraint ck_driver_availability check (availability in ('available', 'busy', 'offline'))
);

create table restaurant_account (
    restaurant_account_id integer      primary key
        references account (account_id) on delete cascade,
    telephone             varchar(20)  not null,
    company_name          varchar(100) not null,
    nif                   char(9)      not null,
    constraint uq_restaurant_account_nif unique (nif),
    constraint ck_restaurant_account_nif check (nif ~ '^[0-9]{9}$')
);

-- Delivery addresses a customer keeps for future orders.
create table address (
    address_id          integer generated always as identity primary key,
    customer_account_id integer      not null
        references customer_account (customer_account_id) on delete cascade,
    street              varchar(150) not null,
    postal_code         char(8)      not null,
    city                varchar(60)  not null,
    latitude            numeric(9,6) not null,
    longitude           numeric(9,6) not null,
    constraint ck_address_postal check (postal_code ~ '^[0-9]{4}-[0-9]{3}$'),
    constraint ck_address_lat check (latitude  between -90  and 90),
    constraint ck_address_lon check (longitude between -180 and 180)
);

-- Payment methods are stored only as a token issued by the payment provider.
create table payment_method (
    payment_method_id   integer generated always as identity primary key,
    customer_account_id integer      not null
        references customer_account (customer_account_id) on delete cascade,
    type                varchar(10)  not null,
    provider_token      varchar(255) not null,
    display_label       varchar(50)  not null,
    constraint ck_payment_method_type check (type in ('card', 'mbway')),
    -- lets orders reference (method, customer) and prove ownership
    constraint uq_payment_method_owner unique (payment_method_id, customer_account_id)
);


-- =====================================================================
-- 2. RESTAURANTS, MENUS, PROMOTIONS, ORDERS AND REVIEWS
-- =====================================================================

create table food_type (
    food_type_id integer generated always as identity primary key,
    name         varchar(50) not null unique
);

create table restaurant (
    restaurant_id         integer generated always as identity primary key,
    restaurant_account_id integer      not null
        references restaurant_account (restaurant_account_id) on delete restrict,
    food_type_id          integer      not null
        references food_type (food_type_id),
    name                  varchar(100) not null,
    telephone             varchar(20)  not null,
    street                varchar(150) not null,
    postal_code           char(8)      not null,
    city                  varchar(60)  not null,
    latitude              numeric(9,6) not null,
    longitude             numeric(9,6) not null,
    delivery_fee          numeric(6,2) not null default 0,
    status                varchar(10)  not null default 'active',
    constraint ck_restaurant_postal check (postal_code ~ '^[0-9]{4}-[0-9]{3}$'),
    constraint ck_restaurant_lat check (latitude  between -90  and 90),
    constraint ck_restaurant_lon check (longitude between -180 and 180),
    constraint ck_restaurant_fee check (delivery_fee >= 0),
    constraint ck_restaurant_status check (status in ('active', 'inactive'))
);

create table menu_item (
    menu_item_id  integer generated always as identity primary key,
    restaurant_id integer      not null
        references restaurant (restaurant_id) on delete restrict,
    name          varchar(100) not null,
    category      varchar(50)  not null,
    price         numeric(8,2) not null,
    is_available  boolean      not null default true,
    constraint ck_menu_item_price check (price >= 0),
    constraint uq_menu_item_name unique (restaurant_id, name)
);

-- restaurant_id null = coupon valid on the whole platform
create table promotion (
    promotion_id  integer generated always as identity primary key,
    restaurant_id integer
        references restaurant (restaurant_id) on delete cascade,
    type          varchar(15)  not null,
    value         numeric(8,2) not null,
    coupon_code   varchar(30)  not null unique,
    start_date    date         not null,
    end_date      date         not null,
    constraint ck_promotion_type check (type in ('percentage', 'fixed-amount')),
    constraint ck_promotion_value check (value >= 0),
    constraint ck_promotion_percentage check (not (type = 'percentage' and value > 100)),
    constraint ck_promotion_dates check (end_date >= start_date)
);

create table customer_order (
    order_id            integer generated always as identity primary key,
    customer_account_id integer       not null
        references customer_account (customer_account_id),
    restaurant_id       integer       not null
        references restaurant (restaurant_id),
    driver_account_id   integer                          -- null until a driver is assigned
        references driver_account (driver_account_id),
    promotion_id        integer                          -- null when no coupon is used
        references promotion (promotion_id),
    payment_method_id   integer       not null,
    payment_status      varchar(10)   not null default 'pending',
    -- amounts are stored at purchase time; total_amount and discount_amount
    -- are kept up to date by trigger trg_order_item_recalc
    total_amount        numeric(10,2) not null default 0,
    delivery_fee        numeric(6,2)  not null,          -- copied from the restaurant if omitted
    delivery_address    varchar(255)  not null,          -- copy of the address at purchase time
    status              varchar(12)   not null default 'placed',
    placed_at           timestamp     not null default current_timestamp,
    delivered_at        timestamp,
    discount_amount     numeric(8,2)  not null default 0,
    constraint ck_co_payment_status check (payment_status in ('pending', 'failed', 'paid', 'refunded')),
    constraint ck_co_status check (status in
        ('placed', 'accepted', 'preparing', 'delivering', 'delivered', 'cancelled')),
    constraint ck_co_amounts check (total_amount >= 0 and delivery_fee >= 0 and discount_amount >= 0),
    -- a driver is assigned only after the restaurant accepts the order
    constraint ck_co_driver_after_accept check (driver_account_id is null or status <> 'placed'),
    -- delivering or delivered orders must have a driver
    constraint ck_co_driver_required check
        (status not in ('delivering', 'delivered') or driver_account_id is not null),
    -- delivered_at exists exactly when the order is delivered, and not before placed_at
    constraint ck_co_delivered_at check (delivered_at >= placed_at),
    constraint ck_co_delivered_consistent check ((status = 'delivered') = (delivered_at is not null)),
    -- the payment method must belong to the customer who placed the order
    constraint fk_co_payment_method foreign key (payment_method_id, customer_account_id)
        references payment_method (payment_method_id, customer_account_id)
);

-- N:M between customer_order and menu_item. unit_price is the price at purchase time.
create table order_item (
    order_id     integer      not null
        references customer_order (order_id) on delete cascade,
    menu_item_id integer      not null
        references menu_item (menu_item_id),
    quantity     integer      not null,
    unit_price   numeric(8,2) not null,
    primary key (order_id, menu_item_id),
    constraint ck_order_item_quantity check (quantity >= 1),
    constraint ck_order_item_price check (unit_price >= 0)
);

-- GPS readings of a driver.
create table driver_location (
    location_id       integer generated always as identity primary key,
    driver_account_id integer      not null
        references driver_account (driver_account_id) on delete cascade,
    latitude          numeric(9,6) not null,
    longitude         numeric(9,6) not null,
    location_time     timestamp    not null default current_timestamp,
    constraint ck_driver_location_lat check (latitude  between -90  and 90),
    constraint ck_driver_location_lon check (longitude between -180 and 180)
);

-- A review is written by the customer of the order (the customer is the one
-- in order_id). It rates the restaurant of the order and, if the order had a
-- driver, that driver.
create table review (
    review_id         integer generated always as identity primary key,
    order_id          integer      not null unique              -- one review per order
        references customer_order (order_id) on delete cascade,
    restaurant_rating smallint     not null,
    driver_rating     smallint,
    comment           varchar(500),
    created_at        timestamp    not null default current_timestamp,
    constraint ck_review_restaurant_rating check (restaurant_rating between 1 and 5),
    constraint ck_review_driver_rating check (driver_rating between 1 and 5)
);

-- History of status changes (status history of an order, cancellation analysis).
-- Filled automatically by trigger trg_customer_order_status_history.
create table order_status_history (
    history_id integer generated always as identity primary key,
    order_id   integer      not null
        references customer_order (order_id) on delete cascade,
    status     varchar(12)  not null,
    changed_at timestamp    not null default current_timestamp,
    constraint ck_osh_status check (status in
        ('placed', 'accepted', 'preparing', 'delivering', 'delivered', 'cancelled'))
);


-- =====================================================================
-- 2.1 INDEXES (foreign keys are not indexed automatically in PostgreSQL)
-- =====================================================================
create index idx_address_customer        on address (customer_account_id);
create index idx_payment_method_customer on payment_method (customer_account_id);
create index idx_restaurant_account      on restaurant (restaurant_account_id);
create index idx_restaurant_food_type    on restaurant (food_type_id);
create index idx_restaurant_city         on restaurant (city);
create index idx_menu_item_restaurant    on menu_item (restaurant_id);
create index idx_promotion_restaurant    on promotion (restaurant_id);
create index idx_co_customer             on customer_order (customer_account_id);
create index idx_co_driver               on customer_order (driver_account_id);
create index idx_co_restaurant           on customer_order (restaurant_id);
create index idx_co_status               on customer_order (status);
create index idx_order_item_menu_item    on order_item (menu_item_id);
create index idx_driver_location_time    on driver_location (driver_account_id, location_time);
create index idx_osh_order               on order_status_history (order_id);


-- =====================================================================
-- 3. TRIGGERS FOR COMPLEX BUSINESS RULES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1: profile tables match the account type
--   A customer_account can only be created for an account of type
--   'customer'; same for driver and restaurant. One generic function is used
--   by the three triggers: argument 1 = expected type, argument 2 = name of
--   the id column of the profile table.
-- ---------------------------------------------------------------------
create or replace function fn_profile_account_type()
returns trigger as $$
declare
    v_id   integer;
    v_type varchar(10);
begin
    v_id := (to_jsonb(new) ->> tg_argv[1])::integer;
    select account_type into v_type from account where account_id = v_id;

    if v_type is distinct from tg_argv[0] then
        raise exception 'Account % has type %, expected %', v_id, v_type, tg_argv[0];
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_customer_account_type
    before insert or update on customer_account
    for each row execute function fn_profile_account_type('customer', 'customer_account_id');

create trigger trg_driver_account_type
    before insert or update on driver_account
    for each row execute function fn_profile_account_type('driver', 'driver_account_id');

create trigger trg_restaurant_account_type
    before insert or update on restaurant_account
    for each row execute function fn_profile_account_type('restaurant', 'restaurant_account_id');


-- ---------------------------------------------------------------------
-- Trigger 2: validations on customer_order
--   * a new order can only be placed in an active restaurant
--   * delivery_fee is copied from the restaurant when not provided
--   * the coupon must belong to the restaurant (or be platform-wide)
--     and be valid on the order date
--   * status follows placed > accepted > preparing > delivering > delivered
--     and can be cancelled only before the driver picks up the order
--   * a driver has at most one active order at a time
--   * delivered_at is filled automatically when the order is delivered
-- ---------------------------------------------------------------------
create or replace function fn_customer_order_before()
returns trigger as $$
declare
    v_rest_status varchar(10);
    v_rest_fee    numeric(6,2);
    v_promo_rest  integer;
    v_start       date;
    v_end         date;
begin
    if tg_op = 'INSERT' then
        select status, delivery_fee into v_rest_status, v_rest_fee
          from restaurant where restaurant_id = new.restaurant_id;

        -- the "active restaurant" rule applies when the order is being placed;
        -- historical orders (already delivered or cancelled) are not blocked
        if new.status = 'placed' and v_rest_status <> 'active' then
            raise exception 'Restaurant % is not active: order cannot be placed', new.restaurant_id;
        end if;

        if new.delivery_fee is null then
            new.delivery_fee := v_rest_fee;
        end if;
    else
        if new.status is distinct from old.status then
            if not (
                (old.status = 'placed'     and new.status in ('accepted',   'cancelled')) or
                (old.status = 'accepted'   and new.status in ('preparing',  'cancelled')) or
                (old.status = 'preparing'  and new.status in ('delivering', 'cancelled')) or
                (old.status = 'delivering' and new.status = 'delivered')
            ) then
                raise exception 'Invalid status change for order %: % -> %',
                    old.order_id, old.status, new.status;
            end if;

            if new.status = 'delivered' and new.delivered_at is null then
                new.delivered_at := current_timestamp;
            end if;
        end if;
    end if;

    -- coupon: right restaurant and valid on the day the order was placed
    if new.promotion_id is not null
       and (tg_op = 'INSERT' or new.promotion_id is distinct from old.promotion_id) then
        select restaurant_id, start_date, end_date into v_promo_rest, v_start, v_end
          from promotion where promotion_id = new.promotion_id;

        if v_promo_rest is not null and v_promo_rest <> new.restaurant_id then
            raise exception 'Coupon % belongs to another restaurant', new.promotion_id;
        end if;
        if new.placed_at::date < v_start or new.placed_at::date > v_end then
            raise exception 'Coupon % is not valid on %', new.promotion_id, new.placed_at::date;
        end if;
    end if;

    -- one active order per driver
    if new.driver_account_id is not null
       and new.status in ('accepted', 'preparing', 'delivering')
       and (tg_op = 'INSERT'
            or new.driver_account_id is distinct from old.driver_account_id
            or new.status is distinct from old.status) then
        if exists (
            select 1 from customer_order o
             where o.driver_account_id = new.driver_account_id
               and o.status in ('accepted', 'preparing', 'delivering')
               and o.order_id <> new.order_id
        ) then
            raise exception 'Driver % already has an active order', new.driver_account_id;
        end if;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trg_customer_order_before
    before insert or update on customer_order
    for each row execute function fn_customer_order_before();


-- ---------------------------------------------------------------------
-- Trigger 3: validations on order_item
--   * the item must belong to the restaurant of the order
--   * an unavailable item cannot be added to an order that is being placed
--   * unit_price is copied from the menu when not provided
-- ---------------------------------------------------------------------
create or replace function fn_order_item_before()
returns trigger as $$
declare
    v_order_rest  integer;
    v_order_state varchar(12);
    v_item_rest   integer;
    v_item_price  numeric(8,2);
    v_item_avail  boolean;
begin
    select restaurant_id, status into v_order_rest, v_order_state
      from customer_order where order_id = new.order_id;
    select restaurant_id, price, is_available into v_item_rest, v_item_price, v_item_avail
      from menu_item where menu_item_id = new.menu_item_id;

    if v_item_rest <> v_order_rest then
        raise exception 'Menu item % does not belong to the restaurant of order %',
            new.menu_item_id, new.order_id;
    end if;

    if tg_op = 'INSERT' and v_order_state = 'placed' and not v_item_avail then
        raise exception 'Menu item % is not available', new.menu_item_id;
    end if;

    if new.unit_price is null then
        new.unit_price := v_item_price;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trg_order_item_before
    before insert or update on order_item
    for each row execute function fn_order_item_before();


-- ---------------------------------------------------------------------
-- Trigger 4: keeps the order amounts consistent
--   total_amount = sum(quantity * unit_price) + delivery_fee - discount_amount
--   The discount comes from the coupon of the order (percentage of the
--   items, or fixed amount never above the items value).
-- ---------------------------------------------------------------------
create or replace function fn_order_item_recalc()
returns trigger as $$
declare
    v_order    integer;
    v_subtotal numeric(10,2);
    v_discount numeric(8,2) := 0;
    v_type     varchar(15);
    v_value    numeric(8,2);
begin
    if tg_op = 'DELETE' then
        v_order := old.order_id;
    else
        v_order := new.order_id;
    end if;

    select coalesce(sum(quantity * unit_price), 0) into v_subtotal
      from order_item where order_id = v_order;

    select p.type, p.value into v_type, v_value
      from customer_order o join promotion p on p.promotion_id = o.promotion_id
     where o.order_id = v_order;

    if v_type = 'percentage' then
        v_discount := round(v_subtotal * v_value / 100, 2);
    elsif v_type = 'fixed-amount' then
        v_discount := least(v_value, v_subtotal);
    end if;

    update customer_order
       set discount_amount = v_discount,
           total_amount    = v_subtotal + delivery_fee - v_discount
     where order_id = v_order;

    return null;   -- AFTER trigger: return value is ignored
end;
$$ language plpgsql;

create trigger trg_order_item_recalc
    after insert or update or delete on order_item
    for each row execute function fn_order_item_recalc();


-- ---------------------------------------------------------------------
-- Trigger 5: status history
--   Every new order and every status change is recorded with its timestamp.
-- ---------------------------------------------------------------------
create or replace function fn_customer_order_status_history()
returns trigger as $$
begin
    if tg_op = 'INSERT' or new.status is distinct from old.status then
        insert into order_status_history (order_id, status)
        values (new.order_id, new.status);
    end if;
    return null;
end;
$$ language plpgsql;

create trigger trg_customer_order_status_history
    after insert or update of status on customer_order
    for each row execute function fn_customer_order_status_history();


-- ---------------------------------------------------------------------
-- Trigger 6: validations on review
--   * only delivered orders can be reviewed
--   * a driver rating only makes sense if the order had a driver
-- ---------------------------------------------------------------------
create or replace function fn_review_before()
returns trigger as $$
declare
    v_status varchar(12);
    v_driver integer;
begin
    select status, driver_account_id into v_status, v_driver
      from customer_order where order_id = new.order_id;

    if v_status <> 'delivered' then
        raise exception 'Order % is not delivered: it cannot be reviewed', new.order_id;
    end if;

    if new.driver_rating is not null and v_driver is null then
        raise exception 'Order % has no driver: driver_rating must be empty', new.order_id;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trg_review_before
    before insert or update on review
    for each row execute function fn_review_before();


-- ---------------------------------------------------------------------
-- Trigger 7: driver position
--   A position is stored only while the driver is online and has consented
--   to share the location.
-- ---------------------------------------------------------------------
create or replace function fn_driver_location_before()
returns trigger as $$
declare
    v_consent      boolean;
    v_availability varchar(10);
begin
    select location_sharing_consent, availability into v_consent, v_availability
      from driver_account where driver_account_id = new.driver_account_id;

    if not v_consent or v_availability = 'offline' then
        raise exception 'Driver % is offline or did not consent to share the location',
            new.driver_account_id;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trg_driver_location_before
    before insert on driver_location
    for each row execute function fn_driver_location_before();

