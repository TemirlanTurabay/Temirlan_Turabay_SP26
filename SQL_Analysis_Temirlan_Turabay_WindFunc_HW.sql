/*
Task 1:

I first used a grouped CTE to calculate the total payment amount 
for each customer in each store. In the dvdrental database, there 
is no separate sales channel table, so store_id is used as the 
closest replacement for channel_desc. Then I used another CTE 
to calculate the total sales for each store, because this total 
is needed to calculate sales_percentage, which shows how much 
each customer contributed to the store’s total sales. Since 
window functions are not allowed, I did not use ROW_NUMBER(), 
RANK(), or OVER(). Instead, I used a correlated subquery to select 
only customers who have fewer than five customers with higher 
sales in the same store.
*/

WITH customer_channel_sales AS (
    SELECT
        'Store ' || c.store_id AS channel_desc,
        c.customer_id AS cust_id,
        c.last_name AS cust_last_name,
        c.first_name AS cust_first_name,
        SUM(p.amount) AS amount_sold
    FROM public.payment p
    JOIN public.customer c
        ON p.customer_id = c.customer_id
    GROUP BY
        c.store_id,
        c.customer_id,
        c.last_name,
        c.first_name
),

channel_totals AS (
    SELECT
        channel_desc,
        SUM(amount_sold) AS total_channel_sales
    FROM customer_channel_sales
    GROUP BY channel_desc
)

SELECT
    ccs.channel_desc,
    ccs.cust_id,
    ccs.cust_last_name,
    ccs.cust_first_name,

    TO_CHAR(ccs.amount_sold, 'FM9999999990.00') AS amount_sold,

    TO_CHAR(
        (ccs.amount_sold / ct.total_channel_sales) * 100,
        'FM999999990.0000'
    ) || ' %' AS sales_percentage

FROM customer_channel_sales ccs
JOIN channel_totals ct
    ON ccs.channel_desc = ct.channel_desc

WHERE (
    SELECT COUNT(*)
    FROM customer_channel_sales ccs2
    WHERE ccs2.channel_desc = ccs.channel_desc
      AND (
          ccs2.amount_sold > ccs.amount_sold
          OR (
              ccs2.amount_sold = ccs.amount_sold
              AND ccs2.cust_id < ccs.cust_id
          )
      )
) < 5

ORDER BY
    ccs.channel_desc,
    ccs.amount_sold DESC;

/*
Task 2:

I used conditional aggregation with SUM(CASE WHEN) because it is 
simpler than crosstab and still creates separate columns for 
q1, q2, q3, and q4. Since the dvdrental database does not have 
the original sales, products, countries, or region tables from 
the sample task, I used payment as the sales table, film as the 
product table, category as the product category, and payment_date 
to calculate the year and quarters. The database also does not 
have a region column, so Asian countries are filtered manually 
through the country table. YEAR_SUM is calculated by summing all 
payments for each film during the selected year, and the final 
result is sorted from the highest yearly sales to the lowest.
*/

SELECT
    f.title AS product_name,

    TO_CHAR(SUM(CASE WHEN EXTRACT(QUARTER FROM p.payment_date) = 1 THEN p.amount ELSE 0 END), 'FM9999999990.00') AS q1,
    TO_CHAR(SUM(CASE WHEN EXTRACT(QUARTER FROM p.payment_date) = 2 THEN p.amount ELSE 0 END), 'FM9999999990.00') AS q2,
    TO_CHAR(SUM(CASE WHEN EXTRACT(QUARTER FROM p.payment_date) = 3 THEN p.amount ELSE 0 END), 'FM9999999990.00') AS q3,
    TO_CHAR(SUM(CASE WHEN EXTRACT(QUARTER FROM p.payment_date) = 4 THEN p.amount ELSE 0 END), 'FM9999999990.00') AS q4,

    TO_CHAR(SUM(p.amount), 'FM9999999990.00') AS year_sum

FROM public.payment p
JOIN public.rental r
    ON p.rental_id = r.rental_id
JOIN public.inventory i
    ON r.inventory_id = i.inventory_id
JOIN public.film f
    ON i.film_id = f.film_id
JOIN public.film_category fc
    ON f.film_id = fc.film_id
JOIN public.category cat
    ON fc.category_id = cat.category_id
JOIN public.customer c
    ON p.customer_id = c.customer_id
JOIN public.address a
    ON c.address_id = a.address_id
JOIN public.city ci
    ON a.city_id = ci.city_id
JOIN public.country co
    ON ci.country_id = co.country_id

WHERE cat.name = 'Documentary'
  AND EXTRACT(YEAR FROM p.payment_date) = 2017
  AND co.country IN (
      'China',
      'India',
      'Japan',
      'Kazakhstan',
      'Malaysia',
      'Pakistan',
      'Philippines',
      'Thailand',
      'Vietnam',
      'Turkey'
  )

GROUP BY
    f.title

ORDER BY
    SUM(p.amount) DESC;

