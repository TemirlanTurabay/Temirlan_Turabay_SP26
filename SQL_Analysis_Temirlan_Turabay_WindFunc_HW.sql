/*
Task 1:
I first aggregate sales by channel and customer, because one customer can have many sales rows.
Then I use SUM() OVER (PARTITION BY channel_desc) to calculate the total sales inside each channel.
I use ROW_NUMBER() to select exactly top 5 customers per channel.
I do not use window frames such as ROWS BETWEEN / RANGE BETWEEN, because they are not allowed.
*/

WITH customer_channel_sales AS (
    SELECT
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.customers c
        ON s.cust_id = c.cust_id
    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id
    GROUP BY
        ch.channel_desc,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name
),

sales_with_kpi AS (
    SELECT
        channel_desc,
        cust_last_name,
        cust_first_name,
        amount_sold,
        amount_sold * 100.0 / SUM(amount_sold) OVER (
            PARTITION BY channel_desc
        ) AS sales_percentage,
        ROW_NUMBER() OVER (
            PARTITION BY channel_desc
            ORDER BY amount_sold DESC
        ) AS rn
    FROM customer_channel_sales
)

SELECT
    channel_desc,
    cust_last_name,
    cust_first_name,
    TO_CHAR(amount_sold, 'FM999999999990.00') AS amount_sold,
    TO_CHAR(sales_percentage, 'FM999999990.0000') || ' %' AS sales_percentage
FROM sales_with_kpi
WHERE rn <= 5
ORDER BY
    channel_desc,
    amount_sold DESC;

/*
Task 2:
I use window functions with PARTITION BY product name to calculate quarterly and yearly sales.
The final SELECT uses DISTINCT because window functions return values for every sales row.
*/

WITH product_sales AS (
    SELECT
        p.prod_name AS product_name,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 1 THEN s.amount_sold 
                ELSE 0 
            END) OVER (PARTITION BY p.prod_name) AS q1,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 2 THEN s.amount_sold 
                ELSE 0 
            END) OVER (PARTITION BY p.prod_name) AS q2,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 3 THEN s.amount_sold 
                ELSE 0 
            END) OVER (PARTITION BY p.prod_name) AS q3,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 4 THEN s.amount_sold 
                ELSE 0 
            END) OVER (PARTITION BY p.prod_name) AS q4,

        SUM(s.amount_sold) OVER (PARTITION BY p.prod_name) AS year_sum

    FROM sh.sales s
    JOIN sh.products p
        ON s.prod_id = p.prod_id
    JOIN sh.times t
        ON s.time_id = t.time_id
    JOIN sh.customers c
        ON s.cust_id = c.cust_id
    JOIN sh.countries co
        ON c.country_id = co.country_id

    WHERE p.prod_category = 'Photo'
      AND co.country_region = 'Asia'
      AND t.calendar_year = 2000
)

SELECT DISTINCT
    product_name,
    TO_CHAR(q1, 'FM999999999990.00') AS q1,
    TO_CHAR(q2, 'FM999999999990.00') AS q2,
    TO_CHAR(q3, 'FM999999999990.00') AS q3,
    TO_CHAR(q4, 'FM999999999990.00') AS q4,
    TO_CHAR(year_sum, 'FM999999999990.00') AS year_sum
FROM product_sales
ORDER BY
    year_sum DESC;

/*
Task 3:
I first aggregate sales by channel, year, and customer.
Then I rank customers separately inside each channel and each year.
After that I filter customers with rank <= 300.
Finally, I keep only customers who appear in the top 300 in all three years.
*/

WITH customer_year_sales AS (
    SELECT
        ch.channel_desc,
        t.calendar_year,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.customers c
        ON s.cust_id = c.cust_id
    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id
    JOIN sh.times t
        ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY
        ch.channel_desc,
        t.calendar_year,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name
),

ranked_customers AS (
    SELECT
        channel_desc,
        calendar_year,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold,
        RANK() OVER (
            PARTITION BY channel_desc, calendar_year
            ORDER BY SUM(amount_sold) DESC
        ) AS sales_rank
    FROM customer_year_sales
    GROUP BY
        channel_desc,
        calendar_year,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold
),

top_customers AS (
    SELECT
        channel_desc,
        calendar_year,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold
    FROM ranked_customers
    WHERE sales_rank <= 300
)

SELECT
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name,
    TO_CHAR(SUM(amount_sold), 'FM999999999990.00') AS total_sales
FROM top_customers
GROUP BY
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name
HAVING COUNT(DISTINCT calendar_year) = 3
ORDER BY
    channel_desc,
    SUM(amount_sold) DESC;

/*
Task 4:
I use window functions with PARTITION BY month and product category.
This allows sales for Americas and Europe to be calculated without GROUP BY.
*/

WITH monthly_category_sales AS (
    SELECT
        t.calendar_month_number,
        t.calendar_month_desc,
        p.prod_category,

        SUM(CASE
                WHEN co.country_region = 'Americas' THEN s.amount_sold
                ELSE 0
            END) OVER (
                PARTITION BY t.calendar_month_number, t.calendar_month_desc, p.prod_category
            ) AS americas_sales,

        SUM(CASE
                WHEN co.country_region = 'Europe' THEN s.amount_sold
                ELSE 0
            END) OVER (
                PARTITION BY t.calendar_month_number, t.calendar_month_desc, p.prod_category
            ) AS europe_sales

    FROM sh.sales s
    JOIN sh.times t
        ON s.time_id = t.time_id
    JOIN sh.products p
        ON s.prod_id = p.prod_id
    JOIN sh.customers c
        ON s.cust_id = c.cust_id
    JOIN sh.countries co
        ON c.country_id = co.country_id

    WHERE t.calendar_year = 2000
      AND t.calendar_month_number IN (1, 2, 3)
      AND co.country_region IN ('Europe', 'Americas')
)

SELECT DISTINCT
    calendar_month_desc,
    prod_category,
    TO_CHAR(americas_sales, 'FM999G999G999G990') AS "Americas SALES",
    TO_CHAR(europe_sales, 'FM999G999G999G990') AS "Europe SALES"
FROM monthly_category_sales
ORDER BY
    calendar_month_number,
    prod_category;