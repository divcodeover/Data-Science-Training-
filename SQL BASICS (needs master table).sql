USE enterprise_retail_db;

/*
================================================================================
PART 1: THEORETICAL FOUNDATIONS & ARCHITECTURAL REFERENCE
================================================================================

1. RDBMS CONSTRAINTS:
   - PRIMARY KEY : Uniquely identifies each row (Entity Integrity = NOT NULL + UNIQUE).
   - FOREIGN KEY : Enforces referential integrity between tables.
   - UNIQUE      : Ensures all values in a column are distinct (allows NULLs in SQL standard).
   - NOT NULL    : Prevents insertion of missing/empty values.
   - CHECK       : Validates that values satisfy a boolean expression (e.g., quantity > 0).
   - DEFAULT     : Automatically populates a predefined value if none is provided.

2. NORMALISATION QUICK-REFERENCE (PRACTICAL INTUITION):
   - 1NF (Atomic Values)      : No multi-valued attributes, no repeating groups.
   - 2NF (Full Functional)    : In 1NF + No partial dependencies (all non-keys depend on the whole PK).
   - 3NF (Transitive Freedom) : In 2NF + No transitive dependencies (non-keys depend ONLY on PK).

3. SQL SUB-LANGUAGES:
   - DDL (Data Definition Language) : CREATE, ALTER, DROP, TRUNCATE, RENAME
   - DML (Data Manipulation Language): INSERT, UPDATE, DELETE
   - DQL (Data Query Language)       : SELECT
   - DCL (Data Control Language)    : GRANT, REVOKE
   - TCL (Transaction Control Lang) : COMMIT, ROLLBACK, SAVEPOINT

4. THE LOGICAL ORDER OF QUERY EXECUTION (CRITICAL INTERVIEW CONCEPT):
   Written Order:                Logical Execution Order:
   1. SELECT                     1. FROM & JOIN     (Identify and combine tables)
   2. FROM                       2. WHERE           (Filter raw individual rows)
   3. WHERE                      3. GROUP BY        (Aggregate rows into groups)
   4. GROUP BY                   4. HAVING          (Filter aggregated groups)
   5. HAVING                     5. SELECT          (Evaluate expressions & aliases)
   6. ORDER BY                   6. DISTINCT        (Eliminate duplicate rows)
   7. LIMIT                      7. ORDER BY        (Sort final row set)
                                 8. LIMIT / OFFSET  (Restrict output row count)

   * Why it matters: You CANNOT use a SELECT alias in a WHERE clause because 
     WHERE executes before SELECT!
================================================================================
*/

-- -----------------------------------------------------------------------------
-- DEMO 1: Column Aliasing, Arithmetic, and WHERE Filtering
-- Task: Retrieve employee names, current annual salary, and calculated monthly 
--       salary for employees earning over $80,000 in Departments 2 or 3.
-- -----------------------------------------------------------------------------
/*
Logical Execution Narration:
1. FROM employees -> Access employee records.
2. WHERE salary > 80000 AND department_id IN (2, 3) -> Filter rows before calculation.
3. SELECT first_name, last_name, salary, salary/12 -> Evaluate columns and aliases.
4. ORDER BY annual_salary DESC -> Sort output.
*/
SELECT 
    first_name,
    last_name,
    salary AS annual_salary,
    ROUND(salary / 12, 2) AS monthly_salary,
    department_id
FROM employees
WHERE salary > 80000.00
  AND department_id IN (2, 3)
ORDER BY annual_salary DESC;


-- -----------------------------------------------------------------------------
-- DEMO 2: Pattern Matching (LIKE), IS NULL, and Boolean Precedence
-- Task: Find all customers in the USA whose names start with 'A', 'B', or 'J',
--       OR who belong to the 'Corporate' segment with an email from gmail/outlook.
-- -----------------------------------------------------------------------------
/*
Logical Execution Narration:
- Notice parentheses around AND / OR to enforce explicit operator precedence!
- AND takes precedence over OR by default.
*/
SELECT 
    customer_id,
    customer_name,
    email,
    country,
    segment
