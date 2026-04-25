DROP DATABASE IF EXISTS real_estate_db;
CREATE DATABASE real_estate_db
    ENCODING    = 'UTF8'
    LC_COLLATE  = 'en_US.UTF-8'
    LC_CTYPE    = 'en_US.UTF-8'
    TEMPLATE    = template0;

\connect real_estate_db

DROP SCHEMA IF EXISTS realty CASCADE;
CREATE SCHEMA realty;

SET search_path = realty;

CREATE TABLE agents (
    agent_id        SERIAL          PRIMARY KEY,
    first_name      VARCHAR(60)     NOT NULL,
    last_name       VARCHAR(60)     NOT NULL,

    email           VARCHAR(120)    NOT NULL UNIQUE,
    phone           VARCHAR(20)     NOT NULL,
    license_number  VARCHAR(30)     NOT NULL UNIQUE,

    commission_rate NUMERIC(5,4)    NOT NULL DEFAULT 0.0300,
    hire_date       DATE            NOT NULL DEFAULT CURRENT_DATE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,

    full_name       TEXT            GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,

    CONSTRAINT chk_agent_commission
        CHECK (commission_rate BETWEEN 0.0000 AND 0.2000),
    CONSTRAINT chk_agent_hire_date
        CHECK (hire_date >= DATE '2026-01-01')
);

CREATE TABLE neighborhoods (
    neighborhood_id SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL UNIQUE,
    city            VARCHAR(100)    NOT NULL,
    district        VARCHAR(100),

    avg_price_sqm   NUMERIC(12,2)   NOT NULL DEFAULT 0.00,

    CONSTRAINT chk_nbh_avg_price
        CHECK (avg_price_sqm >= 0)
);

CREATE TABLE clients (
    client_id       SERIAL          PRIMARY KEY,
    first_name      VARCHAR(60)     NOT NULL,
    last_name       VARCHAR(60)     NOT NULL,
    email           VARCHAR(120)    NOT NULL UNIQUE,
    phone           VARCHAR(20)     NOT NULL,

    client_role     VARCHAR(20)     NOT NULL DEFAULT 'buyer',
    registration_date DATE          NOT NULL DEFAULT CURRENT_DATE,

    full_name       TEXT            GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,

    CONSTRAINT chk_client_role
        CHECK (client_role IN ('buyer','seller','landlord','tenant')),
    CONSTRAINT chk_client_reg_date
        CHECK (registration_date >= DATE '2026-01-01')
);

CREATE TABLE properties (
    property_id     SERIAL          PRIMARY KEY,
    neighborhood_id INT             NOT NULL REFERENCES neighborhoods(neighborhood_id),
    agent_id        INT             NOT NULL REFERENCES agents(agent_id),
    address         VARCHAR(255)    NOT NULL,
    property_type   VARCHAR(30)     NOT NULL DEFAULT 'apartment',

    status          VARCHAR(20)     NOT NULL DEFAULT 'available',
    bedrooms        SMALLINT        NOT NULL DEFAULT 1,
    bathrooms       SMALLINT        NOT NULL DEFAULT 1,
    area_sqm        NUMERIC(10,2)   NOT NULL,

    listing_price   NUMERIC(14,2)   NOT NULL,
    listing_date    DATE            NOT NULL DEFAULT CURRENT_DATE,
    description     TEXT,

    price_per_sqm   NUMERIC(12,2)   GENERATED ALWAYS AS (listing_price / NULLIF(area_sqm,0)) STORED,

    CONSTRAINT chk_prop_type
        CHECK (property_type IN ('apartment','house','villa','office','land','commercial')),
    CONSTRAINT chk_prop_status
        CHECK (status IN ('available','reserved','sold','rented','withdrawn')),
    CONSTRAINT chk_prop_area
        CHECK (area_sqm > 0),
    CONSTRAINT chk_prop_price
        CHECK (listing_price > 0),
    CONSTRAINT chk_prop_listing_date
        CHECK (listing_date >= DATE '2026-01-01'),
    CONSTRAINT chk_prop_bedrooms
        CHECK (bedrooms >= 0),
    CONSTRAINT chk_prop_bathrooms
        CHECK (bathrooms >= 0)
);

