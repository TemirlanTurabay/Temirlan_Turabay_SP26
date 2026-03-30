/*
Task 1.1
The marketing team needs a list of animation movies between 2017 and 2019 
to promote family-friendly content in an upcoming season in stores. 
Show all animation movies released during this period with rate more 
than 1, sorted alphabetically
*/

/*
Business logic:
I treated "animation movies" as films that are connected to the Animation category.
The INNER JOINs keep only rows that really match in film_category and category, so films
without a matching category row will not be shown.

Advantages and disadvantages:
This JOIN solution is simple and direct. It is usually fast because the database can solve
everything in one query block. The weak side is that JOINs can create extra rows in some
one-to-many cases, so the join path must be chosen carefully.

Production choice:
For this task I would use the JOIN version in production because it is the shortest,
clear, and easy to maintain.
*/
SELECT
    f.film_id,
    f.title,
    f.release_year,
    f.rental_rate
FROM public.film AS f
INNER JOIN public.film_category AS fc
    ON f.film_id = fc.film_id
INNER JOIN public.category AS c
    ON fc.category_id = c.category_id
WHERE UPPER(c.name) = 'ANIMATION'
AND f.release_year BETWEEN 2017 AND 2019
AND f.rental_rate > 1
ORDER BY
    f.title,
    f.film_id;

/*
Business logic:
Here I first filter films in the main query and then check whether the film_id exists
inside the Animation category set. The INNER JOIN inside the subquery keeps only real
category matches. The IN condition then keeps only those films in the outer query.

Advantages and disadvantages:
This version can feel natural because the category check is separated from the film filter.
But correlated or nested filters can be harder to read in biger tasks and on some systems
they may be less efficeint than a clean JOIN.

Production choice:
I would not choose this version first for production. It works, but the JOIN version is
shorter and more transparent for this task.
*/
SELECT
    f.film_id,
    f.title,
    f.release_year,
    f.rental_rate
FROM public.film AS f
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
  AND f.film_id IN (
      SELECT
          fc.film_id
      FROM public.film_category AS fc
      INNER JOIN public.category AS c
          ON fc.category_id = c.category_id
      WHERE UPPER(c.name) = 'ANIMATION'
  )
ORDER BY
    f.title,
    f.film_id;

/*
Business logic:
In this version I first prepare the set of animation film IDs in a CTE, then I join it
to the film table. The INNER JOIN means only films present in that prepared category list
will stay in the final result.

Advantages and disadvantages:
The CTE version is readable because the logic is split into steps. It is nice when the task
starts getting bigger. The downside is that for a small task like this it is a little too much.

Production choice:
I could also use this in production, but for this exact task I stil prefer the JOIN version
because it is simpler and does not need an extra step
*/
WITH animation_films AS (
    SELECT
        fc.film_id
    FROM public.film_category AS fc
    INNER JOIN public.category AS c
        ON fc.category_id = c.category_id
    WHERE UPPER(c.name) = 'ANIMATION'
)
SELECT
    f.film_id,
    f.title,
    f.release_year,
    f.rental_rate
FROM public.film AS f
INNER JOIN animation_films AS af
    ON f.film_id = af.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY
    f.title,
    f.film_id;


/*
Task 1.2
The finance department requires a report on store performance to assess profitability 
and plan resource allocation for stores after March 2017. 
Calculate the revenue earned by each rental store after March 2017 
(since April) (include columns: address and address2 – as one column, revenue)
*/