FROM customers
WHERE (country = 'USA' AND (customer_name LIKE 'A%' OR customer_name LIKE 'B%' OR customer_name LIKE 'J%'))
   OR (segment = 'Corporate' AND (email LIKE '%@gmail.com' OR email LIKE '%@outlook.com'))
ORDER BY customer_name ASC;


-- -----------------------------------------------------------------------------
-- DEMO 3: String Functions & Date Arithmetic
-- Task: Calculate shipping turnaround time in days, extract order year/month, 
--       and format customer IDs into an enterprise masking format.
-- -----------------------------------------------------------------------------
/*
Functions Used:
- CONCAT, LPAD for string formatting.
- DATEDIFF(end_date, start_date) for duration.
- DATE_FORMAT, EXTRACT for date manipulation.
*/
SELECT 
    order_id,
    CONCAT('CUST-ID-', LPAD(customer_id, 5, '0')) AS formatted_customer_code,
    order_date,
    ship_date,
    DATEDIFF(ship_date, order_date) AS fulfillment_days,
    DATE_FORMAT(order_date, '%M %Y') AS order_period,
    EXTRACT(QUARTER FROM order_date) AS order_quarter,
    ship_mode
FROM orders
WHERE ship_date IS NOT NULL
  AND order_status = 'Completed'
ORDER BY fulfillment_days DESC;


-- -----------------------------------------------------------------------------
-- DEMO 4: Aggregations, COUNT(*) vs COUNT(col), and NULL Handling
-- Task: Compare total rows vs assigned sales reps and find pricing statistics
--       for all products in the catalog.
-- -----------------------------------------------------------------------------
/*
Key Concept:
- COUNT(*) counts every physical row.
- COUNT(sales_rep_id) skips NULL values!
*/
SELECT 
    COUNT(*) AS total_orders_placed,
    COUNT(sales_rep_id) AS orders_with_sales_rep,
    COUNT(*) - COUNT(sales_rep_id) AS self_service_orders_without_rep,
    COUNT(DISTINCT customer_id) AS unique_transacting_customers
FROM orders;

SELECT 
    COUNT(product_id) AS total_products,
    ROUND(MIN(unit_price), 2) AS min_price,
    ROUND(MAX(unit_price), 2) AS max_price,
    ROUND(AVG(unit_price), 2) AS avg_price,
    ROUND(SUM(unit_price * stock_quantity), 2) AS total_inventory_valuation
FROM products;


