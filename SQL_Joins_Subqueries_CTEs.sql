USE enterprise_retail_db;

/*
================================================================================
PART 1: RELATIONAL JOINS ARCHITECTURAL REFERENCE & VENN DIAGRAMS
================================================================================

1. WHY JOINS EXIST:
   The relational model normalises data into separate tables (Entities) to eliminate 
   redundancy. Joins reconstruct these logical relationships dynamically at query time.

2. VENN DIAGRAMS & BUSINESS USE CASES:

   A. INNER JOIN (Intersection):
      ┌───────────┐
      │   A ┌─────┼─────┐ B   │  Use Case: "Find completed orders and their product details."
      │     │ A∩B │     │     │  Returns: ONLY rows with matching keys in BOTH tables.
      └─────┴─────┴─────┘
      Syntax: FROM TableA A INNER JOIN TableB B ON A.id = B.a_id;

   B. LEFT JOIN (Left Outer):
      ┌───────────┐
      │█████┌─────┼─────┐ B   │  Use Case: "List ALL customers, including those with 0 orders."
      │█████│█████│     │     │  Returns: ALL left rows + matching right rows (or NULLs).
      └─────┴─────┴─────┘
      Syntax: FROM TableA A LEFT JOIN TableB B ON A.id = B.a_id;

   C. RIGHT JOIN (Right Outer):
      ┌───────────┐
      │   A ┌─────┼█████┐ B   │  Use Case: "List ALL products, including unpurchased inventory."
      │     │█████│█████│     │  Returns: ALL right rows + matching left rows (or NULLs).
      └─────┴─────┴─────┘
      Syntax: FROM TableA A RIGHT JOIN TableB B ON A.id = B.a_id;

   D. FULL OUTER JOIN (Complete Union of Disjoint & Shared Sets):
      ┌───────────┐
      │█████┌─────┼█████┐     │  Use Case: "Consolidate all vendors and customers across platforms."
      │█████│█████│█████│     │  Note: MySQL does not natively support FULL OUTER JOIN.
      └─────┴─────┴─────┘           Emulated via: LEFT JOIN ... UNION ... RIGHT JOIN
      
   E. CROSS JOIN (Cartesian Product):
      All possible row pairs: Rows(A) × Rows(B).
      Use Case: "Generate a matrix of all Store Locations × All 12 Calendar Months."
      Syntax: FROM TableA CROSS JOIN TableB;

   F. SELF JOIN (Unary Relational Link):
      Joining a table to itself using distinct aliases.
      Use Case: "Organizational hierarchies (Employee -> Manager) or consecutive transactions."
      Syntax: FROM employees emp JOIN employees mgr ON emp.manager_id = mgr.employee_id;

--------------------------------------------------------------------------------
3. CRITICAL INTERVIEW TRAP: FILTERING IN 'ON' VS 'WHERE' IN A LEFT JOIN
--------------------------------------------------------------------------------
- Condition placed in ON:
  Evaluated DURING join construction. If false, the left row is STILL preserved with NULLs.
- Condition placed in WHERE:
  Evaluated AFTER join construction. If right column is filtered (e.g. WHERE B.status = 'Active'),
  all non-matching rows (which became NULL) are DROPPED, inadvertently turning the LEFT JOIN into an INNER JOIN!
================================================================================
*/

-- -----------------------------------------------------------------------------
-- METHOD 1: LEFT JOIN with IS NULL (Standard Anti-Join)
-- -----------------------------------------------------------------------------
/*
Execution Mechanics:
1. Performs full LEFT JOIN matching customers with orders.
2. Filter keeps only rows where the right-side Primary Key evaluated to NULL.
- Pros: Highly optimized by relational query planners (Hash Anti-Join).
*/
SELECT 
    c.customer_id,
    c.customer_name,
    c.email,
    c.city
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;


-- -----------------------------------------------------------------------------
-- METHOD 2: NOT IN (Subquery) & THE DANGEROUS NULL PITFALL!
-- -----------------------------------------------------------------------------
/*
⚠️ CRITICAL INTERVIEW GOTCHA:
If the subquery returns even a SINGLE NULL value (e.g. SELECT customer_id FROM orders WHERE ...),
SQL evaluates: value NOT IN (1, 2, NULL) -> (value != 1) AND (value != 2) AND (value != NULL).
Because (value != NULL) is UNKNOWN (Three-Valued Logic), the whole predicate returns UNKNOWN!
RESULT: The query returns ZERO rows silently! Always filter `WHERE col IS NOT NULL` inside NOT IN.
*/
SELECT 
    customer_id,
    customer_name,
    email,
    city
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id 
    FROM orders 
    WHERE customer_id IS NOT NULL -- Mandatory defensive predicate!
);


