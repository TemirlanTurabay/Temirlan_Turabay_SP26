/*
Task 1
Choose your real top-3 favorite movies (released in different years, 
belong to different genres) and add them to the 'film' table 
(films with the title Film1, Film2, etc - will not be taken into 
account and grade will be reduced by 20%)
Fill in rental rates with 4.99, 9.99 and 19.99 and rental 
durations with 1, 2 and 3 weeks respectively.
*/

BEGIN;

INSERT INTO public.film (
    title,
    description,
    release_year,
    language_id,
    original_language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update
)
SELECT
    'The Wolf of Wall Street',
    'A New York stockbroker rises through excess, fraud, and greed before the consequences catch up with him.',
    2013,
    l.language_id,
    l.language_id,
    7,
    4.99,
    180,
    19.99,
    'R',
    CURRENT_DATE
FROM public.language AS l
WHERE LOWER(l.name) = LOWER('English')
  AND NOT EXISTS (
      SELECT 1
      FROM public.film AS f
      WHERE LOWER(f.title) = LOWER('The Wolf of Wall Street')
        AND f.release_year = 2013
  )
RETURNING film_id, title, release_year, last_update;

COMMIT;


BEGIN;

INSERT INTO public.film (
    title,
    description,
    release_year,
    language_id,
    original_language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update
)
SELECT
    'The Intouchables',
    'After a paragliding accident leaves him quadriplegic, a wealthy man hires an unlikely caregiver and an unexpected friendship changes both of their lives.',
    2011,
    l.language_id,
    l.language_id,
    14,
    9.99,
    112,
    19.99,
    'R',
    CURRENT_DATE
FROM public.language AS l
WHERE LOWER(l.name) = LOWER('French')
  AND NOT EXISTS (
      SELECT 1
      FROM public.film AS f
      WHERE LOWER(f.title) = LOWER('The Intouchables')
        AND f.release_year = 2011
  )
RETURNING film_id, title, release_year, last_update;

COMMIT;


BEGIN;

INSERT INTO public.film (
    title,
    description,
    release_year,
    language_id,
    original_language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update
)
SELECT
    'Interstellar',
    'A team of explorers travels through a wormhole in space in search of a new home for humanity.',
    2014,
    l.language_id,
    l.language_id,
    21,
    19.99,
    169,
    19.99,
    'PG-13',
    CURRENT_DATE
FROM public.language AS l
WHERE LOWER(l.name) = LOWER('English')
  AND NOT EXISTS (
      SELECT 1
      FROM public.film AS f
      WHERE LOWER(f.title) = LOWER('Interstellar')
        AND f.release_year = 2014
  )
RETURNING film_id, title, release_year, last_update;

COMMIT;

/*to check*/

SELECT
    f.film_id,
    f.title,
    f.release_year,
    l.name AS language,
    ol.name AS original_language,
    f.rental_duration,
    f.rental_rate,
    f.length,
    f.replacement_cost,
    f.rating,
    f.last_update
FROM public.film AS f
LEFT JOIN public.language AS l
    ON f.language_id = l.language_id
LEFT JOIN public.language AS ol
    ON f.original_language_id = ol.language_id
WHERE (LOWER(f.title) = LOWER('The Wolf of Wall Street') AND f.release_year = 2013)
   OR (LOWER(f.title) = LOWER('The Intouchables') AND f.release_year = 2011)
   OR (LOWER(f.title) = LOWER('Interstellar') AND f.release_year = 2014)
ORDER BY f.title;

/*to check duplicates*/

SELECT
    f.title,
    f.release_year,
    COUNT(*) AS record_count
FROM public.film AS f
WHERE (LOWER(f.title) = LOWER('The Wolf of Wall Street') AND f.release_year = 2013)
   OR (LOWER(f.title) = LOWER('The Intouchables') AND f.release_year = 2011)
   OR (LOWER(f.title) = LOWER('Interstellar') AND f.release_year = 2014)
GROUP BY f.title, f.release_year
ORDER BY f.title;


/*
Add the real actors who play leading roles in your favorite movies 
to the 'actor' and 'film_actor' tables (6 or more actors in total). 
Actors with the name Actor1, Actor2, etc - will not be taken into 
account and grade will be reduced by 20%. You must decide how to 
identify actors that already exist in the system and how to avoid 
duplicates
*/

BEGIN;

