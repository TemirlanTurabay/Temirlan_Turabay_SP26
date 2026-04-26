BEGIN;

/*
Create a new user with the username "rentaluser" and the password "rentalpassword". Give the user the ability to connect to the database but no other permissions.
*/

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rentaluser') THEN
        CREATE ROLE rentaluser LOGIN PASSWORD 'rentalpassword';
        RAISE NOTICE 'Role rentaluser created.';
    ELSE
        ALTER ROLE rentaluser LOGIN PASSWORD 'rentalpassword';
        RAISE NOTICE 'Role rentaluser already existed; password reset.';
    END IF;
END$$;

REVOKE ALL PRIVILEGES ON DATABASE dvd_rental FROM rentaluser;
GRANT CONNECT ON DATABASE dvd_rental TO rentaluser;

/*
Grant "rentaluser" permission allows reading data from the "customer" table. Сheck to make sure this permission works correctly: write a SQL query to select all customers.
*/

GRANT USAGE ON SCHEMA public TO rentaluser;
GRANT SELECT ON TABLE public.customer TO rentaluser;

/*Successful access demonstration*/
SET ROLE rentaluser;
SELECT *
FROM public.customer
ORDER BY customer_id;
RESET ROLE;

/*Denied access demonstration*/
SAVEPOINT sp_denied_payment_select;
SET ROLE rentaluser;
SELECT *
FROM public.payment
LIMIT 1;
RESET ROLE;
ROLLBACK TO SAVEPOINT sp_denied_payment_select;
RELEASE SAVEPOINT sp_denied_payment_select;

/*
Create a new user group called "rental" and add "rentaluser" to the group. 
*/

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rental') THEN
        CREATE ROLE rental NOLOGIN;
        RAISE NOTICE 'Role rental created.';
    ELSE
        RAISE NOTICE 'Role rental already exists.';
    END IF;
END$$;

GRANT rental TO rentaluser;

/*
Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. Insert a new row and update one existing row in the "rental" table under that role. 
*/

GRANT USAGE ON SCHEMA public TO rental;
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;
GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;

/*One valid source row for demo values*/
DROP TABLE IF EXISTS pg_temp.rental_seed;
CREATE TEMP TABLE rental_seed AS
SELECT inventory_id, customer_id, staff_id
FROM public.rental
ORDER BY rental_id
LIMIT 1;

/*Successful INSERT under role rentaluser*/
SET ROLE rentaluser;
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT now(),
       inventory_id,
       customer_id,
       NULL,
       staff_id,
       now()
FROM rental_seed;
RESET ROLE;

/*Prepare exact rental_id for update demo*/
DROP TABLE IF EXISTS pg_temp.last_inserted_rental;
CREATE TEMP TABLE last_inserted_rental AS
SELECT max(rental_id) AS rental_id
FROM public.rental;

/*Successful UPDATE under role rentaluser*/
SET ROLE rentaluser;
UPDATE public.rental
SET return_date = now(),
    last_update = now()
WHERE rental_id = (SELECT rental_id FROM last_inserted_rental);
RESET ROLE;


/*
Revoke the "rental" group's INSERT permission for the "rental" table. Try to insert new rows into the "rental" table make sure this action is denied.
*/

REVOKE INSERT ON TABLE public.rental FROM rental;

/*Denied INSERT after revoke*/
SAVEPOINT sp_denied_rental_insert;
SET ROLE rentaluser;
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT now(),
       inventory_id,
       customer_id,
       NULL,
       staff_id,
       now()
FROM rental_seed;
RESET ROLE;
ROLLBACK TO SAVEPOINT sp_denied_rental_insert;
RELEASE SAVEPOINT sp_denied_rental_insert;

/*UPDATE*/
SET ROLE rentaluser;
UPDATE public.rental
SET last_update = now()
WHERE rental_id = (SELECT rental_id FROM last_inserted_rental);
RESET ROLE;


/*
Create a personalized role for any customer already existing in the dvd_rental database. The name of the role name must be client_{first_name}_{last_name} (omit curly brackets). The customer's payment and rental history must not be empty. 
*/

DROP TABLE IF EXISTS pg_temp.client_choice;
CREATE TEMP TABLE client_choice AS
SELECT c.customer_id,
       c.first_name,
       c.last_name,
       lower(
         'client_' ||
         regexp_replace(c.first_name, '[^a-zA-Z0-9]+', '_', 'g') || '_' ||
         regexp_replace(c.last_name,  '[^a-zA-Z0-9]+', '_', 'g')
       ) AS role_name
FROM public.customer c
WHERE EXISTS (SELECT 1 FROM public.rental  r WHERE r.customer_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM public.payment p WHERE p.customer_id = c.customer_id)
ORDER BY c.customer_id
LIMIT 1;

DO $$
DECLARE
    v_role_name text;