-- -----------------------------------------------------------------------------
-- DEMO 5: GROUP BY & The Crucial Difference Between WHERE and HAVING
-- Task: For all 'Completed' orders, aggregate total units sold and gross sales 
--       per product_id. Return ONLY products generating over $10,000 in revenue.
-- -----------------------------------------------------------------------------
/*
Logical Execution Breakdown:
1. FROM order_items
2. JOIN orders (WHERE evaluates row-level attributes BEFORE grouping)
3. GROUP BY product_id (Aggregates quantities & revenues per bucket)
4. HAVING gross_revenue > 10000 (Filters GROUPS after aggregation!)
5. SELECT (Generates final projected columns)
6. ORDER BY gross_revenue DESC
*/
SELECT 
    product_id,
    SUM(quantity) AS total_units_sold,
    COUNT(DISTINCT order_id) AS distinct_orders_count,
    ROUND(AVG(discount_pct) * 100, 1) AS avg_discount_pct,
    ROUND(SUM(quantity * unit_price), 2) AS gross_revenue,
    ROUND(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS net_revenue
FROM order_items
GROUP BY product_id
HAVING net_revenue > 10000.00
ORDER BY net_revenue DESC;


-- -----------------------------------------------------------------------------
-- DEMO 6: Conditional Logic via CASE WHEN with Multi-Level Aggregation
-- Task: Classify inventory value risk based on stock levels and unit price, 
--       and calculate employee compensation tiers.
-- -----------------------------------------------------------------------------
SELECT 
    product_name,
    unit_price,
    stock_quantity,
    (unit_price * stock_quantity) AS stock_value,
    CASE 
        WHEN (unit_price * stock_quantity) >= 50000 THEN 'Critical High-Value Capital'
        WHEN (unit_price * stock_quantity) BETWEEN 15000 AND 49999.99 THEN 'Moderate Working Capital'
        ELSE 'Low Capital Exposure'
    END AS capital_exposure_tier,
    CASE 
        WHEN stock_quantity < 50 THEN 'URGENT: Reorder Required'
        WHEN stock_quantity BETWEEN 50 AND 150 THEN 'Optimal Stock'
        ELSE 'Excess Inventory'
    END AS inventory_health_status
FROM products
ORDER BY stock_value DESC;


-- =============================================================================
-- PART 3: 12 STUDENT PRACTICE EXERCISES (WITH EMBEDDED SOLUTIONS)
-- =============================================================================

-- --- EXERCISE 1 ---
-- Task: Select all products from category_id = 1 or 3 with a unit_price >= 500,
--       sorted by unit_price in descending order.
-- EXPECTED: Laptops, Standing Desks, Monitors, etc.
-- YOUR QUERY HERE:
SELECT product_id, product_name, category_id, unit_price
FROM products
WHERE category_id IN (1, 3) 
  AND unit_price >= 500.00
ORDER BY unit_price DESC;


-- --- EXERCISE 2 ---
-- Task: Find all customers located in 'USA' whose city contains the letter 'e' 
--       as the second character (Hint: use underscore wildcard '_e%').
-- YOUR QUERY HERE:
SELECT customer_id, customer_name, city, country
FROM customers
WHERE country = 'USA' 
  AND city LIKE '_e%';


-- --- EXERCISE 3 ---
-- Task: Find all orders placed between '2024-02-01' and '2024-04-30' that used 
--       'Express' or 'Same Day' shipping and have a completed status.
-- YOUR QUERY HERE:
SELECT order_id, customer_id, order_date, ship_mode, order_status
FROM orders
WHERE order_date BETWEEN '2024-02-01' AND '2024-04-30'
  AND ship_mode IN ('Express', 'Same Day')
  AND order_status = 'Completed'
ORDER BY order_date ASC;


-- --- EXERCISE 4 ---
-- Task: Display each product's name, unit_price, cost_price, and calculate:
--       1. Unit Profit ($): unit_price - cost_price
--       2. Profit Margin (%): ((unit_price - cost_price) / unit_price) * 100 rounded to 2 decimals.
--       Filter to show only products with a profit margin >= 40%.
-- YOUR QUERY HERE:
SELECT 
    product_name,
    unit_price,
    cost_price,
    ROUND(unit_price - cost_price, 2) AS unit_profit_usd,
    ROUND(((unit_price - cost_price) / unit_price) * 100, 2) AS profit_margin_pct
FROM products
WHERE (((unit_price - cost_price) / unit_price) * 100) >= 40.00
ORDER BY profit_margin_pct DESC;


-- --- EXERCISE 5 ---
-- Task: Determine how many orders were placed by each ship_mode.
--       Display ship_mode and total_order_count, sorted from highest to lowest.
-- YOUR QUERY HERE:
SELECT 
    ship_mode,
    COUNT(*) AS total_order_count
FROM orders
GROUP BY ship_mode
ORDER BY total_order_count DESC;


-- --- EXERCISE 6 ---
-- Task: Standardize customer emails: Display customer_id, full customer name, 
--       email in lowercase, length of the customer name, and extract only the 
--       domain from the email (e.g. 'acmeglobal.com' from 'purchasing@acmeglobal.com').
-- YOUR QUERY HERE:
SELECT 
    customer_id,
    UPPER(customer_name) AS clean_customer_name,
    LOWER(email) AS clean_email,
    CHAR_LENGTH(customer_name) AS name_char_count,
    SUBSTRING(email, INSTR(email, '@') + 1) AS email_domain
FROM customers;


-- --- EXERCISE 7 ---
-- Task: Using date functions, determine the tenure of all employees in full months 
--       as of '2026-01-01'. Display employee_id, full name, hire_date, and months_of_service.
-- YOUR QUERY HERE:
SELECT 
    employee_id,
    CONCAT(first_name, ' ', last_name) AS full_name,
    hire_date,
    TIMESTAMPDIFF(MONTH, hire_date, '2026-01-01') AS months_of_service
FROM employees
ORDER BY months_of_service DESC;


-- --- EXERCISE 8 ---
-- Task: Categorize all orders using CASE WHEN into:
--       - 'Self-Service' if sales_rep_id IS NULL
--       - 'Assisted Enterprise' if sales_rep_id IS NOT NULL
--       Count the number of orders in each channel.
-- YOUR QUERY HERE:
SELECT 
    CASE 
        WHEN sales_rep_id IS NULL THEN 'Self-Service'
        ELSE 'Assisted Enterprise'
    END AS sales_channel,
    COUNT(*) AS total_orders
FROM orders
GROUP BY 
    CASE 
        WHEN sales_rep_id IS NULL THEN 'Self-Service'
        ELSE 'Assisted Enterprise'
    END;


-- --- EXERCISE 9 ---
-- Task: Calculate the total line-item count, total quantity sold, average unit price, 
--       and total net revenue (factoring discount_pct) for order_id = 101.
-- YOUR QUERY HERE:
SELECT 
    order_id,
    COUNT(order_item_id) AS total_line_items,
    SUM(quantity) AS total_units_sold,
    ROUND(AVG(unit_price), 2) AS avg_unit_price,
    ROUND(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS total_net_revenue
FROM order_items
WHERE order_id = 101
GROUP BY order_id;


-- --- EXERCISE 10 ---
-- Task: Find the total number of customers in each country and segment combination.
--       Filter out any groups that have fewer than 2 customers.
-- YOUR QUERY HERE:
SELECT 
    country,
    segment,
    COUNT(customer_id) AS customer_count
FROM customers
GROUP BY country, segment
HAVING COUNT(customer_id) >= 2
ORDER BY country ASC, customer_count DESC;


-- --- EXERCISE 11 ---
-- Task: Find all customers who placed orders in multiple distinct ship modes.
--       Return customer_id and the count of distinct ship modes used (HAVING count > 1).
-- YOUR QUERY HERE:
SELECT 
    customer_id,
    COUNT(DISTINCT ship_mode) AS distinct_ship_modes_used
FROM orders
GROUP BY customer_id
HAVING COUNT(DISTINCT ship_mode) > 1;


-- --- EXERCISE 12 (Comprehensive Integration Challenge) ---
-- Task: Analyze all order items with quantity >= 5. Group by product_id and calculate:
--       1. Total volume sold (sum of quantity).
--       2. Total revenue generated after discounts.
--       3. Pricing Category using CASE: 'High Ticket' if avg unit_price > 1000, else 'Standard'.
--       Only include product groups that generated a net revenue of at least $10,000.
--       Sort by net revenue descending, and limit to the Top 3 products.
-- YOUR QUERY HERE:
SELECT 
    product_id,
    SUM(quantity) AS bulk_volume_sold,
    ROUND(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS bulk_net_revenue,
    CASE 
        WHEN AVG(unit_price) > 1000.00 THEN 'High Ticket'
        ELSE 'Standard Ticket'
    END AS ticket_classification
FROM order_items
WHERE quantity >= 5
GROUP BY product_id
HAVING bulk_net_revenue >= 10000.00
ORDER BY bulk_net_revenue DESC
LIMIT 3;

-- =============================================================================
-- END OF DAY 1 SQL FOUNDATIONS SCRIPT
-- =============================================================================