/*
Business logic:
I combined address and address2 into one text field. I used LEFT JOINs from store to the
transaction tables so stores with no matching rentals or payments still stay in the result.
That is important here because a report by store should not hide inactive stores.

Advantages and disadvantages:
This JOIN version keeps all store rows and shows zero when there are no payments, which is
good business reporting logic. The downside is that long join chains can be harder to debug,
and if someone joins the wrong tables it can accidentally duplicate.

Production choice:
For production I would use the CTE version below, because preaggregating revenue first
makes the final query easier to validate. 
*/
SELECT
    s.store_id,
    CASE
        WHEN a.address2 IS NOT NULL AND a.address2 <> ''
            THEN a.address || ', ' || a.address2
        ELSE a.address
    END AS store_address,
    COALESCE(SUM(p.amount), 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON s.address_id = a.address_id
LEFT JOIN public.inventory AS i
    ON s.store_id = i.store_id
LEFT JOIN public.rental AS r
    ON i.inventory_id = r.inventory_id
LEFT JOIN public.payment AS p
    ON r.rental_id = p.rental_id
   AND p.payment_date >= DATE '2017-04-01'
GROUP BY
    s.store_id,
    a.address,
    a.address2
ORDER BY
    s.store_id;

/*
Business logic:
The outer query returns all stores and their addresses. The subquery calculates total revenue
for one store at a time by using the store_id from the outer query. The INNER JOINs inside the
subquery keep only valid inventory to rental to payment matches, while the outer query still keeps all
stores because it starts from the store table.

Advantages and disadvantages:
This version is easy to understand step by step. The main disadvantage is that the revenue
subquery may be executed repeatedly for many store rows, so it can be heavier than a preaggregated
solution.

Production choice:
I would not choose this version first in production because the CTE approach is usually cleaner
and scales better for reports.
*/
SELECT
    s.store_id,
    CASE
        WHEN a.address2 IS NOT NULL AND a.address2 <> ''
            THEN a.address || ', ' || a.address2
        ELSE a.address
    END AS store_address,
    COALESCE((
        SELECT
            SUM(p.amount)
        FROM public.inventory AS i
        INNER JOIN public.rental AS r
            ON i.inventory_id = r.inventory_id
        INNER JOIN public.payment AS p
            ON r.rental_id = p.rental_id
        WHERE i.store_id = s.store_id
          AND p.payment_date >= DATE '2017-04-01'
    ), 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON s.address_id = a.address_id
ORDER BY
    s.store_id;

/*
Business logic:
I first calculate revenue by store in a CTE and then LEFT JOIN it back to all stores.
The LEFT JOIN is important because it keeps stores even when they have no payments after
March 2017. That gives a full store report instead of only active stores.

Advantages and disadvantages:
This is very readable because the aggregation part and the presentation part are separated.
It is also safer for reporting, because the revenue is already summarized before the final join.
The only downside is one extra query block.

Production choice:
This is the version I would use in production. It is clear, easy to test and less risky when
a report becomes larger later.
*/
WITH revenue_by_store AS (
    SELECT
        i.store_id,
        SUM(p.amount) AS revenue
    FROM public.inventory AS i
    INNER JOIN public.rental AS r
        ON i.inventory_id = r.inventory_id
    INNER JOIN public.payment AS p
        ON r.rental_id = p.rental_id
    WHERE p.payment_date >= DATE '2017-04-01'
    GROUP BY
        i.store_id
)
SELECT
    s.store_id,
    CASE
        WHEN a.address2 IS NOT NULL AND a.address2 <> ''
            THEN a.address || ', ' || a.address2
        ELSE a.address
    END AS store_address,
    COALESCE(rbs.revenue, 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON s.address_id = a.address_id
LEFT JOIN revenue_by_store AS rbs
    ON s.store_id = rbs.store_id
ORDER BY
    s.store_id;


/*
Task 1.3
The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer interest in their films. 
Show top-5 actors by number of movies (released since 2015) they took part in (columns: first_name, last_name, number_of_movies, 
sorted by number_of_movies in descending order)
*/

/*
Business logic:
I counted films linked to each actor only for release_year >= 2015. The INNER JOINs keep only
actors who really have matching film rows in that period. Grouping by actor makes one result row
per actor.

Advantages and disadvantages:
This JOIN version is compact and usually performs well because counting is done in one grouped query.
The weak side is that if the join path becomes more complex the query can get less clear.

Production choice:
I would use either this JOIN version or the CTE version. For production I slightly prefer the CTE
version because it separates counting from name lookup.
*/
SELECT
    a.first_name,
    a.last_name,
    COUNT(fa.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa
    ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f
    ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY
    a.actor_id,
    a.first_name,
    a.last_name
ORDER BY
    number_of_movies DESC,
    a.last_name,
    a.first_name
LIMIT 5;

/*
Business logic:
For each actor, this query counts how many films they appeared in with release_year >= 2015.
The count is calculated with a correlated subquery linked to the current actor. The second
correlated subquery in the WHERE clause keeps only actors whose count is greater than zero,
so actors without qualifying films are excluded from the final result.

Advantages and disadvantages:
This version is quite easy to understand because the logic is written directly around each actor.
However, the same counting work is repeated in both the SELECT and WHERE clauses. Because of that,
it can use more resources and may run slower than a JOIN or CTE solution.

Production choice:
I would not choose this version for production. Even though it is readable, the repeated subqueries
make it less efficient and less practical to maintain.
*/
SELECT
    a.first_name,
    a.last_name,
    (
        SELECT
            COUNT(fa.film_id)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
          AND f.release_year >= 2015
    ) AS number_of_movies
FROM public.actor AS a
WHERE (
    SELECT
        COUNT(fa.film_id)
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
    WHERE fa.actor_id = a.actor_id
      AND f.release_year >= 2015
) > 0
ORDER BY
    number_of_movies DESC,
    a.last_name,
    a.first_name
LIMIT 5;

/*
Business logic:
I first count movies per actor in a CTE and then join that result to actor names.
The INNER JOIN in the final step keeps only actors who appear in the counted result set.

Advantages and disadvantages:
This version is very readable because the counting step is isolated. It also avoids repeating
logic like the subquery version. The only downside is a little more text compared with the simple
JOIN solution.

Production choice:
This is the version I would choose in production because it balances readability and performance
well, especially if more actor attributes are added later.
*/
WITH actor_movie_counts AS (
    SELECT
        fa.actor_id,
        COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY
        fa.actor_id
)
SELECT
    a.first_name,
    a.last_name,
    amc.number_of_movies
FROM actor_movie_counts AS amc
INNER JOIN public.actor AS a
    ON amc.actor_id = a.actor_id
ORDER BY
    amc.number_of_movies DESC,
    a.last_name,
    a.first_name
LIMIT 5;

/*
Task 1.4
The marketing team needs to track the production trends of Drama, Travel, and Documentary 
films to inform genre-specific marketing strategies. Show number of Drama, Travel, 
Documentary per year (include columns: release_year, number_of_drama_movies, number_of_travel_movies, 
number_of_documentary_movies), sorted by release year in descending order. 
Dealing with NULL values is encouraged)
*/

/*
Business logic:
I used conditional aggregation to count each category by year in one query. The LEFT JOINs are
important here because they keep film years even if one of the requested categories is missing
for that year. DISTINCT protects the counts from duplicate join rows.

Advantages and disadvantages:
This version is efficient because it calculates all three category counts in one grouped query.
It is shorter than running separate queries for each category. The downside is that CASE-based
aggregation can look a bit crowded.

Production choice:
For this task I would use the JOIN version in production because it is compact and usually the
most efficient option.
*/
SELECT
    f.release_year,
    COALESCE(COUNT(DISTINCT CASE WHEN UPPER(c.name) = 'DRAMA' THEN f.film_id END), 0) AS number_of_drama_movies,
    COALESCE(COUNT(DISTINCT CASE WHEN UPPER(c.name) = 'TRAVEL' THEN f.film_id END), 0) AS number_of_travel_movies,
    COALESCE(COUNT(DISTINCT CASE WHEN UPPER(c.name) = 'DOCUMENTARY' THEN f.film_id END), 0) AS number_of_documentary_movies
FROM public.film AS f
LEFT JOIN public.film_category AS fc
    ON f.film_id = fc.film_id
LEFT JOIN public.category AS c
    ON fc.category_id = c.category_id
GROUP BY
    f.release_year
ORDER BY
    f.release_year DESC;

/*
Business logic:
I first list all distinct years and then calculate each category count with a subquery for that
year. The INNER JOINs inside the subqueries count only valid film to category matches, while the
outer list of years keeps every year from the film table.

Advantages and disadvantages:
This version is easy to explain because each category is calculated separately. But it repeats
very similar logic three times, so it uses more resources.

Production choice:
I would not use this one first in production because the JOIN version gives the same result in
a simpler and more efficient way.
*/
SELECT
    y.release_year,
    COALESCE((
        SELECT
            COUNT(DISTINCT f.film_id)
        FROM public.film AS f
        INNER JOIN public.film_category AS fc
            ON f.film_id = fc.film_id
        INNER JOIN public.category AS c
            ON fc.category_id = c.category_id
        WHERE f.release_year = y.release_year
          AND UPPER(c.name) = 'DRAMA'
    ), 0) AS number_of_drama_movies,
    COALESCE((
        SELECT
            COUNT(DISTINCT f.film_id)
        FROM public.film AS f
        INNER JOIN public.film_category AS fc
            ON f.film_id = fc.film_id
        INNER JOIN public.category AS c
            ON fc.category_id = c.category_id
        WHERE f.release_year = y.release_year
          AND UPPER(c.name) = 'TRAVEL'
    ), 0) AS number_of_travel_movies,
    COALESCE((
        SELECT
            COUNT(DISTINCT f.film_id)
        FROM public.film AS f
        INNER JOIN public.film_category AS fc
            ON f.film_id = fc.film_id
        INNER JOIN public.category AS c
            ON fc.category_id = c.category_id
        WHERE f.release_year = y.release_year
          AND UPPER(c.name) = 'DOCUMENTARY'
    ), 0) AS number_of_documentary_movies
FROM (
    SELECT DISTINCT
        release_year
    FROM public.film
) AS y
ORDER BY
    y.release_year DESC;

/*
Business logic:
I created separate CTEs for the year list and for each category count. Then I used LEFT JOINs
to attach those counts to every year.

Advantages and disadvantages:
This version is very readable because each category has its own step. The downside is that the
same base tables are scanned several times, so it can be heavier than the JOIN version.

Production choice:
I would keep this version for teaching or for a report that may grow later, but in production
I would choose the JOIN version because it is shorter and usually more efficient.
*/
WITH years AS (
    SELECT DISTINCT
        release_year
    FROM public.film
),
drama_counts AS (
    SELECT
        f.release_year,
        COUNT(DISTINCT f.film_id) AS number_of_drama_movies
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON f.film_id = fc.film_id
    INNER JOIN public.category AS c
        ON fc.category_id = c.category_id
    WHERE UPPER(c.name) = 'DRAMA'
    GROUP BY
        f.release_year
),
travel_counts AS (
    SELECT
        f.release_year,
        COUNT(DISTINCT f.film_id) AS number_of_travel_movies
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON f.film_id = fc.film_id
    INNER JOIN public.category AS c
        ON fc.category_id = c.category_id
    WHERE UPPER(c.name) = 'TRAVEL'
    GROUP BY
        f.release_year
),
documentary_counts AS (
    SELECT
        f.release_year,
        COUNT(DISTINCT f.film_id) AS number_of_documentary_movies
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON f.film_id = fc.film_id
    INNER JOIN public.category AS c
        ON fc.category_id = c.category_id
    WHERE UPPER(c.name) = 'DOCUMENTARY'
    GROUP BY
        f.release_year
)
SELECT
    y.release_year,
    COALESCE(dc.number_of_drama_movies, 0) AS number_of_drama_movies,
    COALESCE(tc.number_of_travel_movies, 0) AS number_of_travel_movies,
    COALESCE(doc.number_of_documentary_movies, 0) AS number_of_documentary_movies
FROM years AS y
LEFT JOIN drama_counts AS dc
    ON y.release_year = dc.release_year
LEFT JOIN travel_counts AS tc
    ON y.release_year = tc.release_year
LEFT JOIN documentary_counts AS doc
    ON y.release_year = doc.release_year
ORDER BY
    y.release_year DESC;


/*
Task 2.1
The HR department aims to reward top-performing employees in 2017 with bonuses to recognize their contribution to stores revenue. Show which three employees generated the most revenue in 2017? 

Assumptions: 
staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
if staff processed the payment then he works in the same store; 
take into account only payment_date
*/

/*
Business logic:
I summed 2017 payments by staff and determined the last store from the latest 2017 payment row.
The INNER JOINs keep only valid payment to rental to inventory to store links. 

Advantages and disadvantages:
This JOIN version follows the business rules correctly and stays in the style of plain joins.
But the logic is quite long because last store needs several derived steps, so readability is
bad.

Production choice:
I would not choose this JOIN version first in production. It works, but the CTE version below
is easier to read and test.
*/
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_full_name,
    ls.store_id AS last_store_id,
    CASE
        WHEN a.address2 IS NOT NULL AND a.address2 <> ''
            THEN a.address || ', ' || a.address2
        ELSE a.address
    END AS last_store_address,
    rev.revenue_2017
FROM (
    SELECT
        p.staff_id,
        SUM(p.amount) AS revenue_2017
    FROM public.payment AS p
    WHERE p.payment_date >= TIMESTAMP '2017-01-01 00:00:00'
      AND p.payment_date < TIMESTAMP '2018-01-01 00:00:00'
    GROUP BY
        p.staff_id
) AS rev
INNER JOIN public.staff AS s
    ON s.staff_id = rev.staff_id
INNER JOIN (
    SELECT
        ranked.staff_id,
        ranked.store_id
    FROM (
        SELECT
            p.staff_id,
            i.store_id,
            ROW_NUMBER() OVER (
                PARTITION BY p.staff_id
                ORDER BY p.payment_date DESC, p.payment_id DESC
            ) AS rn
        FROM public.payment AS p
        INNER JOIN public.rental AS r
            ON p.rental_id = r.rental_id
        INNER JOIN public.inventory AS i
            ON r.inventory_id = i.inventory_id
        WHERE p.payment_date >= TIMESTAMP '2017-01-01 00:00:00'
          AND p.payment_date < TIMESTAMP '2018-01-01 00:00:00'
    ) AS ranked
    WHERE ranked.rn = 1
) AS ls
    ON s.staff_id = ls.staff_id
INNER JOIN public.store AS st
    ON ls.store_id = st.store_id
INNER JOIN public.address AS a
    ON st.address_id = a.address_id
ORDER BY
    rev.revenue_2017 DESC,
    s.staff_id
LIMIT 3;


/*
Business logic:
This query starts from the staff table and uses correlated subqueries to calculate three values
for each staff member: the store of the latest 2017 payment, the address of that store and the
total revenue made in 2017. The subqueries connect payment to rental and inventory with INNER JOINs,
so only valid linked transactions are included. The WHERE clause uses a counting subquery to keep only
staff members who had at least one payment in 2017.

Advantages and disadvantages:
This version is understandable because each value is calculated separately and the logic is close to
the business requirement. At the same time, it repeats very similar subqueries several times. Because
of that, the query becomes longer, harder to maintain and can use more resources than a JOIN or CTE
solution, especially if the dataset grows.

Production choice:
I would not choose this version for production on a larger database.
*/
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_full_name,
    (
        SELECT
            i.store_id
        FROM public.payment AS p
        INNER JOIN public.rental AS r
            ON p.rental_id = r.rental_id
        INNER JOIN public.inventory AS i
            ON r.inventory_id = i.inventory_id
        WHERE p.staff_id = s.staff_id
          AND p.payment_date >= DATE '2017-01-01'
          AND p.payment_date < DATE '2018-01-01'
        ORDER BY
            p.payment_date DESC,
            p.payment_id DESC
        LIMIT 1
    ) AS last_store_id,
    (
        SELECT
            CASE
                WHEN a.address2 IS NOT NULL AND a.address2 <> ''
                    THEN a.address || ', ' || a.address2
                ELSE a.address
            END
        FROM public.payment AS p
        INNER JOIN public.rental AS r
            ON p.rental_id = r.rental_id
        INNER JOIN public.inventory AS i
            ON r.inventory_id = i.inventory_id
        INNER JOIN public.store AS st
            ON i.store_id = st.store_id
        INNER JOIN public.address AS a
            ON st.address_id = a.address_id
        WHERE p.staff_id = s.staff_id
          AND p.payment_date >= DATE '2017-01-01'
          AND p.payment_date < DATE '2018-01-01'
        ORDER BY
            p.payment_date DESC,
            p.payment_id DESC
        LIMIT 1
    ) AS last_store_address,
    (
        SELECT
            SUM(p.amount)
        FROM public.payment AS p
        INNER JOIN public.rental AS r
            ON p.rental_id = r.rental_id
        INNER JOIN public.inventory AS i
            ON r.inventory_id = i.inventory_id
        WHERE p.staff_id = s.staff_id
          AND p.payment_date >= DATE '2017-01-01'
          AND p.payment_date < DATE '2018-01-01'
    ) AS revenue_2017
FROM public.staff AS s
WHERE (
    SELECT
        COUNT(*)
    FROM public.payment AS p
    INNER JOIN public.rental AS r
        ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i
        ON r.inventory_id = i.inventory_id
    WHERE p.staff_id = s.staff_id
      AND p.payment_date >= DATE '2017-01-01'
      AND p.payment_date < DATE '2018-01-01'
) > 0
ORDER BY
    revenue_2017 DESC,
    s.staff_id
LIMIT 3;

/*
Business logic:
I first prepared valid 2017 payment rows with their store_id. Then I split the task into
clear steps: revenue by staff, latest payment date, last_payment_row and  last
store. The final INNER JOINs keep only staff who really have valid 2017 payment rows.

Advantages and disadvantages:
This version is longer than a simple query, but the logic is much easier to audit because each
step has one purpose. It also avoids repeating the same work like the subquery version.

Production choice:
This is the version I would use in production. The rule about last store is the hardest part
of the task, and the CTE structure makes that rule much clearer.
*/
WITH payments_2017 AS (
    SELECT
        p.payment_id,
        p.staff_id,
        p.amount,
        p.payment_date,
        p.rental_id
    FROM public.payment AS p
    WHERE p.payment_date >= TIMESTAMP '2017-01-01 00:00:00'
      AND p.payment_date < TIMESTAMP '2018-01-01 00:00:00'
),
revenue_by_staff AS (
    SELECT
        staff_id,
        SUM(amount) AS revenue_2017
    FROM payments_2017
    GROUP BY
        staff_id
),
ranked_last_store AS (
    SELECT
        p.staff_id,
        i.store_id,
        ROW_NUMBER() OVER (
            PARTITION BY p.staff_id
            ORDER BY p.payment_date DESC, p.payment_id DESC
        ) AS rn
    FROM payments_2017 AS p
    INNER JOIN public.rental AS r
        ON p.rental_id = r.rental_id
    INNER JOIN public.inventory AS i
        ON r.inventory_id = i.inventory_id
),
last_store AS (
    SELECT
        staff_id,
        store_id
    FROM ranked_last_store
    WHERE rn = 1
)
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_full_name,
    ls.store_id AS last_store_id,
    CASE
        WHEN a.address2 IS NOT NULL AND a.address2 <> ''
            THEN a.address || ', ' || a.address2
        ELSE a.address
    END AS last_store_address,
    rbs.revenue_2017
FROM revenue_by_staff AS rbs
INNER JOIN public.staff AS s
    ON rbs.staff_id = s.staff_id
INNER JOIN last_store AS ls
    ON s.staff_id = ls.staff_id
INNER JOIN public.store AS st
    ON ls.store_id = st.store_id
INNER JOIN public.address AS a
    ON st.address_id = a.address_id
ORDER BY
    rbs.revenue_2017 DESC,
    s.staff_id
LIMIT 3;

/*
Task 2.2
The management team wants to identify the most popular movies and their target audience age groups 
to optimize marketing efforts. Show which 5 movies were rented more than others (number of rentals), 
and what's the expected age of the audience for these movies? To determine expected age please use 
'Motion Picture Association film rating system'
*/

/*
Business logic:
I counted rentals per film and translated the rating into an age-group description with CASE.
The INNER JOINs keep only films that actually have inventory and rental rows, so unrented films
do not appear.

Advantages and disadvantages:
This JOIN version is short and efficient because the counting is done directly on the joined tables.
The only downside is that business text mapping with CASE can make the query a little longer.

Production choice:
This version is valid for production, but I slightly prefer the CTE version because it separates
the rental counting from the final presentation.
*/
SELECT
    f.title,
    COUNT(r.rental_id) AS number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN f.rating = 'PG-13' THEN '13+ (parents strongly cautioned)'
        WHEN f.rating = 'R' THEN 'Under 17 requires accompanying parent/adult guardian'
        WHEN f.rating = 'NC-17' THEN '18+ only / adults only'
        ELSE 'Unknown'
    END AS expected_audience_age_group
FROM public.film AS f
INNER JOIN public.inventory AS i
    ON f.film_id = i.film_id
INNER JOIN public.rental AS r
    ON i.inventory_id = r.inventory_id
GROUP BY
    f.film_id,
    f.title,
    f.rating
ORDER BY
    number_of_rentals DESC,
    f.title,
    f.film_id
LIMIT 5;

/*
Business logic:
This query starts from the film table and returns film title, rating, rental count, and a simple
text description of the audience age group based on the rating. A correlated subquery counts how
many rentals belong to the current film by linking inventory and rental with an INNER JOIN. The
WHERE clause uses the same counting logic to keep only films that were rented at least once.

Advantages and disadvantages:
This version is fairly easy to understand because the rental count is calculated directly for each
film row. The CASE expression also makes the rating meaning clearer in the result. However, the
query repeats the rental-counting logic in both the SELECT and WHERE clauses.

Production choice:
I would not choose this as the first production option. It works correctly, but the repeated
subqueries make it less efficient and less clean.
*/
SELECT
    f.title,
    (
        SELECT
            COUNT(r.rental_id)
        FROM public.inventory AS i
        INNER JOIN public.rental AS r
            ON i.inventory_id = r.inventory_id
        WHERE i.film_id = f.film_id
    ) AS number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN f.rating = 'PG-13' THEN '13+ (parents strongly cautioned)'
        WHEN f.rating = 'R' THEN 'Under 17 requires accompanying parent/adult guardian'
        WHEN f.rating = 'NC-17' THEN '18+ only / adults only'
        ELSE 'Unknown'
    END AS expected_audience_age_group
FROM public.film AS f
WHERE (
    SELECT
        COUNT(r.rental_id)
    FROM public.inventory AS i
    INNER JOIN public.rental AS r
        ON i.inventory_id = r.inventory_id
    WHERE i.film_id = f.film_id
) > 0
ORDER BY
    number_of_rentals DESC,
    f.title,
    f.film_id
LIMIT 5;

/*
Business logic:
I first count rentals by film in a CTE and then join that set to the film table to show title
and rating. The INNER JOIN means only films with at least one rental are returned.

Advantages and disadvantages:
This version is readable because the aggregation step is separated from the descriptive columns.
It also avoids repeated subqueries. The only disadvantage is that it is a little longer than
the plain JOIN version.

Production choice:
This is the version I would use in production because it keeps the counting logic clean and
is easy to extend if more film details are needed later.
*/
WITH rentals_by_film AS (
    SELECT
        i.film_id,
        COUNT(r.rental_id) AS number_of_rentals
    FROM public.inventory AS i
    INNER JOIN public.rental AS r
        ON i.inventory_id = r.inventory_id
    GROUP BY
        i.film_id
)
SELECT
    f.title,
    rbf.number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN f.rating = 'PG-13' THEN '13+ (parents strongly cautioned)'
        WHEN f.rating = 'R' THEN 'Under 17 requires accompanying parent/adult guardian'
        WHEN f.rating = 'NC-17' THEN '18+ only / adults only'
        ELSE 'Unknown'
    END AS expected_audience_age_group
FROM rentals_by_film AS rbf
INNER JOIN public.film AS f
    ON rbf.film_id = f.film_id
ORDER BY
    rbf.number_of_rentals DESC,
    f.title,
    f.film_id
LIMIT 5;


/*
Task 3.1
The stores’ marketing team wants to analyze actors' inactivity periods to select those 
with notable career breaks for targeted promotional campaigns, highlighting their comebacks 
or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
*/

/*
Business logic:
This query first finds the latest release year for each actor. After that, it keeps only the
actors whose latest release year is the earliest among all actors, which means they have the
largest inactivity period. The inactivity is calculated as the current year minus the actor's
last release year.

Advantages and disadvantages:
It is easy to read and still follows the required logic. Still, it uses nested derived tables, so it is not as clean as the
CTE version.

Production choice:
I would choose the CTE version for production, since it is usually easier to read,
support and explain.
*/
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    lr.last_release_year,
    CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS INTEGER) - lr.last_release_year AS inactivity_years
FROM public.actor AS a
INNER JOIN (
    SELECT
        fa.actor_id,
        MAX(f.release_year) AS last_release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
    GROUP BY
        fa.actor_id
) AS lr
    ON a.actor_id = lr.actor_id
INNER JOIN (
    SELECT
        MIN(actor_last.last_release_year) AS earliest_last_release_year
    FROM (
        SELECT
            fa.actor_id,
            MAX(f.release_year) AS last_release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
        GROUP BY
            fa.actor_id
    ) AS actor_last
) AS m
    ON lr.last_release_year = m.earliest_last_release_year
ORDER BY
    a.last_name,
    a.first_name,
    a.actor_id;

/*
Business logic:
This query returns the actor or actors with the longest inactivity period. For each actor, a
correlated subquery finds the latest release year from the film history. Then the query calculates
inactivity as the current year minus that latest release year. The WHERE clause uses one subquery
to keep only actors who have at least one film record, and another subquery to keep only those
whose latest release year is the earliest among all actors.

Advantages and disadvantages:
This version follows the business logic correctly. However,
the same latest-release lookup is repeated more than once, so the query is longer and can
be less efficient than a JOIN or CTE solution.

Production choice:
I would not choose this version first for production. 
*/
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    (
        SELECT
            MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS last_release_year,
    CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS INTEGER) - (
        SELECT
            MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS inactivity_years
FROM public.actor AS a
WHERE (
    SELECT
        COUNT(*)
    FROM public.film_actor AS fa
    WHERE fa.actor_id = a.actor_id
) > 0
  AND (
      SELECT
          MAX(f.release_year)
      FROM public.film_actor AS fa
      INNER JOIN public.film AS f
          ON fa.film_id = f.film_id
      WHERE fa.actor_id = a.actor_id
  ) = (
      SELECT
          MIN(last_release.last_release_year)
      FROM (
          SELECT
              MAX(f.release_year) AS last_release_year
          FROM public.film_actor AS fa
          INNER JOIN public.film AS f
              ON fa.film_id = f.film_id
          GROUP BY
              fa.actor_id
      ) AS last_release
  )
ORDER BY
    a.last_name,
    a.first_name,
    a.actor_id;

/*
Business logic:
I split the task into three clear steps: latest release per actor, inactivity per actor,
and maximum inactivity overall. The final INNER JOIN keeps only the actor rows whose inactivity
matches that maximum.

Advantages and disadvantages:
This version is very readable and easy to check. It also avoids repeating logic. The only
disadvantage is that it is a bit longer than writing everything in one query.

Production choice:
This is the version I would use in production because the business rule is clear in each step
and it is easier to maintain.
*/
WITH last_release_per_actor AS (
    SELECT
        fa.actor_id,
        MAX(f.release_year) AS last_release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
    GROUP BY
        fa.actor_id
),
inactivity_per_actor AS (
    SELECT
        lra.actor_id,
        lra.last_release_year,
        CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS INTEGER) - lra.last_release_year AS inactivity_years
    FROM last_release_per_actor AS lra
),
max_inactivity AS (
    SELECT
        MAX(inactivity_years) AS max_inactivity_years
    FROM inactivity_per_actor
)
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    ipa.last_release_year,
    ipa.inactivity_years
FROM inactivity_per_actor AS ipa
INNER JOIN max_inactivity AS mi
    ON ipa.inactivity_years = mi.max_inactivity_years
INNER JOIN public.actor AS a
    ON ipa.actor_id = a.actor_id
ORDER BY
    a.last_name,
    a.first_name,
    a.actor_id;


/*
Task 3.2
V2: gaps between sequential films per each actor;
*/

/*
Business logic:
I first build pairs of years for the same actor where the second year is greater than the first.
Then I use a LEFT JOIN to check whether there is an intermediate release year in between. If the
LEFT JOIN finds no middle year, that pair is consecutive. After that, I keep only the largest gap.

Advantages and disadvantages:
This JOIN version which matches the requirement.
But it is quite long because the same distinct actor_year dataset appears several times.

Production choice:
I would not use this version first in production because it is harder to read and maintain than
the CTE version.
*/
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    g.previous_release_year,
    g.next_release_year,
    g.gap_in_years
FROM public.actor AS a
INNER JOIN (
    SELECT
        y1.actor_id,
        y1.release_year AS previous_release_year,
        y2.release_year AS next_release_year,
        y2.release_year - y1.release_year AS gap_in_years
    FROM (
        SELECT DISTINCT
            fa.actor_id,
            f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
    ) AS y1
    INNER JOIN (
        SELECT DISTINCT
            fa.actor_id,
            f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
    ) AS y2
        ON y1.actor_id = y2.actor_id
       AND y2.release_year > y1.release_year
    LEFT JOIN (
        SELECT DISTINCT
            fa.actor_id,
            f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
    ) AS ym
        ON y1.actor_id = ym.actor_id
       AND ym.release_year > y1.release_year
       AND ym.release_year < y2.release_year
    WHERE ym.actor_id IS NULL
) AS g
    ON a.actor_id = g.actor_id
INNER JOIN (
    SELECT
        MAX(gap_data.gap_in_years) AS max_gap_in_years
    FROM (
        SELECT
            y1.actor_id,
            y2.release_year - y1.release_year AS gap_in_years
        FROM (
            SELECT DISTINCT
                fa.actor_id,
                f.release_year
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f
                ON fa.film_id = f.film_id
        ) AS y1
        INNER JOIN (
            SELECT DISTINCT
                fa.actor_id,
                f.release_year
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f
                ON fa.film_id = f.film_id
        ) AS y2
            ON y1.actor_id = y2.actor_id
           AND y2.release_year > y1.release_year
        LEFT JOIN (
            SELECT DISTINCT
                fa.actor_id,
                f.release_year
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f
                ON fa.film_id = f.film_id
        ) AS ym
            ON y1.actor_id = ym.actor_id
           AND ym.release_year > y1.release_year
           AND ym.release_year < y2.release_year
        WHERE ym.actor_id IS NULL
    ) AS gap_data
) AS mg
    ON g.gap_in_years = mg.max_gap_in_years
ORDER BY
    a.last_name,
    a.first_name,
    g.previous_release_year,
    a.actor_id;

/*
Business logic:
For each actor_year row, I look for the next later release year by using MIN in a subquery.
That gives the next consecutive release year. Then I compare the gap to the maximum gap found
for all actors. The INNER JOINs inside the subqueries keep only valid actor-film rows.

Advantages and disadvantages:
This version follows the idea of next year after this one. But it still repeats the
same actor-year dataset many times.

Production choice:
I would not pick this one for production because the CTE version is easier to read and reuse.
*/
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    ay.release_year AS previous_release_year,
    (
        SELECT
            MIN(ay2.release_year)
        FROM (
            SELECT DISTINCT
                fa.actor_id,
                f.release_year
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f
                ON fa.film_id = f.film_id
        ) AS ay2
        WHERE ay2.actor_id = ay.actor_id
          AND ay2.release_year > ay.release_year
    ) AS next_release_year,
    (
        SELECT
            MIN(ay2.release_year)
        FROM (
            SELECT DISTINCT
                fa.actor_id,
                f.release_year
            FROM public.film_actor AS fa
            INNER JOIN public.film AS f
                ON fa.film_id = f.film_id
        ) AS ay2
        WHERE ay2.actor_id = ay.actor_id
          AND ay2.release_year > ay.release_year
    ) - ay.release_year AS gap_in_years
FROM public.actor AS a
INNER JOIN (
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
) AS ay
    ON a.actor_id = ay.actor_id
WHERE (
    SELECT
        MIN(ay2.release_year)
    FROM (
        SELECT DISTINCT
            fa.actor_id,
            f.release_year
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON fa.film_id = f.film_id
    ) AS ay2
    WHERE ay2.actor_id = ay.actor_id
      AND ay2.release_year > ay.release_year
) IS NOT NULL
  AND (
      (
          SELECT
              MIN(ay2.release_year)
          FROM (
              SELECT DISTINCT
                  fa.actor_id,
                  f.release_year
              FROM public.film_actor AS fa
              INNER JOIN public.film AS f
                  ON fa.film_id = f.film_id
          ) AS ay2
          WHERE ay2.actor_id = ay.actor_id
            AND ay2.release_year > ay.release_year
      ) - ay.release_year
  ) = (
      SELECT
          MAX(gap_data.gap_in_years)
      FROM (
          SELECT
              ayx.actor_id,
              ayx.release_year,
              (
                  SELECT
                      MIN(ayy.release_year)
                  FROM (
                      SELECT DISTINCT
                          fa.actor_id,
                          f.release_year
                      FROM public.film_actor AS fa
                      INNER JOIN public.film AS f
                          ON fa.film_id = f.film_id
                  ) AS ayy
                  WHERE ayy.actor_id = ayx.actor_id
                    AND ayy.release_year > ayx.release_year
              ) - ayx.release_year AS gap_in_years
          FROM (
              SELECT DISTINCT
                  fa.actor_id,
                  f.release_year
              FROM public.film_actor AS fa
              INNER JOIN public.film AS f
                  ON fa.film_id = f.film_id
          ) AS ayx
      ) AS gap_data
      WHERE gap_data.gap_in_years IS NOT NULL
  )
ORDER BY
    a.last_name,
    a.first_name,
    ay.release_year,
    a.actor_id;

/*
Business logic:
I first create a clean actor_years set with distinct actor and release year values. Then I build
all consecutive gaps by joining that set to itself and using a LEFT JOIN to remove non-consecutive
pairs. Finally, I keep only the maximum gap.

Advantages and disadvantages:
This version is the clearest one for a difficult task like this.

Production choice:
This is the version I would use in production because the logic is complex and the CTE structure
makes the query much easier to verify and maintain.
*/
WITH actor_years AS (
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON fa.film_id = f.film_id
),
consecutive_gaps AS (
    SELECT
        ay1.actor_id,
        ay1.release_year AS previous_release_year,
        ay2.release_year AS next_release_year,
        ay2.release_year - ay1.release_year AS gap_in_years
    FROM actor_years AS ay1
    INNER JOIN actor_years AS ay2
        ON ay1.actor_id = ay2.actor_id
       AND ay2.release_year > ay1.release_year
    LEFT JOIN actor_years AS aym
        ON ay1.actor_id = aym.actor_id
       AND aym.release_year > ay1.release_year
       AND aym.release_year < ay2.release_year
    WHERE aym.actor_id IS NULL
),
max_gap AS (
    SELECT
        MAX(gap_in_years) AS max_gap_in_years
    FROM consecutive_gaps
)
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    cg.previous_release_year,
    cg.next_release_year,
    cg.gap_in_years
FROM consecutive_gaps AS cg
INNER JOIN max_gap AS mg
    ON cg.gap_in_years = mg.max_gap_in_years
INNER JOIN public.actor AS a
    ON cg.actor_id = a.actor_id
ORDER BY
    a.last_name,
    a.first_name,
    cg.previous_release_year,
    a.actor_id;