WITH actor_seed(film_title, first_name, last_name) AS (
    VALUES
        ('The Wolf of Wall Street', 'Leonardo', 'DiCaprio'),
        ('The Wolf of Wall Street', 'Jonah', 'Hill'),
        ('The Wolf of Wall Street', 'Margot', 'Robbie'),
        ('The Intouchables', 'Francois', 'Cluzet'),
        ('The Intouchables', 'Omar', 'Sy'),
        ('The Intouchables', 'Audrey', 'Fleurot'),
        ('Interstellar', 'Matthew', 'McConaughey'),
        ('Interstellar', 'Anne', 'Hathaway'),
        ('Interstellar', 'Jessica', 'Chastain')
),
insert_actors AS (
    INSERT INTO public.actor (first_name, last_name, last_update)
    SELECT DISTINCT
        s.first_name,
        s.last_name,
        CURRENT_DATE
    FROM actor_seed s
    WHERE NOT EXISTS (
        SELECT *
        FROM public.actor a
        WHERE LOWER(a.first_name) = LOWER(s.first_name)
          AND LOWER(a.last_name) = LOWER(s.last_name)
    )
    RETURNING actor_id, first_name, last_name
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT DISTINCT
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM actor_seed s
JOIN public.actor a
    ON LOWER(a.first_name) = LOWER(s.first_name)
   AND LOWER(a.last_name) = LOWER(s.last_name)
JOIN public.film f
    ON LOWER(f.title) = LOWER(s.film_title)
WHERE NOT EXISTS (
    SELECT *
    FROM film_actor fa
    WHERE fa.actor_id = a.actor_id
      AND fa.film_id = f.film_id
);

COMMIT;

/*to check actors*/

SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    a.last_update
FROM public.actor AS a
WHERE (a.first_name = 'Leonardo' AND a.last_name = 'DiCaprio')
   OR (a.first_name = 'Jonah' AND a.last_name = 'Hill')
   OR (a.first_name = 'Margot' AND a.last_name = 'Robbie')
   OR (a.first_name = 'Francois' AND a.last_name = 'Cluzet')
   OR (a.first_name = 'Omar' AND a.last_name = 'Sy')
   OR (a.first_name = 'Audrey' AND a.last_name = 'Fleurot')
   OR (a.first_name = 'Matthew' AND a.last_name = 'McConaughey')
   OR (a.first_name = 'Anne' AND a.last_name = 'Hathaway')
   OR (a.first_name = 'Jessica' AND a.last_name = 'Chastain')
ORDER BY a.last_name, a.first_name;

/*to check duplicates*/

SELECT
    a.first_name,
    a.last_name,
    COUNT(*) AS record_count
FROM public.actor AS a
WHERE (a.first_name = 'Leonardo' AND a.last_name = 'DiCaprio')
   OR (a.first_name = 'Jonah' AND a.last_name = 'Hill')
   OR (a.first_name = 'Margot' AND a.last_name = 'Robbie')
   OR (a.first_name = 'Francois' AND a.last_name = 'Cluzet')
   OR (a.first_name = 'Omar' AND a.last_name = 'Sy')
   OR (a.first_name = 'Audrey' AND a.last_name = 'Fleurot')
   OR (a.first_name = 'Matthew' AND a.last_name = 'McConaughey')
   OR (a.first_name = 'Anne' AND a.last_name = 'Hathaway')
   OR (a.first_name = 'Jessica' AND a.last_name = 'Chastain')
GROUP BY a.first_name, a.last_name
ORDER BY a.last_name, a.first_name;

/*to check film actors*/

SELECT
    f.title,
    a.first_name,
    a.last_name,
    fa.last_update
FROM public.film_actor AS fa
JOIN public.actor AS a
    ON fa.actor_id = a.actor_id
JOIN public.film AS f
    ON fa.film_id = f.film_id
WHERE (LOWER(f.title) = LOWER('The Wolf of Wall Street') AND (
          (a.first_name = 'Leonardo' AND a.last_name = 'DiCaprio')
       OR (a.first_name = 'Jonah' AND a.last_name = 'Hill')
       OR (a.first_name = 'Margot' AND a.last_name = 'Robbie')
))
   OR (LOWER(f.title) = LOWER('The Intouchables') AND (
          (a.first_name = 'Francois' AND a.last_name = 'Cluzet')
       OR (a.first_name = 'Omar' AND a.last_name = 'Sy')
       OR (a.first_name = 'Audrey' AND a.last_name = 'Fleurot')
))
   OR (LOWER(f.title) = LOWER('Interstellar') AND (
          (a.first_name = 'Matthew' AND a.last_name = 'McConaughey')
       OR (a.first_name = 'Anne' AND a.last_name = 'Hathaway')
       OR (a.first_name = 'Jessica' AND a.last_name = 'Chastain')
))
ORDER BY f.title, a.last_name, a.first_name;

/*to check duplicates of film actors*/

SELECT
    f.title,
    a.first_name,
    a.last_name,
    COUNT(*) AS record_count
FROM public.film_actor AS fa
JOIN public.actor AS a
    ON fa.actor_id = a.actor_id
JOIN public.film AS f
    ON fa.film_id = f.film_id
WHERE (LOWER(f.title) = LOWER('The Wolf of Wall Street') AND (
          (a.first_name = 'Leonardo' AND a.last_name = 'DiCaprio')
       OR (a.first_name = 'Jonah' AND a.last_name = 'Hill')
       OR (a.first_name = 'Margot' AND a.last_name = 'Robbie')
))
   OR (LOWER(f.title) = LOWER('The Intouchables') AND (
          (a.first_name = 'Francois' AND a.last_name = 'Cluzet')
       OR (a.first_name = 'Omar' AND a.last_name = 'Sy')
       OR (a.first_name = 'Audrey' AND a.last_name = 'Fleurot')
))
   OR (LOWER(f.title) = LOWER('Interstellar') AND (
          (a.first_name = 'Matthew' AND a.last_name = 'McConaughey')
       OR (a.first_name = 'Anne' AND a.last_name = 'Hathaway')
       OR (a.first_name = 'Jessica' AND a.last_name = 'Chastain')
))
GROUP BY f.title, a.first_name, a.last_name
ORDER BY f.title, a.last_name, a.first_name;

/*
Add your favorite movies to any store's inventory.
*/

BEGIN;

WITH random_store AS (
    SELECT store_id
    FROM public.store
    ORDER BY random()
    LIMIT 1
)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT
    f.film_id,
    rs.store_id,
    CURRENT_DATE
FROM public.film f
CROSS JOIN random_store rs
WHERE LOWER(f.title) IN (
    LOWER('The Wolf of Wall Street'),
    LOWER('The Intouchables'),
    LOWER('Interstellar')
)
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
      AND i.store_id = rs.store_id
);

