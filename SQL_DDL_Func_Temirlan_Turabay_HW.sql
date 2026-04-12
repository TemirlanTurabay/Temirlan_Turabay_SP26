CREATE SCHEMA IF NOT EXISTS core;

/*
Task 1.
Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue for the current quarter and year. The view should only display categories with at least one sale in the current quarter. 
Note: make it dynamic - when the next quarter begins, it automatically considers that as the current quarter
Explain in the comment how you determine:
current quarter
current year
why only categories with sales appear
how zero-sales categories are excluded
the current default database does not contain data for the current year. Also, please indicate how you verified that view is working correctly
Provide example of data that should NOT appear
*/
DROP VIEW IF EXISTS core.sales_revenue_by_category_qtr;

CREATE OR REPLACE VIEW core.sales_revenue_by_category_qtr AS
WITH quarter_bounds AS (
    SELECT
        date_trunc('quarter', current_date)::timestamp AS q_start,
        (date_trunc('quarter', current_date) + interval '3 months')::timestamp AS q_end,
        extract(year FROM current_date)::int AS report_year,
        extract(quarter FROM current_date)::int AS report_quarter
)
SELECT
    qb.report_year,
    qb.report_quarter,
    c.name::text AS category_name,
    round(sum(p.amount), 2) AS total_sales_revenue
FROM quarter_bounds qb
JOIN public.payment p
  ON p.payment_date >= qb.q_start
 AND p.payment_date < qb.q_end
JOIN public.rental r
  ON r.rental_id = p.rental_id
JOIN public.inventory i
  ON i.inventory_id = r.inventory_id
JOIN public.film_category fc
  ON fc.film_id = i.film_id
JOIN public.category c
  ON c.category_id = fc.category_id
GROUP BY qb.report_year, qb.report_quarter, c.category_id, c.name
ORDER BY c.name;

/*
Task 2.
Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.
Explain in the comment:
why parameter is needed
what happens if:
invalid quarter is passed
no data exists
*/
DROP FUNCTION IF EXISTS core.check_sales_period(text);

