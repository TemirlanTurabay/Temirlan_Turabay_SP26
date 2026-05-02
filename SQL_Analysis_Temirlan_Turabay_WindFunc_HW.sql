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
I use conditional aggregation with CASE instead of crosstab because it is simpler and does not require the tablefunc extension.
Each CASE calculates sales only for one quarter.
YEAR_SUM is calculated as the total sales for the whole year.
I keep YEAR_SUM numeric inside the CTE, then format it only in the final SELECT, so sorting works correctly.
*/

WITH product_sales AS (
    SELECT
        p.prod_name AS product_name,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 1 THEN s.amount_sold 
                ELSE 0 
            END) AS q1,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 2 THEN s.amount_sold 
                ELSE 0 
            END) AS q2,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 3 THEN s.amount_sold 
                ELSE 0 
            END) AS q3,

        SUM(CASE 
                WHEN t.calendar_quarter_number = 4 THEN s.amount_sold 
                ELSE 0 
            END) AS q4,

        SUM(s.amount_sold) AS year_sum

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

    GROUP BY
        p.prod_name
)

SELECT
    ps.product_name,
    TO_CHAR(ps.q1, 'FM999999999990.00') AS q1,
    TO_CHAR(ps.q2, 'FM999999999990.00') AS q2,
    TO_CHAR(ps.q3, 'FM999999999990.00') AS q3,
    TO_CHAR(ps.q4, 'FM999999999990.00') AS q4,
    TO_CHAR(ps.year_sum, 'FM999999999990.00') AS year_sum
FROM product_sales ps
ORDER BY
    ps.year_sum DESC;

/*
Task 3: 
I first aggregate sales by channel and customer because one customer can have many purchases.
I filter only the required years before aggregation, so the total sales are calculated only for 1998, 1999, and 2001.
I use RANK() separately inside each sales channel with PARTITION BY channel_desc.
This is needed because the task says calculations should be performed separately for each channel.
I do not use window frames such as ROWS BETWEEN or RANGE BETWEEN, because they are not allowed.
*/

WITH customer_channel_sales AS (
    SELECT
        ch.channel_desc,
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
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name
),

ranked_customers AS (
    SELECT
        channel_desc,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold,
        RANK() OVER (
            PARTITION BY channel_desc
            ORDER BY amount_sold DESC
        ) AS sales_rank
    FROM customer_channel_sales
)

SELECT
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name,
    TO_CHAR(amount_sold, 'FM999999999990.00') AS amount_sold
FROM ranked_customers
WHERE sales_rank <= 300
ORDER BY
    channel_desc,
    amount_sold DESC;

/*
Task 4:
The task asks to compare sales in Europe and Americas, so I use conditional aggregation.
This means I create separate SUM calculations for each region using CASE.
I do not use window functions or window frames here because this task only needs grouped totals.
I group by month and product category because the report must show sales by month and category.
*/

WITH monthly_category_sales AS (
    SELECT
        t.calendar_month_desc,
        p.prod_category,

        SUM(CASE
                WHEN co.country_region = 'Americas' THEN s.amount_sold
                ELSE 0
            END) AS americas_sales,

        SUM(CASE
                WHEN co.country_region = 'Europe' THEN s.amount_sold
                ELSE 0
            END) AS europe_sales

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

    GROUP BY
        t.calendar_month_desc,
        p.prod_category
)

SELECT
    calendar_month_desc,
    prod_category,
    TO_CHAR(americas_sales, 'FM999G999G999G990') AS "Americas SALES",
    TO_CHAR(europe_sales, 'FM999G999G999G990') AS "Europe SALES"
FROM monthly_category_sales
ORDER BY
    calendar_month_desc,
    prod_category;