CREATE TABLE transactions (
    transaction_id  SERIAL          PRIMARY KEY,
    property_id     INT             NOT NULL REFERENCES properties(property_id),
    agent_id        INT             NOT NULL REFERENCES agents(agent_id),

    client_id       INT             NOT NULL REFERENCES clients(client_id),
    transaction_type VARCHAR(10)    NOT NULL DEFAULT 'sale',

    agreed_price    NUMERIC(14,2)   NOT NULL,
    transaction_date DATE           NOT NULL DEFAULT CURRENT_DATE,

    commission_amount NUMERIC(14,2) GENERATED ALWAYS AS (
                        agreed_price * 0.0300
                      ) STORED,
    notes           TEXT,

    CONSTRAINT chk_txn_type
        CHECK (transaction_type IN ('sale','rental')),
    CONSTRAINT chk_txn_price
        CHECK (agreed_price > 0),
    CONSTRAINT chk_txn_date
        CHECK (transaction_date >= DATE '2026-01-01')
);

CREATE TABLE property_images (
    image_id        SERIAL          PRIMARY KEY,
    property_id     INT             NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    image_url       VARCHAR(500)    NOT NULL,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    uploaded_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_img_url_notempty
        CHECK (TRIM(image_url) <> '')
);

CREATE TABLE market_data (
    market_data_id  SERIAL          PRIMARY KEY,
    neighborhood_id INT             NOT NULL REFERENCES neighborhoods(neighborhood_id),
    record_date     DATE            NOT NULL DEFAULT CURRENT_DATE,
    avg_sale_price  NUMERIC(14,2)   NOT NULL,
    avg_rent_price  NUMERIC(10,2)   NOT NULL,
    listings_count  INT             NOT NULL DEFAULT 0,
    sold_count      INT             NOT NULL DEFAULT 0,

    CONSTRAINT uq_market_nbh_date
        UNIQUE (neighborhood_id, record_date),

    CONSTRAINT chk_mkt_avg_sale
        CHECK (avg_sale_price >= 0),
    CONSTRAINT chk_mkt_avg_rent
        CHECK (avg_rent_price >= 0),
    CONSTRAINT chk_mkt_listings
        CHECK (listings_count >= 0),
    CONSTRAINT chk_mkt_sold
        CHECK (sold_count >= 0),
    CONSTRAINT chk_mkt_date
        CHECK (record_date >= DATE '2026-01-01')
);

CREATE TABLE client_property (
    client_id       INT             NOT NULL REFERENCES clients(client_id),
    property_id     INT             NOT NULL REFERENCES properties(property_id),
    interaction_type VARCHAR(20)    NOT NULL DEFAULT 'viewed',
    interaction_date DATE           NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (client_id, property_id),

    CONSTRAINT chk_cp_type
        CHECK (interaction_type IN ('viewed','saved','offered','inspected')),
    CONSTRAINT chk_cp_date
        CHECK (interaction_date >= DATE '2026-01-01')
);

ALTER TABLE agents
    ADD CONSTRAINT chk_agent_phone_length
        CHECK (LENGTH(TRIM(phone)) >= 7);

ALTER TABLE clients
    ADD CONSTRAINT chk_client_phone_length
        CHECK (LENGTH(TRIM(phone)) >= 7);

ALTER TABLE agents
    ADD CONSTRAINT chk_agent_license_notempty
        CHECK (TRIM(license_number) <> '');

ALTER TABLE transactions
    ADD CONSTRAINT chk_txn_price_cap
        CHECK (agreed_price <= 1000000000);

ALTER TABLE properties
    ADD CONSTRAINT chk_prop_area_cap
        CHECK (area_sqm <= 100000);