-- -----------------------------------------------------------------------------
-- METHOD 3: NOT EXISTS (Correlated Subquery)
-- -----------------------------------------------------------------------------
/*
Execution Mechanics:
1. Evaluates outer row against the inner subquery.
2. Short-circuits immediately upon finding the first match (returns TRUE/FALSE boolean).
- Pros: 100% immune to NULL values inside the subquery; often fastest on indexed columns.
*/
SELECT 
    c.customer_id,
    c.customer_name,
    c.email,
    c.city
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 
    FROM orders o 
    WHERE o.customer_id = c.customer_id
);

/*
================================================================================
COMPARISON SUMMARY MATRIX:
┌──────────────┬──────────────────┬─────────────────┬──────────────────────────┐
│ Method       │ Readability      │ NULL Safe?      │ Execution Mechanism      │
├──────────────┼──────────────────┼─────────────────┼──────────────────────────┤
│ LEFT JOIN    │ Moderate         │ Yes             │ Hash / Merge Anti-Join   │
│ NOT IN       │ High (Intuitive) │ ❌ NO (Trap!)   │ Table scan / In-List     │
│ NOT EXISTS   │ High (Modular)   │ ✅ YES          │ Correlated Short-Circuit │
└──────────────┴──────────────────┴─────────────────┴──────────────────────────┘
================================================================================
*/


-- =============================================================================
-- PART 3: COMMON TABLE EXPRESSIONS (CTEs) & SUBQUERY ARCHITECTURE
-- =============================================================================
-- temp table - common ta le exprssion 


-- -----------------------------------------------------------------------------
-- 1. UNION vs UNION ALL Demonstration
-- UNION: Appends row sets and performs expensive DISTINCT de-duplication sort.
-- UNION ALL: Raw append of row sets (Preserves duplicates, significantly faster).
-- -----------------------------------------------------------------------------
SELECT city, country FROM customers WHERE country = 'USA'
UNION ALL -- Fast append
SELECT office_location AS city, 'USA' AS country FROM departments;
-- -----------------------------------------------------------------------------
-- 2. Scalar, Derived Table & Correlated Subqueries
-- -----------------------------------------------------------------------------
-- A. Scalar Subquery in SELECT (Returns single value 1x1)
SELECT 
    product_name,
    unit_price,
    ROUND((SELECT AVG(unit_price) FROM products), 2) AS catalog_avg_price,
    ROUND(unit_price - (SELECT AVG(unit_price) FROM products), 2) AS diff_from_avg
FROM products;
-- B. Derived Table in FROM (Inline View requiring alias)
SELECT 
    summary.order_status,
    COUNT(*) AS total_orders,
    ROUND(AVG(summary.order_net_val), 2) AS avg_status_order_val
FROM (
    SELECT 
        o.order_id,
        o.order_status,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS order_net_val
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.order_status
) AS summary
GROUP BY summary.order_status;
-- -----------------------------------------------------------------------------
-- 3. Common Table Expressions (WITH Syntax)
-- Eliminates nested subquery clutter ("Spaghetti SQL") through linear readability.
-- -----------------------------------------------------------------------------
WITH RegionalCustomerRevenue AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.city,
        c.country,
        c.segment,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.customer_name, c.city, c.country, c.segment
),
SegmentAverages AS (
    SELECT 
        segment,
        AVG(total_spent) AS segment_avg_spend
    FROM RegionalCustomerRevenue
    GROUP BY segment
)

SELECT 
    rcr.customer_name,
    rcr.segment,
    ROUND(rcr.total_spent, 2) AS customer_total_spent,
    ROUND(sa.segment_avg_spend, 2) AS segment_benchmark,
    ROUND(rcr.total_spent - sa.segment_avg_spend, 2) AS spend_variance_vs_segment