/*
Task 3:

I used grouped CTEs to calculate customer sales separately for 
each store and each selected period. In the original task, 
the data is separated by sales channels and years, but the 
dvdrental database does not contain a channels table or the 
years 1998, 1999, and 2001. Therefore, I used store_id as the 
closest replacement for sales channel and January, February, 
and March 2017 as the three comparison periods. Since window 
functions are not allowed, I avoided ROW_NUMBER(), RANK(), and 
OVER(). Instead, I used a correlated subquery to keep only 
customers who had fewer than 300 customers with higher sales 
in the same store and period. Then I selected only customers 
who appeared in the top 300 in all three periods and calculated 
their total sales only for the same store.
*/

WITH customer_period_channel_sales AS (
    SELECT
        c.store_id AS channel_id,
        'Store ' || c.store_id AS channel_desc,
        c.customer_id AS cust_id,
        c.last_name AS cust_last_name,
        c.first_name AS cust_first_name,
        EXTRACT(MONTH FROM p.payment_date) AS sales_period,
        SUM(p.amount) AS amount_sold
    FROM public.payment p
    JOIN public.customer c
        ON p.customer_id = c.customer_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
      AND EXTRACT(MONTH FROM p.payment_date) IN (1, 2, 3)
    GROUP BY
        c.store_id,
        c.customer_id,
        c.last_name,
        c.first_name,
        EXTRACT(MONTH FROM p.payment_date)
),

top_300_customers AS (
    SELECT
        c1.channel_id,
        c1.channel_desc,
        c1.cust_id,
        c1.cust_last_name,
        c1.cust_first_name,
        c1.sales_period,
        c1.amount_sold
    FROM customer_period_channel_sales c1
    WHERE (
        SELECT COUNT(*)
        FROM customer_period_channel_sales c2
        WHERE c2.channel_id = c1.channel_id
          AND c2.sales_period = c1.sales_period
          AND (
              c2.amount_sold > c1.amount_sold
              OR (
                  c2.amount_sold = c1.amount_sold
                  AND c2.cust_id < c1.cust_id
              )
          )
    ) < 300
),

customers_in_top_300_all_periods AS (
    SELECT
        channel_id,
        channel_desc,
        cust_id,
        cust_last_name,
        cust_first_name
    FROM top_300_customers
    GROUP BY
        channel_id,
        channel_desc,
        cust_id,
        cust_last_name,
        cust_first_name
    HAVING COUNT(DISTINCT sales_period) = 3
)

SELECT
    e.channel_desc,
    e.cust_id,
    e.cust_last_name,
    e.cust_first_name,
    TO_CHAR(SUM(p.amount), 'FM9999999990.00') AS amount_sold

FROM customers_in_top_300_all_periods e
JOIN public.payment p
    ON e.cust_id = p.customer_id
JOIN public.customer c
    ON p.customer_id = c.customer_id
   AND e.channel_id = c.store_id

WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
  AND EXTRACT(MONTH FROM p.payment_date) IN (1, 2, 3)

GROUP BY
    e.channel_desc,
    e.cust_id,
    e.cust_last_name,
    e.cust_first_name

ORDER BY
    e.channel_desc,
    SUM(p.amount) DESC;

/*
Task 4:

I used conditional aggregation with SUM(CASE WHEN) because 
it is a simple way to show Americas sales and Europe sales as 
separate columns. Since the dvdrental database does not have the 
original sales, products, times, or region tables, I used payment 
as the sales table, category as the product category, payment_date 
for the month, and country to separate customers into Americas and 
Europe. The original task uses January, February, and March 2000, 
but dvdrental contains payment data for 2017, so I used January, 
February, and March 2017. The result is grouped by month and product 
category, then ordered by month and product category alphabetically.
*/

SELECT
    TO_CHAR(p.payment_date, 'YYYY-MM') AS calendar_month_desc,
    cat.name AS prod_category,

    TO_CHAR(
        SUM(
            CASE
                WHEN co.country IN ('United States', 'Canada', 'Mexico', 'Brazil', 'Argentina')
                THEN p.amount
                ELSE 0
            END
        ),
        'FM9999999990.00'
    ) AS "Americas SALES",

    TO_CHAR(
        SUM(
            CASE
                WHEN co.country IN ('United Kingdom', 'France', 'Germany', 'Italy', 'Spain', 'Poland')
                THEN p.amount
                ELSE 0
            END
        ),
        'FM9999999990.00'
    ) AS "Europe SALES"

FROM public.payment p
JOIN public.rental r
    ON p.rental_id = r.rental_id
JOIN public.inventory i
    ON r.inventory_id = i.inventory_id
JOIN public.film f
    ON i.film_id = f.film_id
JOIN public.film_category fc
    ON f.film_id = fc.film_id
JOIN public.category cat
    ON fc.category_id = cat.category_id
JOIN public.customer c
    ON p.customer_id = c.customer_id
JOIN public.address a
    ON c.address_id = a.address_id
JOIN public.city ci
    ON a.city_id = ci.city_id
JOIN public.country co
    ON ci.country_id = co.country_id

WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
  AND EXTRACT(MONTH FROM p.payment_date) IN (1, 2, 3)
  AND co.country IN (
      'United States', 'Canada', 'Mexico', 'Brazil', 'Argentina',
      'United Kingdom', 'France', 'Germany', 'Italy', 'Spain', 'Poland'
  )

GROUP BY
    TO_CHAR(p.payment_date, 'YYYY-MM'),
    cat.name

ORDER BY
    calendar_month_desc,
    prod_category;
