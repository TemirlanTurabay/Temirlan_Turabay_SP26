/*Task1*/

WITH sales_by_channel AS (
    SELECT
        c.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold)::numeric AS amount_sold
    FROM sh.sales s
    JOIN sh.customers cu
        ON s.cust_id = cu.cust_id
    JOIN sh.countries c
        ON cu.country_id = c.country_id
    JOIN sh.times t
        ON s.time_id = t.time_id
    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id
    WHERE c.country_region IN ('Americas', 'Asia', 'Europe')
      AND t.calendar_year BETWEEN 1998 AND 2001
    GROUP BY
        c.country_region,
        t.calendar_year,
        ch.channel_desc
),

channel_percentages AS (
    SELECT
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        ROUND(
            amount_sold * 100.0
            / SUM(amount_sold) OVER (
                PARTITION BY country_region, calendar_year
            ),
            2
        ) AS pct_by_channels
    FROM sales_by_channel
),

with_previous_period AS (
    SELECT
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        pct_by_channels,
        LAG(pct_by_channels) OVER (
            PARTITION BY country_region, channel_desc
            ORDER BY calendar_year
        ) AS pct_previous_period
    FROM channel_percentages
)

SELECT
    country_region,
    calendar_year,
    channel_desc,

    ROUND(amount_sold, 2) AS amount_sold,

    pct_by_channels AS "% BY CHANNELS",

    pct_previous_period AS "% PREVIOUS PERIOD",

    ROUND(
        pct_by_channels - pct_previous_period,
        2
    ) AS "% DIFF"

FROM with_previous_period
WHERE calendar_year BETWEEN 1999 AND 2001
ORDER BY
    country_region ASC,
    calendar_year ASC,
    channel_desc ASC;

/*Task2*/

WITH daily_sales AS (
    SELECT
        t.calendar_year,
        t.calendar_week_number,
        t.time_id,
        TRIM(t.day_name) AS day_name,
        COALESCE(SUM(s.amount_sold), 0)::numeric AS sales
    FROM sh.times t
    LEFT JOIN sh.sales s
        ON t.time_id = s.time_id
    WHERE t.time_id BETWEEN DATE '1999-12-04' AND DATE '1999-12-27'
    GROUP BY
        t.calendar_year,
        t.calendar_week_number,
        t.time_id,
        TRIM(t.day_name)
),

calculated_sales AS (
    SELECT
        calendar_year,
        calendar_week_number,
        time_id,
        day_name,
        sales,

        SUM(sales) OVER (
            PARTITION BY calendar_week_number
            ORDER BY time_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cum_sum,

        CASE
            WHEN day_name = 'Monday' THEN
                AVG(sales) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING
                )

            WHEN day_name = 'Friday' THEN
                AVG(sales) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING
                )

            ELSE
                AVG(sales) OVER (
                    ORDER BY time_id
                    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
                )
        END AS centered_3_day_avg

    FROM daily_sales
)

SELECT
    calendar_week_number,
    time_id,
    day_name,
    ROUND(sales, 2) AS sales,
    ROUND(cum_sum, 2) AS cum_sum,
    ROUND(centered_3_day_avg, 2) AS centered_3_day_avg
FROM calculated_sales
WHERE calendar_year = 1999
  AND calendar_week_number IN (49, 50, 51)
ORDER BY
    calendar_week_number,
    time_id;

/*Task3*/

WITH daily_sales AS (
    SELECT
        t.time_id,
        TRIM(t.day_name) AS day_name,
        SUM(s.amount_sold)::numeric AS sales
    FROM sh.sales s
    JOIN sh.times t
        ON s.time_id = t.time_id
    WHERE t.time_id BETWEEN DATE '1999-12-06' AND DATE '1999-12-26'
    GROUP BY
        t.time_id,
        TRIM(t.day_name)
)

SELECT
    time_id,
    day_name,
    ROUND(sales, 2) AS sales,

    ROUND(
        AVG(sales) OVER (
            ORDER BY time_id
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ),
        2
    ) AS centered_3_day_avg

FROM daily_sales
ORDER BY time_id;

WITH daily_sales AS (
    SELECT
        t.time_id,
        SUM(s.amount_sold)::numeric AS sales
    FROM sh.sales s
    JOIN sh.times t
        ON s.time_id = t.time_id
    WHERE t.time_id BETWEEN DATE '1999-12-01' AND DATE '1999-12-31'
    GROUP BY
        t.time_id
)

SELECT
    time_id,
    ROUND(sales, 2) AS sales,

    ROUND(
        SUM(sales) OVER (
            ORDER BY time_id::timestamp
            RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_7_day_sales

FROM daily_sales
ORDER BY time_id;

WITH monthly_channel_sales AS (
    SELECT
        t.calendar_year,
        t.calendar_month_number,
        ch.channel_desc,
        SUM(s.amount_sold)::numeric AS sales
    FROM sh.sales s
    JOIN sh.times t
        ON s.time_id = t.time_id
    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id
    WHERE t.calendar_year = 2000
    GROUP BY
        t.calendar_year,
        t.calendar_month_number,
        ch.channel_desc
)

SELECT
    calendar_year,
    calendar_month_number,
    channel_desc,
    ROUND(sales, 2) AS sales,

    ROUND(
        SUM(sales) OVER (
            ORDER BY calendar_month_number
            GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS current_and_previous_month_sales

FROM monthly_channel_sales
ORDER BY
    calendar_month_number,
    channel_desc;