FROM RegionalCustomerRevenue rcr
JOIN SegmentAverages sa ON rcr.segment = sa.segment
ORDER BY spend_variance_vs_segment DESC;

-- -----------------------------------------------------------------------------
-- 4. Recursive CTE: Organizational Tree & Management Level Depth
-- -----------------------------------------------------------------------------
WITH RECURSIVE OrgHierarchy AS (
    -- Anchor Member: Top-level executive (manager_id IS NULL)
    SELECT 
        employee_id,
        CONCAT(first_name, ' ', last_name) AS employee_name,
        manager_id,
        1 AS hierarchy_level,
        CAST(first_name AS CHAR(200)) AS reporting_path
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive Member: Join employees to their parent manager
    SELECT 
        e.employee_id,
        CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
        e.manager_id,
        oh.hierarchy_level + 1 AS hierarchy_level,
        CONCAT(oh.reporting_path, ' -> ', e.first_name) AS reporting_path
    FROM employees e
    INNER JOIN OrgHierarchy oh ON e.manager_id = oh.employee_id
)
SELECT 
    hierarchy_level,
    employee_name,
    reporting_path
FROM OrgHierarchy
ORDER BY hierarchy_level ASC, employee_name ASC;


-- =============================================================================
-- PART 4: 8 MULTI-TABLE JOIN & CTE STUDENT PRACTICE PROBLEMS
-- =============================================================================

-- --- EXERCISE 1 (3-Table Inner Join with Aggregation) ---
-- Task: Generate a category sales report for 'Completed' orders.
--       Display category_name, total units sold, and net revenue generated.
--       Sort by net revenue in descending order.
-- YOUR QUERY HERE:
SELECT 
    cat.category_name,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue
FROM categories cat
INNER JOIN products p ON cat.category_id = p.category_id
INNER JOIN order_items oi ON p.product_id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY cat.category_id, cat.category_name
ORDER BY net_revenue DESC;


-- --- EXERCISE 2 (LEFT JOIN: Sales Rep Performance with Zeros) ---
-- Task: Display ALL sales representatives (employees in department_id = 2) along with:
--       - Total completed orders closed (0 if none)
--       - Total net revenue booked ($0.00 if none)
--       Hint: Use COALESCE to replace NULL with 0.
-- YOUR QUERY HERE:
SELECT 
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS sales_rep_name,
    COUNT(DISTINCT o.order_id) AS orders_closed,
    COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2), 0.00) AS total_booked_revenue
FROM employees e
LEFT JOIN orders o ON e.employee_id = o.sales_rep_id AND o.order_status = 'Completed'
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE e.department_id = 2
GROUP BY e.employee_id, sales_rep_name
ORDER BY total_booked_revenue DESC;


-- --- EXERCISE 3 (SELF JOIN: Hierarchy Pay Gap) ---
-- Task: Find all employees who earn MORE than their direct manager.
--       Return employee name, employee salary, manager name, manager salary,
--       and the positive salary difference.
-- YOUR QUERY HERE:
SELECT 
    CONCAT(emp.first_name, ' ', emp.last_name) AS employee_name,
    emp.salary AS employee_salary,
    CONCAT(mgr.first_name, ' ', mgr.last_name) AS manager_name,
    mgr.salary AS manager_salary,
    (emp.salary - mgr.salary) AS salary_surplus
FROM employees emp
INNER JOIN employees mgr ON emp.manager_id = mgr.employee_id
WHERE emp.salary > mgr.salary;


-- --- EXERCISE 4 (Emulated FULL OUTER JOIN via UNION) ---
-- Task: Find all customers and all sales reps, matching them by city = office_location.
--       Show unmatched customers and unmatched employees (Full Outer Join logic).
-- YOUR QUERY HERE:
SELECT 
    c.customer_name,
    c.city AS customer_city,
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.office_location AS department_city
FROM customers c
LEFT JOIN departments d ON c.city = d.office_location
LEFT JOIN employees e ON d.department_id = e.department_id

UNION

SELECT 
    c.customer_name,
    c.city AS customer_city,
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.office_location AS department_city
FROM customers c
RIGHT JOIN departments d ON c.city = d.office_location
RIGHT JOIN employees e ON d.department_id = e.department_id;