COMMIT;

/*
Alter any existing customer in the database with at least 43 rental 
and 43 payment records. Change their personal data to yours 
(first name, last name, address, etc.). You can use any existing 
address from the "address" table. Please do not perform any updates 
on the "address" table, as this can impact multiple records with 
the same address.
*/

BEGIN;

WITH rental_counts AS (
    SELECT
        customer_id,
        COUNT(*) AS rental_count
    FROM public.rental
    GROUP BY customer_id
),
payment_counts AS (
    SELECT
        customer_id,
        COUNT(*) AS payment_count
    FROM public.payment
    GROUP BY customer_id
),
eligible_customer AS (
    SELECT c.customer_id
    FROM public.customer c
    JOIN rental_counts rc ON rc.customer_id = c.customer_id
    JOIN payment_counts pc ON pc.customer_id = c.customer_id
    WHERE rc.rental_count >= 43
      AND pc.payment_count >= 43
    ORDER BY c.customer_id
    LIMIT 1
),
chosen_address AS (
    SELECT address_id
    FROM public.address
    ORDER BY address_id
    LIMIT 1
)
UPDATE customer c
SET first_name  = 'Temirlan',                     
    last_name   = 'Turabay',                   
    email       = 'temirlan.turabay@nu.edu.kz', 
    address_id  = (SELECT address_id FROM chosen_address),
    last_update = CURRENT_DATE
WHERE c.customer_id = (SELECT customer_id FROM eligible_customer)
RETURNING c.customer_id, c.first_name, c.last_name, c.email, c.address_id;

COMMIT;

/*to check updates*/

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.address_id,
    c.last_update
FROM public.customer AS c
WHERE c.email = 'temirlan.turabay@nu.edu.kz';

/*to check duplicates*/

SELECT
    c.email,
    COUNT(*) AS record_count
FROM public.customer AS c
WHERE c.email = 'temirlan.turabay@nu.edu.kz'
GROUP BY c.email;

/*
Remove any records related to you (as a customer) from all 
tables except 'Customer' and 'Inventory'
*/