CREATE OR REPLACE FUNCTION core.check_sales_period(p_period text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_period IS NULL OR btrim(p_period) = '' THEN
        RAISE EXCEPTION 'Quarter/year value cannot be null or empty. Use format YYYY-Q1 .. YYYY-Q4.';
    END IF;

    IF upper(btrim(p_period)) !~ '^\d{4}-Q[1-4]$' THEN
        RAISE EXCEPTION 'Wrong quarter/year value: "%". Use format YYYY-Q1 .. YYYY-Q4.', p_period;
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS core.get_sales_revenue_by_category_qtr(text);

CREATE OR REPLACE FUNCTION core.get_sales_revenue_by_category_qtr(p_period text)
RETURNS TABLE (
    report_year int,
    report_quarter int,
    category_name text,
    total_sales_revenue numeric
)
LANGUAGE sql
AS $$
    WITH checked AS (
        SELECT upper(btrim($1)) AS period_value, core.check_sales_period($1)
    ), parts AS (
        SELECT
            substring(period_value, 1, 4)::int AS report_year,
            substring(period_value, 7, 1)::int AS report_quarter
        FROM checked
    ), quarter_bounds AS (
        SELECT
            report_year,
            report_quarter,
            make_date(report_year, ((report_quarter - 1) * 3) + 1, 1)::timestamp AS q_start,
            (make_date(report_year, ((report_quarter - 1) * 3) + 1, 1) + interval '3 months')::timestamp AS q_end
        FROM parts
    )
    SELECT
        qb.report_year,
        qb.report_quarter,
        c.name::text AS category_name,
        round(sum(p.amount), 2) AS total_sales_revenue
    FROM quarter_bounds qb
    JOIN public.payment p
      ON p.payment_date >= qb.q_start
     AND p.payment_date < qb.q_end
    JOIN public.rental r
      ON r.rental_id = p.rental_id
    JOIN public.inventory i
      ON i.inventory_id = r.inventory_id
    JOIN public.film_category fc
      ON fc.film_id = i.film_id
    JOIN public.category c
      ON c.category_id = fc.category_id
    GROUP BY qb.report_year, qb.report_quarter, c.category_id, c.name
    ORDER BY c.name;
$$;

/*
Task 3.
Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 
The function should format the result set as follows:
                    Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]);
Explain in the comment:
how 'most popular' is defined: by rentals / by revenue / by count
how ties are handled
what happens if country has no data
*/
DROP FUNCTION IF EXISTS core.most_popular_films_by_countries(text[]);

CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(p_countries text[])
RETURNS TABLE (
    country text,
    film text,
    rating text,
    language text,
    length text,
    release_year text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count int;
BEGIN
    IF p_countries IS NULL OR cardinality(p_countries) = 0 THEN
        RAISE EXCEPTION 'Country array cannot be null or empty.';
    END IF;

    SELECT count(*)
      INTO v_count
    FROM unnest(p_countries) AS x(name)
    WHERE nullif(btrim(name), '') IS NOT NULL;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'Country array does not contain any usable country names.';
    END IF;

    RETURN QUERY
    WITH wanted AS (
        SELECT DISTINCT ON (upper(btrim(name)))
            ord::int AS ord,
            btrim(name)::text AS country_name
        FROM unnest(p_countries) WITH ORDINALITY AS t(name, ord)
        WHERE nullif(btrim(name), '') IS NOT NULL
        ORDER BY upper(btrim(name)), ord
    ), ranked AS (
        SELECT
            w.ord,
            w.country_name,
            f.film_id,
            f.title,
            f.rating::text AS rating,
            l.name::text AS lang_name,
            f.length,
            coalesce(f.release_year::text, '-') AS release_year,
            count(r.rental_id)::int AS rental_count,
            row_number() OVER (
                PARTITION BY w.country_name
                ORDER BY count(r.rental_id) DESC, f.title, f.film_id
            ) AS rn
        FROM wanted w
        JOIN public.country co
          ON upper(co.country) = upper(w.country_name)
        JOIN public.city ci
          ON ci.country_id = co.country_id
        JOIN public.address a
          ON a.city_id = ci.city_id
        JOIN public.customer cu
          ON cu.address_id = a.address_id
        JOIN public.rental r
          ON r.customer_id = cu.customer_id
        JOIN public.inventory i
          ON i.inventory_id = r.inventory_id
        JOIN public.film f
          ON f.film_id = i.film_id
        JOIN public.language l
          ON l.language_id = f.language_id
        GROUP BY w.ord, w.country_name, f.film_id, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT
        w.country_name::text AS country,
        coalesce(rk.title, '-')::text AS film,
        coalesce(rk.rating, '-')::text AS rating,
        coalesce(rk.lang_name, '-')::text AS language,
        coalesce(rk.length::text, '-')::text AS length,
        coalesce(rk.release_year, '-')::text AS release_year
    FROM wanted w
    LEFT JOIN ranked rk
      ON rk.country_name = w.country_name
     AND rk.rn = 1
    ORDER BY w.ord;
END;
$$;

/*
Task 4.
Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 'love' in their title). 
The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, return a message indicating that it was not found.
The function should produce the result set in the following format (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).
                    Query (example):select * from core.films_in_stock_by_title('%love%’);
Explain in the comment:
how pattern matching works (LIKE, %)
how you ensure performance: which part of your query may become slow on large data; how your implementation minimizes unnecessary data processing
case sensitivity
what happens if:
multiple matches
no matches
*/
DROP FUNCTION IF EXISTS core.films_in_stock_by_title(text);

CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_title_pattern text)
RETURNS TABLE (
    row_num bigint,
    film_title text,
    language text,
    customer_name text,
    rental_date text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pattern text;
BEGIN
    IF p_title_pattern IS NULL OR btrim(p_title_pattern) = '' THEN
        RAISE EXCEPTION 'Title pattern cannot be null or empty.';
    END IF;

    IF strpos(p_title_pattern, '%') > 0 OR strpos(p_title_pattern, '_') > 0 THEN
        v_pattern := p_title_pattern;
    ELSE
        v_pattern := '%' || btrim(p_title_pattern) || '%';
    END IF;

    RETURN QUERY
    WITH available AS (
        SELECT
            f.film_id,
            f.title,
            l.name AS language_name,
            i.inventory_id
        FROM public.film f
        JOIN public.language l
          ON l.language_id = f.language_id
        JOIN public.inventory i
          ON i.film_id = f.film_id
        WHERE f.title ILIKE v_pattern
          AND public.inventory_in_stock(i.inventory_id)
    ),
    picked AS (
        SELECT DISTINCT ON (a.film_id)
            a.film_id,
            a.title,
            a.language_name,
            COALESCE(c.first_name || ' ' || c.last_name, '-')::text AS customer_name_val,
            COALESCE(to_char(lr.rental_date, 'YYYY-MM-DD HH24:MI:SS'), '-')::text AS rental_date_val
        FROM available a
        LEFT JOIN LATERAL (
            SELECT r.customer_id, r.rental_date
            FROM public.rental r
            WHERE r.inventory_id = a.inventory_id
            ORDER BY r.rental_date DESC NULLS LAST
            LIMIT 1
        ) AS lr ON true
        LEFT JOIN public.customer c
          ON c.customer_id = lr.customer_id
        ORDER BY a.film_id, lr.rental_date DESC NULLS LAST, a.inventory_id
    ),
    numbered AS (
        SELECT
            row_number() OVER (ORDER BY p.title, p.film_id) AS row_num_val,
            p.title::text AS film_title_val,
            p.language_name::text AS language_val,
            p.customer_name_val,
            p.rental_date_val
        FROM picked p
    )
    SELECT
        n.row_num_val,
        n.film_title_val,
        n.language_val,
        n.customer_name_val,
        n.rental_date_val
    FROM numbered n
    ORDER BY n.row_num_val;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            1::bigint,
            format('Film not found in stock for pattern: %s', v_pattern)::text,
            '-'::text,
            '-'::text,
            '-'::text;
    END IF;
END;
$$;

/*
Task 5.
Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts a new movie with the given title in the film table. The function should generate a new unique film ID, set the rental rate to 4.99, the rental duration to three days, the replacement cost to 19.99. The release year and language are optional and by default should be current year and Klingon respectively. 
The function should also verify that the language exists in the 'language' table. 
The function must prevent inserting duplicate movie titles and raise an exception if duplicate exists.
Ensure that no such function has been created before; if so, replace it.
Explain in the comment:
how you generate unique ID
how you ensure no duplicates
what happens if movie already exists
how you validate language existence
what happens if insertion fails
how consistency is preserved
*/
DROP FUNCTION IF EXISTS core.new_movie(text, integer, text);

CREATE OR REPLACE FUNCTION core.new_movie(
    p_title text,
    p_release_year integer DEFAULT extract(year FROM current_date)::integer,
    p_language_name text DEFAULT 'Klingon'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id int;
    v_film_id int;
    v_has_fulltext boolean;
BEGIN
    IF p_title IS NULL OR btrim(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be null or empty.';
    END IF;

    IF p_release_year IS NULL THEN
        RAISE EXCEPTION 'Release year cannot be null.';
    END IF;

    IF p_release_year < 1901 OR p_release_year > 2155 THEN
        RAISE EXCEPTION 'Release year % is outside the allowed range 1901..2155.', p_release_year;
    END IF;

    IF p_language_name IS NULL OR btrim(p_language_name) = '' THEN
        RAISE EXCEPTION 'Language name cannot be null or empty.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.film f
        WHERE upper(btrim(f.title)) = upper(btrim(p_title))
    ) THEN
        RAISE EXCEPTION 'Movie "%" already exists.', btrim(p_title);
    END IF;

    SELECT l.language_id
    INTO v_language_id
    FROM public.language l
    WHERE upper(btrim(l.name)) = upper(btrim(p_language_name))
    ORDER BY l.language_id
    LIMIT 1;

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in public.language.', btrim(p_language_name);
    END IF;

    SELECT COALESCE(MAX(film_id), 0) + 1
    INTO v_film_id
    FROM public.film;

    IF v_film_id IS NULL THEN
        RAISE EXCEPTION 'Could not generate film_id.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'film'
          AND column_name = 'fulltext'
    )
    INTO v_has_fulltext;

    IF v_has_fulltext THEN
        INSERT INTO public.film (
            film_id,
            title,
            release_year,
            language_id,
            rental_duration,
            rental_rate,
            replacement_cost,
            last_update,
            fulltext
        )
        VALUES (
            v_film_id,
            btrim(p_title),
            p_release_year,
            v_language_id,
            3,
            4.99,
            19.99,
            current_timestamp,
            to_tsvector('pg_catalog.english', btrim(p_title))
        );
    ELSE
        INSERT INTO public.film (
            film_id,
            title,
            release_year,
            language_id,
            rental_duration,
            rental_rate,
            replacement_cost,
            last_update
        )
        VALUES (
            v_film_id,
            btrim(p_title),
            p_release_year,
            v_language_id,
            3,
            4.99,
            19.99,
            current_timestamp
        );
    END IF;

    RETURN v_film_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Insert failed: movie "%" already exists.', btrim(p_title);
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Insert failed because a referenced row is missing.';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Insert failed for movie "%": %', btrim(p_title), SQLERRM;
END;
$$;

/*
Explanation comments:

Task 1.
The view finds the current quarter and year from CURRENT_DATE, so it updates by itself
when a new quarter starts.

Only categories with sales appear because the query is built from actual payment data.
If a category has no sales in the current quarter, it simply has no row in the result.

The sample dvd_rental database has no real current-year data, so I checked the view by
comparing it with the same logic written as a normal SELECT query.

Data that should not appear: categories that had sales before, but not in the current quarter.

Task 2.
The parameter is needed so the function can return results for any quarter, not only the current one.

If the quarter format is wrong, the function raises an error.
If there is no data for that quarter, it just returns no rows.

Task 3.
Here, “most popular” means the film with the highest number of rentals in that country.

If there is a tie, it is resolved by title and then by film_id, so the result stays consistent.

If a country has no data, the function still returns that country, but puts '-' in the film columns.

Task 4.
The function uses ILIKE for partial search. For example, 'love' becomes '%love%',
so it finds titles that contain that word anywhere.

The search is case-insensitive. On large data, pattern search and stock checking can be slow,
so the query first filters matching films in stock and only then gets extra details.

If several movies match, all of them are returned with row numbers.
If nothing matches, the function returns one message row.

Task 5.
The function creates a new film_id using MAX(film_id) + 1.

Before insert, it checks whether the same movie title already exists.
If it exists, the function raises an error and stops.

It also checks whether the language exists in the language table.
If insert fails for any reason, PostgreSQL cancels the statement, so the database stays consistent.
*/