BEGIN
    SELECT role_name INTO v_role_name FROM client_choice;
    IF v_role_name IS NULL THEN
        RAISE EXCEPTION 'No customer with non-empty rental and payment history was found.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role_name) THEN
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', v_role_name, 'clientpassword');
        RAISE NOTICE 'Created personalized client role: %', v_role_name;
    ELSE
        EXECUTE format('ALTER ROLE %I LOGIN PASSWORD %L', v_role_name, 'clientpassword');
        RAISE NOTICE 'Personalized client role already existed, password reset: %', v_role_name;
    END IF;
END$$;

/*Store mapping in a dedicated security table*/
CREATE SCHEMA IF NOT EXISTS security;

CREATE TABLE IF NOT EXISTS security.customer_role_map (
    role_name   text PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES public.customer(customer_id)
);

INSERT INTO security.customer_role_map (role_name, customer_id)
SELECT role_name, customer_id
FROM client_choice
ON CONFLICT (role_name)
DO UPDATE SET customer_id = EXCLUDED.customer_id;

/*Give this client role permission only to read*/

DO $$
DECLARE
    v_role_name text;
BEGIN
    SELECT role_name INTO v_role_name FROM client_choice;
    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', v_role_name);
    EXECUTE format('GRANT USAGE ON SCHEMA security TO %I', v_role_name);
    EXECUTE format('GRANT SELECT ON public.rental TO %I', v_role_name);
    EXECUTE format('GRANT SELECT ON public.payment TO %I', v_role_name);
    EXECUTE format('GRANT SELECT ON security.customer_role_map TO %I', v_role_name);
END$$;

----------------------------------------------------------------------
-- 7. Row-level security configuration
----------------------------------------------------------------------

ALTER TABLE public.rental  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Recreate policies cleanly
DROP POLICY IF EXISTS rental_client_self ON public.rental;
DROP POLICY IF EXISTS payment_client_self ON public.payment;

CREATE POLICY rental_client_self
ON public.rental
FOR SELECT
USING (
    customer_id = (
        SELECT crm.customer_id
        FROM security.customer_role_map crm
        WHERE crm.role_name = current_user
    )
);

CREATE POLICY payment_client_self
ON public.payment
FOR SELECT
USING (
    customer_id = (
        SELECT crm.customer_id
        FROM security.customer_role_map crm
        WHERE crm.role_name = current_user
    )
);


/*Demonstrate allowed rows and denied/hidden rows for that client role*/

DO $$
DECLARE
    v_role_name text;
    v_customer_id integer;
    v_rental_count integer;
    v_payment_count integer;
BEGIN
    SELECT role_name, customer_id
    INTO v_role_name, v_customer_id
    FROM client_choice;

    EXECUTE format('SET ROLE %I', v_role_name);

    EXECUTE 'SELECT count(*) FROM public.rental'  INTO v_rental_count;
    EXECUTE 'SELECT count(*) FROM public.payment' INTO v_payment_count;

    RAISE NOTICE 'Client role % mapped to customer_id % sees rental rows: % and payment rows: %',
                 v_role_name, v_customer_id, v_rental_count, v_payment_count;

    EXECUTE 'RESET ROLE';
END$$;

/*Actual visible rows for the client role*/
SET ROLE (SELECT role_name FROM client_choice);
SELECT rental_id, rental_date, inventory_id, customer_id, return_date, staff_id
FROM public.rental
ORDER BY rental_id
LIMIT 10;

SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date
FROM public.payment
ORDER BY payment_id
LIMIT 10;

RESET ROLE;

/*Find role name*/
SELECT role_name FROM client_choice;

/*Denied,hidden records direct query should return zero rows*/
SET ROLE client_mary_smith;

SELECT rental_id, rental_date, inventory_id, customer_id, return_date, staff_id
FROM public.rental
WHERE customer_id <> (
    SELECT customer_id
    FROM security.customer_role_map
    WHERE role_name = current_user
)
LIMIT 10;

SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date
FROM public.payment
WHERE customer_id <> (
    SELECT customer_id
    FROM security.customer_role_map
    WHERE role_name = current_user
)
LIMIT 10;

RESET ROLE;

/*Find role name*/
SELECT role_name FROM client_choice;

/*Denied access to customer table*/
SAVEPOINT sp_denied_customer_select;
SET ROLE client_mary_smith;

SELECT *
FROM public.customer
LIMIT 1;

RESET ROLE;
ROLLBACK TO SAVEPOINT sp_denied_customer_select;
RELEASE SAVEPOINT sp_denied_customer_select;

/*Verification queris*/
SELECT rolname, rolcanlogin, rolinherit, rolconnlimit
FROM pg_roles
WHERE rolname IN ('rentaluser', 'rental')
   OR rolname IN (SELECT role_name FROM security.customer_role_map)
ORDER BY rolname;

SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rentaluser', 'rental')
   OR grantee IN (SELECT role_name FROM security.customer_role_map)
ORDER BY grantee, table_name, privilege_type;

SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('rental', 'payment')
ORDER BY tablename, policyname;