BEGIN;

DELETE FROM public.payment
WHERE customer_id = (
    SELECT c.customer_id
    FROM public.customer AS c
    WHERE c.email = 'temirlan.turabay@nu.edu.kz'
    LIMIT 1
)
RETURNING payment_id, customer_id, rental_id, amount;

DELETE FROM public.rental
WHERE customer_id = (
    SELECT c.customer_id
    FROM public.customer AS c
    WHERE c.email = 'temirlan.turabay@nu.edu.kz'
    LIMIT 1
)
RETURNING rental_id, customer_id, inventory_id, rental_date;

COMMIT;

/*to check*/

SELECT
    c.customer_id,
    c.email,
    (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) AS remaining_payments,
    (SELECT COUNT(*) FROM public.rental r WHERE r.customer_id = c.customer_id) AS remaining_rentals
FROM public.customer c
WHERE c.email = 'temirlan.turabay@nu.edu.kz';

/*
Rent you favorite movies from the store they are in and pay for them 
(add corresponding records to the database to represent this activity)
(Note: to insert the payment_date into the table payment, 
you can create a new partition (see the scripts to install the training
database ) or add records for the
first half of 2017)
*/

BEGIN;

WITH target_customer AS (
    SELECT customer_id
    FROM customer
    WHERE LOWER(email) = LOWER('temirlan.turabay@nu.edu.kz')
    LIMIT 1
),

favorite_candidates AS (
    SELECT *
    FROM (
        VALUES
            (1, 'The Wolf of Wall Street', 1, TIMESTAMPTZ '2017-06-10 10:00:00+00', TIMESTAMPTZ '2017-06-17 10:00:00+00', TIMESTAMPTZ '2017-06-10 10:05:00+00'),
            (2, 'The Intouchables', 1, TIMESTAMPTZ '2017-06-11 11:00:00+00', TIMESTAMPTZ '2017-06-25 11:00:00+00', TIMESTAMPTZ '2017-06-11 11:05:00+00'),
            (3, 'Interstellar', 1, TIMESTAMPTZ '2017-06-12 12:00:00+00', TIMESTAMPTZ '2017-07-03 12:00:00+00', TIMESTAMPTZ '2017-06-12 12:05:00+00')
    ) AS v(movie_no, title, priority, rental_date, return_date, payment_date)
)

picked_films AS (
    SELECT DISTINCT ON (fc.movie_no)
        fc.movie_no,
        f.film_id,
        fc.title,
        f.rental_rate,
        f.rental_duration,
        fc.rental_date,
        fc.return_date,
        fc.payment_date
    FROM favorite_candidates fc
    JOIN film f
      ON LOWER(f.title) = LOWER(fc.title)
    ORDER BY fc.movie_no, fc.priority
),

picked_inventory AS (
    SELECT
        pf.movie_no,
        pf.film_id,
        pf.title,
        pf.rental_rate,
        pf.rental_duration,
        pf.rental_date,
        pf.return_date,
        pf.payment_date,
        i.inventory_id,
        i.store_id,
        ROW_NUMBER() OVER (PARTITION BY pf.movie_no ORDER BY i.inventory_id) AS rn
    FROM picked_films pf
    JOIN public.inventory i
      ON i.film_id = pf.film_id
),

selected_inventory AS (
    SELECT
        movie_no,
        film_id,
        title,
        rental_rate,
        rental_duration,
        rental_date,
        return_date,
        payment_date,
        inventory_id,
        store_id
    FROM picked_inventory
    WHERE rn = 1
),

calculated_payments AS (
    SELECT
        si.movie_no,
        si.film_id,
        si.title,
        si.inventory_id,
        si.store_id,
        si.rental_date,
        si.return_date,
        si.payment_date,
        si.rental_rate,
        si.rental_duration,
        CEIL(EXTRACT(EPOCH FROM (si.return_date - si.rental_date)) / 86400.0) AS actual_days,
        CASE
            WHEN CEIL(EXTRACT(EPOCH FROM (si.return_date - si.rental_date)) / 86400.0) <= si.rental_duration
                THEN si.rental_rate
            ELSE
                si.rental_rate +
                (
                    CEIL(EXTRACT(EPOCH FROM (si.return_date - si.rental_date)) / 86400.0) - si.rental_duration
                ) * si.rental_rate
        END::numeric(5,2) AS amount
    FROM selected_inventory si
),

