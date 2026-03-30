/*
Task 2
1. Create table ‘table_to_delete’ and fill it with the following query:
Afftected rows: 10000000
Time consumption: 9.179s
*/

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) AS x;

/*
2. Lookup how much space this table consumes with the following query:
Space consumption: 575MB
*/

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *,
           total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

/*
3. Issue the following DELETE operation on ‘table_to_delete’:
               DELETE FROM table_to_delete
               WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; -- removes 1/3 of all rows
      a) Note how much time it takes to perform this DELETE statement;
      Affected rows: 3333333
      Time consumption: 6.643s
      b) Lookup how much space this table consumes after previous DELETE;
      Space consumption: 575 MB
      c) Perform the following command (if you're using DBeaver, press Ctrl+Shift+O to observe server output (VACUUM results)): VACUUM FULL VERBOSE table_to_delete;
      очистка "public.table_to_delete"
      "public.table_to_delete": найдено удаляемых версий строк: 1688186, неудаляемых: 6666667, просмотрено страниц: 73536
      d) Check space consumption of the table once again and make conclusions;
      Space consumption: 383 MB
      e) Recreate ‘table_to_delete’ table;
*/ 

DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *,
           total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

VACUUM FULL VERBOSE table_to_delete;

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *,
           total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

DROP TABLE table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) AS x;

/*
4. Issue the following TRUNCATE operation: TRUNCATE table_to_delete;
      a) Note how much time it takes to perform this TRUNCATE statement.
      Time consumtion: 0.063s
      b) Compare with previous results and make conclusion.
      Compared to the previous DELETE result, TRUNCATE was much faster. 
      DELETE needed 6.643 seconds because it removed rows one by one, 
      but TRUNCATE cleared the whole table at once. So, I can conclude 
      that TRUNCATE is much better when we need to remove all data 
      from a table quickly.
      c) Check space consumption of the table once again and make conclusions;
      Space consumption: 8192 bytes
      After TRUNCATE, the table size became only 8192 bytes, 
      which is very small. This shows that TRUNCATE not only 
      removes the rows, but also frees almost all table space 
      immediately. So, the conclusion is that TRUNCATE is much 
      more effective than DELETE for both speed and space when 
      we want to clear the whole table.
*/

TRUNCATE table_to_delete;

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *,
           total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

/*
5. Hand over your investigation's results to your mentor. The results must include:
      a) Space consumption of ‘table_to_delete’ table before and after each operation;
      b) Compare DELETE and TRUNCATE in terms of:
execution time
disk space usage
transaction behavior
rollback possibility
      c) Explain:
why DELETE does not free space immediately
why VACUUM FULL changes table size
why TRUNCATE behaves differently
how these operations affect performance and storage
*/

/*
5a) The space consumption of table_to_delete changed like this: 
before everything the table size was 575 MB. After DELETE, it still stayed 575 MB, 
which means the space was not released right away. After VACUUM FULL, 
the size became 383 MB, because PostgreSQL rebuilt the table and 
removed empty space. After TRUNCATE, the size became only 8192 bytes, 
so almost all space was freed.

5b) DELETE and TRUNCATE are different in several ways. 
In execution time, TRUNCATE was much faster (0.063 s) than DELETE 
(6.643 s). In disk space usage, DELETE did not reduce the table size 
immediately, but TRUNCATE reduced it almost completely. In transaction 
behavior, DELETE works row by row, while TRUNCATE works on the whole 
table at once. About rollback, both can be rolled back if they are used 
inside a transaction in PostgreSQL, but TRUNCATE is still much 
faster because it does not process every row separately.

5c) DELETE does not free space immediately because it only marks rows 
as deleted, and the physical space stays in the table until cleanup 
happens. VACUUM FULL changes the table size because it rewrites 
the whole table and removes the unused space physically. 
TRUNCATE behaves differently because it clears the whole table 
directly without scanning and deleting rows one by one. 
Because of this, DELETE is slower and keeps old space longer, 
while TRUNCATE gives better performance and frees storage much faster.
*/