INSERT INTO neighborhoods (name, city, district, avg_price_sqm) VALUES
    ('Almaty Heights',    'Almaty',  'Bostandyq',    850.00),
    ('Astana Central',    'Astana',  'Yesil',        920.00),
    ('Green Quarter',     'Almaty',  'Alatau',       710.00),
    ('Riverside Estate',  'Astana',  'Saryarka',     680.00),
    ('Old Town Core',     'Shymkent','Central',      540.00),
    ('Business District', 'Astana',  'Yesil',       1100.00);

INSERT INTO agents (first_name, last_name, email, phone, license_number, commission_rate, hire_date) VALUES
    ('Aizat',    'Bekova',    'aizat.bekova@realty.kz',   '+77011234567', 'KZ-RE-0001', 0.0300, '2026-01-15'),
    ('Daniyar',  'Seitkali',  'daniyar.seitkali@realty.kz','+77022345678','KZ-RE-0002', 0.0350, '2026-01-20'),
    ('Madina',   'Nurlan',    'madina.nurlan@realty.kz',  '+77033456789', 'KZ-RE-0003', 0.0300, '2026-02-01'),
    ('Ruslan',   'Akhmet',    'ruslan.akhmet@realty.kz',  '+77044567890', 'KZ-RE-0004', 0.0250, '2026-02-10'),
    ('Zarina',   'Dosova',    'zarina.dosova@realty.kz',  '+77055678901', 'KZ-RE-0005', 0.0400, '2026-03-01'),
    ('Timur',    'Kasymov',   'timur.kasymov@realty.kz',  '+77066789012', 'KZ-RE-0006', 0.0300, '2026-03-15');

INSERT INTO clients (first_name, last_name, email, phone, client_role, registration_date) VALUES
    ('Aigerim',  'Sultanova',  'aigerim.s@email.kz',   '+77111000001', 'buyer',    '2026-01-18'),
    ('Bolat',    'Dzhaksybekov','bolat.d@email.kz',    '+77111000002', 'seller',   '2026-01-22'),
    ('Gulnara',  'Isakova',    'gulnara.i@email.kz',   '+77111000003', 'tenant',   '2026-02-05'),
    ('Serik',    'Mambetov',   'serik.m@email.kz',     '+77111000004', 'buyer',    '2026-02-12'),
    ('Aliya',    'Dulatova',   'aliya.du@email.kz',    '+77111000005', 'landlord', '2026-02-20'),
    ('Nurbol',   'Yergaliyev', 'nurbol.y@email.kz',    '+77111000006', 'buyer',    '2026-03-03'),
    ('Diana',    'Pak',        'diana.p@email.kz',     '+77111000007', 'seller',   '2026-03-10'),
    ('Alibek',   'Zhumabayev', 'alibek.z@email.kz',    '+77111000008', 'tenant',   '2026-03-25');

INSERT INTO properties
    (neighborhood_id, agent_id, address, property_type, status, bedrooms, bathrooms, area_sqm, listing_price, listing_date, description)
VALUES
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Almaty Heights'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0001'),
     '12 Abai Ave, apt 34', 'apartment', 'available', 3, 2, 95.50,  45000000, '2026-01-20',
     'Bright 3-bed apartment with mountain view.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Astana Central'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0002'),
     '5 Mangilik El, unit 7', 'office', 'available', 0, 1, 120.00, 90000000, '2026-01-25',
     'Modern open-plan office in the heart of Astana.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Green Quarter'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0003'),
     '88 Rozybakiev St', 'house', 'reserved', 4, 3, 210.00, 78000000, '2026-02-03',
     'Spacious family house with private garden.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Riverside Estate'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0004'),
     '3 Kabanbay Batyr, apt 12', 'apartment', 'available', 2, 1, 68.00, 28000000, '2026-02-14',
     'Cozy 2-bed near the river.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Old Town Core'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0005'),
     '17 Al-Farabi St', 'commercial', 'available', 0, 2, 300.00, 55000000, '2026-02-28',
     'Ground-floor retail unit on busy street.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Business District'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0006'),
     '1 Expo Blvd, tower B', 'office', 'available', 0, 1, 85.00,  72000000, '2026-03-05',
     'Premium A-class office space.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Almaty Heights'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0001'),
     '44 Dostyk Ave, apt 101', 'apartment', 'sold', 1, 1, 50.00,  22000000, '2026-03-10',
     'Studio apartment, fully renovated.'),

    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Astana Central'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0002'),
     '9 Turan Ave, villa 2', 'villa', 'available', 5, 4, 450.00, 200000000, '2026-04-01',
     'Luxury villa with indoor pool and smart home system.');