-- --- EXERCISE 5 (Correlated Subquery: Outlier Pricing per Category) ---
-- Task: Find all products whose unit_price is STRICTLY HIGHER than the average unit_price 
--       of their respective category. Display product_name, category_id, unit_price, 
--       and the category average price.
-- YOUR QUERY HERE:
SELECT 
    p.product_id,
    p.product_name,
    p.category_id,
    p.unit_price,
    ROUND((
        SELECT AVG(p_sub.unit_price)
        FROM products p_sub
        WHERE p_sub.category_id = p.category_id
    ), 2) AS category_avg_price
FROM products p
WHERE p.unit_price > (
    SELECT AVG(p_sub.unit_price)
    FROM products p_sub
    WHERE p_sub.category_id = p.category_id
);


-- --- EXERCISE 6 (Complex Multi-Table Filtering with NOT EXISTS) ---
-- Task: Find all Corporate customers who placed an order in 2024, but have NEVER
--       ordered any product from the 'Furniture' category (category_id = 3).
-- YOUR QUERY HERE:
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment
FROM customers c
WHERE c.segment = 'Corporate'
  AND EXISTS (
      -- Placed at least one order
      SELECT 1 
      FROM orders o 
      WHERE o.customer_id = c.customer_id
  )
  AND NOT EXISTS (
      -- Never ordered category 3 (Furniture)
      SELECT 1 
      FROM orders o
      JOIN order_items oi ON o.order_id = oi.order_id
      JOIN products p ON oi.product_id = p.product_id
      WHERE o.customer_id = c.customer_id
        AND p.category_id = 3
  );


-- --- EXERCISE 7 (Multi-Stage CTE: Customer Order Frequency & Spend) ---
-- Task: Using chained CTEs:
--       1. CTE 1 (CustomerMetrics): Compute total completed orders and net spend per customer.
--       2. CTE 2 (CustomerTiers): Assign a Tier:
--          - 'Platinum' if net spend >= $30,000
--          - 'Gold' if net spend between $10,000 and $29,999.99
--          - 'Silver' if net spend < $10,000
--       3. Final Select: Count total customers and total revenue per Tier.
-- YOUR QUERY HERE:
WITH CustomerMetrics AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(DISTINCT o.order_id) AS completed_orders,
        COALESCE(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 0) AS total_net_spend
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Completed'
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name
),
CustomerTiers AS (
    SELECT 
        customer_id,
        customer_name,
        total_net_spend,
        CASE 
            WHEN total_net_spend >= 30000 THEN 'Platinum'
            WHEN total_net_spend >= 10000 THEN 'Gold'
            ELSE 'Silver'
        END AS customer_tier
    FROM CustomerMetrics
)
SELECT 
    customer_tier,
    COUNT(customer_id) AS total_customers_in_tier,
    ROUND(SUM(total_net_spend), 2) AS cumulative_tier_revenue,
    ROUND(AVG(total_net_spend), 2) AS avg_spend_per_tier_member
FROM CustomerTiers
GROUP BY customer_tier
ORDER BY cumulative_tier_revenue DESC;


-- --- EXERCISE 8 (Recursive CTE: Date Spine Generation for Sales Trend) ---
-- Task: Generate a continuous date sequence from '2024-01-01' to '2024-01-07' (Date Spine).
--       LEFT JOIN the orders table against this date sequence to display the daily order 
--       count and daily revenue, ensuring days with 0 orders appear as 0 rather than being skipped!
-- YOUR QUERY HERE:
WITH RECURSIVE DateSpine AS (
    -- Anchor: Start date
    SELECT CAST('2024-01-15' AS DATE) AS calendar_date
    UNION ALL
    -- Recursive: Increment by 1 day until limit
    SELECT DATE_ADD(calendar_date, INTERVAL 1 DAY)
    FROM DateSpine
    WHERE calendar_date < '2024-01-22'
)
SELECT 
    ds.calendar_date,
    COUNT(o.order_id) AS daily_order_count,
    COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2), 0.00) AS daily_revenue
FROM DateSpine ds
LEFT JOIN orders o ON ds.calendar_date = o.order_date
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY ds.calendar_date
ORDER BY ds.calendar_date ASC;

-- =============================================================================
-- END OF DAY 2 SQL ADVANCED JOINS, SUBQUERIES & CTES SCRIPT
-- =============================================================================