inserted_rentals AS (
    INSERT INTO rental (
        rental_date,
        inventory_id,
        customer_id,
        return_date,
        staff_id,
        last_update
    )
    SELECT
        cp.rental_date,
        cp.inventory_id,
        tc.customer_id,
        cp.return_date,
        (
            SELECT MIN(s.staff_id)
            FROM public.staff s
            WHERE s.store_id = cp.store_id
        ) AS staff_id,
        CURRENT_DATE
    FROM calculated_payments cp
    CROSS JOIN target_customer tc
    WHERE NOT EXISTS (
        SELECT 1
        FROM rental r
        WHERE r.inventory_id = cp.inventory_id
          AND r.customer_id = tc.customer_id
          AND r.rental_date = cp.rental_date
    )
    RETURNING rental_id, inventory_id, customer_id, staff_id
)

INSERT INTO public.payment (
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
)
SELECT
    ir.customer_id,
    ir.staff_id,
    ir.rental_id,
    cp.amount,
    cp.payment_date
FROM inserted_rentals ir
JOIN calculated_payments cp
  ON cp.inventory_id = ir.inventory_id;

COMMIT;

/*to check*/

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    f.title,
    r.rental_id,
    r.rental_date,
    r.return_date,
    r.inventory_id,
    r.staff_id,
    r.last_update,
    p.payment_id,
    p.amount,
    p.payment_date
FROM public.customer AS c
JOIN public.rental AS r
    ON r.customer_id = c.customer_id
JOIN public.inventory AS i
    ON i.inventory_id = r.inventory_id
JOIN public.film AS f
    ON f.film_id = i.film_id
LEFT JOIN public.payment AS p
    ON p.rental_id = r.rental_id
   AND p.customer_id = r.customer_id
WHERE c.email = 'temirlan.turabay@nu.edu.kz'
  AND LOWER(f.title) IN (
      LOWER('The Wolf of Wall Street'),
      LOWER('The Intouchables'),
      LOWER('Interstellar')
  )
ORDER BY r.rental_date, f.title;

/*
explanations:
For the actors part, the script uses a small seed list of real actor names and inserts only those actors who are not already in the actor table. After that, it connects actors to films through the film_actor table by joining actor names with the correct film title, so the many-to-many relationship between films and actors is created correctly. DISTINCT and NOT EXISTS help avoid duplicate actors and duplicate film-actor links.

For inventory, the script adds the three favorite movies to random store only if that exact film_id and store_id pair does not already exist. This means the relationship is built correctly through the film’s primary key, and duplicate inventory rows for the same store are avoided.

For the customer update, the script first finds a customer who already has at least 43 rentals and 43 payments, then updates only that one customer record. It uses an existing address_id from the address table instead of changing the address table itself, so the foreign key stays valid and no shared address records are accidentally modified.

For the delete part, the script removes records related to me only from payment and rental, while leaving customer and inventory unchanged as required. The deletion is safe because it deletes payments first and rentals second, which is the correct order when tables are related, so there is no foreign key problem and no unintended deletion from unrelated tables.

For the rental and payment part, the script first finds my customer record, then matches my favorite movies to real film records and real inventory records. It inserts rentals using existing inventory_id, customer_id, and staff_id, and then inserts payments using the rental_id returned from the rental insert, so the relationships are built correctly from film to inventory to rental to payment. It also prevents duplicate rentals by checking whether the same customer already rented the same inventory item at the same rental date.

A separate transaction is used for each logical step because it keeps every subtask isolated. This makes the script easier to control: if one part has an error, only that part fails, while the already committed parts from previous steps stay saved in the database.

If a transaction fails before COMMIT, its changes are not finalized. In that case, rollback is possible, and the database returns to the state it had before that transaction started. The data affected would only be the tables used inside that failed block, for example film, actor, film_actor, inventory, rental, or payment, depending on where the error happened.

Referential integrity is preserved because the script always uses valid keys from existing tables. It takes languages from language, addresses from address, staff from staff, film IDs from film, inventory IDs from inventory, and customer IDs from customer. Also, during deletion it removes child rows in payment before parent rows in rental, which keeps the references valid.

The script avoids duplicates in several ways. It uses NOT EXISTS before inserting films, actors, inventory rows, and rentals, and it also uses DISTINCT and DISTINCT ON when selecting records. In addition, there are check queries after the inserts to confirm that duplicate rows were not created.
*/