INSERT INTO transactions (property_id, agent_id, client_id, transaction_type, agreed_price, transaction_date, notes)
VALUES
    ((SELECT property_id FROM properties WHERE address='44 Dostyk Ave, apt 101'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0001'),
     (SELECT client_id FROM clients WHERE email='aigerim.s@email.kz'),
     'sale', 21500000, '2026-03-20', 'Quick sale; buyer paid cash.'),

    ((SELECT property_id FROM properties WHERE address='88 Rozybakiev St'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0003'),
     (SELECT client_id FROM clients WHERE email='serik.m@email.kz'),
     'sale', 77000000, '2026-04-05', 'Price negotiated down 1.3%.'),

    ((SELECT property_id FROM properties WHERE address='3 Kabanbay Batyr, apt 12'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0004'),
     (SELECT client_id FROM clients WHERE email='gulnara.i@email.kz'),
     'rental', 1800000, '2026-02-20', 'Annual rental agreement.'),

    ((SELECT property_id FROM properties WHERE address='17 Al-Farabi St'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0005'),
     (SELECT client_id FROM clients WHERE email='nurbol.y@email.kz'),
     'sale', 54000000, '2026-03-30', 'Commercial property sold to retailer.'),

    ((SELECT property_id FROM properties WHERE address='12 Abai Ave, apt 34'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0001'),
     (SELECT client_id FROM clients WHERE email='bolat.d@email.kz'),
     'sale', 44800000, '2026-04-10', 'Seller agreed to minor discount.'),

    ((SELECT property_id FROM properties WHERE address='1 Expo Blvd, tower B'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0006'),
     (SELECT client_id FROM clients WHERE email='alibek.z@email.kz'),
     'rental', 4500000, '2026-04-12', 'Short-term office rental 6 months.'),

    ((SELECT property_id FROM properties WHERE address='5 Mangilik El, unit 7'),
     (SELECT agent_id FROM agents WHERE license_number='KZ-RE-0002'),
     (SELECT client_id FROM clients WHERE email='diana.p@email.kz'),
     'sale', 89000000, '2026-04-20', 'Sold to tech startup.');

INSERT INTO property_images (property_id, image_url, is_primary) VALUES
    ((SELECT property_id FROM properties WHERE address='12 Abai Ave, apt 34'),
     'https://cdn.realty.kz/props/abai34_main.jpg', TRUE),
    ((SELECT property_id FROM properties WHERE address='12 Abai Ave, apt 34'),
     'https://cdn.realty.kz/props/abai34_kitchen.jpg', FALSE),
    ((SELECT property_id FROM properties WHERE address='88 Rozybakiev St'),
     'https://cdn.realty.kz/props/roz88_front.jpg', TRUE),
    ((SELECT property_id FROM properties WHERE address='9 Turan Ave, villa 2'),
     'https://cdn.realty.kz/props/turan_villa_aerial.jpg', TRUE),
    ((SELECT property_id FROM properties WHERE address='1 Expo Blvd, tower B'),
     'https://cdn.realty.kz/props/expo1_lobby.jpg', TRUE),
    ((SELECT property_id FROM properties WHERE address='5 Mangilik El, unit 7'),
     'https://cdn.realty.kz/props/mangilik5_open.jpg', TRUE);

INSERT INTO market_data (neighborhood_id, record_date, avg_sale_price, avg_rent_price, listings_count, sold_count)
VALUES
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Almaty Heights'),
     '2026-02-01', 44000000, 2200000, 12, 3),
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Astana Central'),
     '2026-02-01', 88000000, 4100000,  8, 2),
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Green Quarter'),
     '2026-03-01', 76000000, 1950000, 10, 4),
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Riverside Estate'),
     '2026-03-01', 27000000, 1700000, 15, 5),
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Old Town Core'),
     '2026-04-01', 52000000, 1200000,  9, 3),
    ((SELECT neighborhood_id FROM neighborhoods WHERE name='Business District'),
     '2026-04-01', 70000000, 4400000,  6, 1);

INSERT INTO client_property (client_id, property_id, interaction_type, interaction_date) VALUES
    ((SELECT client_id FROM clients WHERE email='aigerim.s@email.kz'),
     (SELECT property_id FROM properties WHERE address='12 Abai Ave, apt 34'),
     'viewed', '2026-01-25'),
    ((SELECT client_id FROM clients WHERE email='aigerim.s@email.kz'),
     (SELECT property_id FROM properties WHERE address='44 Dostyk Ave, apt 101'),
     'offered', '2026-03-15'),
    ((SELECT client_id FROM clients WHERE email='serik.m@email.kz'),
     (SELECT property_id FROM properties WHERE address='88 Rozybakiev St'),
     'inspected', '2026-03-10'),
    ((SELECT client_id FROM clients WHERE email='serik.m@email.kz'),
     (SELECT property_id FROM properties WHERE address='3 Kabanbay Batyr, apt 12'),
     'viewed', '2026-02-16'),
    ((SELECT client_id FROM clients WHERE email='nurbol.y@email.kz'),
     (SELECT property_id FROM properties WHERE address='17 Al-Farabi St'),
     'saved', '2026-03-05'),
    ((SELECT client_id FROM clients WHERE email='nurbol.y@email.kz'),
     (SELECT property_id FROM properties WHERE address='1 Expo Blvd, tower B'),
     'viewed', '2026-04-08'),
    ((SELECT client_id FROM clients WHERE email='gulnara.i@email.kz'),
     (SELECT property_id FROM properties WHERE address='3 Kabanbay Batyr, apt 12'),
     'inspected', '2026-02-18'),
    ((SELECT client_id FROM clients WHERE email='diana.p@email.kz'),
     (SELECT property_id FROM properties WHERE address='9 Turan Ave, villa 2'),
     'saved', '2026-04-03');

CREATE OR REPLACE FUNCTION realty.update_record(
    p_table     TEXT,
    p_pk_col    TEXT,
    p_pk_value  TEXT,
    p_col_name  TEXT,
    p_new_value TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM   information_schema.tables
        WHERE  table_schema = 'realty'
          AND  table_name   = p_table
    ) THEN
        RAISE EXCEPTION 'Table % does not exist in schema realty.', p_table;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM   information_schema.columns
        WHERE  table_schema = 'realty'
          AND  table_name   = p_table
          AND  column_name  = p_col_name
    ) THEN
        RAISE EXCEPTION 'Column % does not exist in table %.', p_col_name, p_table;
    END IF;

    EXECUTE format(
        'UPDATE realty.%I SET %I = $1 WHERE %I = $2',
        p_table, p_col_name, p_pk_col
    )
    USING p_new_value, p_pk_value;

    IF NOT FOUND THEN
        RAISE WARNING 'No row updated: table=%, pk_col=%, pk_value=%', p_table, p_pk_col, p_pk_value;
    ELSE
        RAISE NOTICE 'Updated realty.%.% where %=% → new value: %',
                     p_table, p_col_name, p_pk_col, p_pk_value, p_new_value;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION realty.add_transaction(
    p_property_address  TEXT,
    p_agent_license     TEXT,
    p_client_email      TEXT,
    p_transaction_type  VARCHAR(10)     DEFAULT 'sale',
    p_agreed_price      NUMERIC(14,2)   DEFAULT NULL,
    p_transaction_date  DATE            DEFAULT CURRENT_DATE,
    p_notes             TEXT            DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id   INT;
    v_agent_id      INT;
    v_client_id     INT;
    v_txn_id        INT;
BEGIN

    SELECT property_id INTO v_property_id
    FROM   realty.properties WHERE address = p_property_address;
    IF v_property_id IS NULL THEN
        RAISE EXCEPTION 'Property not found: %', p_property_address;
    END IF;

    SELECT agent_id INTO v_agent_id
    FROM   realty.agents WHERE license_number = p_agent_license;
    IF v_agent_id IS NULL THEN
        RAISE EXCEPTION 'Agent not found with license: %', p_agent_license;
    END IF;

    SELECT client_id INTO v_client_id
    FROM   realty.clients WHERE email = p_client_email;
    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Client not found: %', p_client_email;
    END IF;

    IF p_agreed_price IS NULL THEN
        SELECT listing_price INTO p_agreed_price
        FROM   realty.properties WHERE property_id = v_property_id;
    END IF;

    INSERT INTO realty.transactions
        (property_id, agent_id, client_id, transaction_type, agreed_price, transaction_date, notes)
    VALUES
        (v_property_id, v_agent_id, v_client_id, p_transaction_type, p_agreed_price, p_transaction_date, p_notes)
    RETURNING transaction_id INTO v_txn_id;

    RETURN format('Transaction #%s inserted successfully. Type: %s, Price: %s',
                  v_txn_id, p_transaction_type, p_agreed_price);
END;
$$;

CREATE OR REPLACE VIEW realty.vw_quarterly_analytics AS

WITH latest_quarter AS (
    SELECT DATE_TRUNC('quarter', MAX(transaction_date))::DATE AS q_start,
           (DATE_TRUNC('quarter', MAX(transaction_date)) + INTERVAL '3 months - 1 day')::DATE AS q_end
    FROM   realty.transactions
),
txn_base AS (
    SELECT
        t.transaction_date,
        t.transaction_type,
        t.agreed_price,
        t.commission_amount,
        t.notes,
        p.address           AS property_address,
        p.property_type,
        p.area_sqm,
        p.price_per_sqm,
        n.name              AS neighborhood,
        n.city,
        ag.full_name        AS agent_name,
        ag.license_number,
        cl.full_name        AS client_name,
        cl.client_role
    FROM   realty.transactions   t
    JOIN   realty.properties     p  ON p.property_id     = t.property_id
    JOIN   realty.neighborhoods  n  ON n.neighborhood_id = p.neighborhood_id
    JOIN   realty.agents         ag ON ag.agent_id        = t.agent_id
    JOIN   realty.clients        cl ON cl.client_id       = t.client_id
    JOIN   latest_quarter        lq ON t.transaction_date BETWEEN lq.q_start AND lq.q_end
)
SELECT
    transaction_date,
    transaction_type,
    property_address,
    property_type,
    neighborhood,
    city,
    area_sqm,
    price_per_sqm,
    agreed_price,
    ROUND(commission_amount, 2)     AS commission_amount,
    agent_name,
    license_number,
    client_name,
    client_role,
    notes
FROM txn_base
ORDER BY transaction_date DESC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'realty_manager') THEN

        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA realty FROM realty_manager';
        EXECUTE 'REVOKE USAGE ON SCHEMA realty FROM realty_manager';
        DROP ROLE realty_manager;
    END IF;
END;
$$;

CREATE ROLE realty_manager
    LOGIN
    PASSWORD 'Mgr@Realty2026!'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    VALID UNTIL '2027-01-01';

GRANT USAGE ON SCHEMA realty TO realty_manager;

GRANT SELECT ON ALL TABLES IN SCHEMA realty TO realty_manager;

ALTER DEFAULT PRIVILEGES IN SCHEMA realty
    GRANT SELECT ON TABLES TO realty_manager;

GRANT SELECT ON realty.vw_quarterly_analytics TO realty_manager;
