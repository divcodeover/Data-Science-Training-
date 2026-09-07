-- =============================================================================
-- STUDENT GRADED PORTFOLIO LAB: 20 ADVANCED SQL INTERVIEW PROBLEMS
-- DATABASE: enterprise_retail_db
-- INSTRUCTIONS: Write optimal SQL queries for each task. Push to GitHub as .sql
-- =============================================================================

USE enterprise_retail_db;

-- -----------------------------------------------------------------------------
-- PART A: JOINS, ADVANCED FILTERING & SUBQUERIES (Q1 - Q5)
-- -----------------------------------------------------------------------------

-- [Q1] Find all customers from 'USA' who placed completed orders in Q1 2024 (Jan–Mar).
--      Return customer_name, order_id, order_date, and order net revenue.
-- YOUR QUERY HERE:
SELECT 
    c.customer_name, 
    o.order_id, 
    o.order_date, 
    o.net_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.country = 'USA'
  AND o.order_status = 'Completed'
  AND o.order_date >= '2024-01-01' 
  AND o.order_date < '2024-04-01';


-- [Q2] Identify all sales reps (department_id = 2) who have NEVER closed an order.
--      Use an Anti-Join pattern (LEFT JOIN + IS NULL or NOT EXISTS).
-- YOUR QUERY HERE:
SELECT 
    e.employee_id, 
    e.employee_name
FROM employees e
LEFT JOIN orders o ON e.employee_id = o.sales_rep_id
WHERE e.department_id = 2 
  AND o.order_id IS NULL;


-- [Q3] List all products that have never been ordered in the entire history of the company.
-- YOUR QUERY HERE:
SELECT 
    p.product_id, 
    p.product_name
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;


-- [Q4] Find all employees whose salary is strictly higher than the average salary of their department.
--      Display employee name, department name, salary, and the department average salary.
-- YOUR QUERY HERE:
WITH DeptAvg AS (
    SELECT 
        department_id, 
        AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department_id
)
SELECT 
    e.employee_name, 
    d.department_name, 
    e.salary, 
    da.avg_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN DeptAvg da ON e.department_id = da.department_id
WHERE e.salary > da.avg_salary;


-- [Q5] Find all customer segments where the total net revenue exceeds $30,000 across completed orders.
--      Display segment, total orders count, and net revenue sorted descending.
-- YOUR QUERY HERE:
SELECT 
    c.segment, 
    COUNT(o.order_id) AS total_orders_count, 
    SUM(o.net_revenue) AS total_net_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.segment
HAVING SUM(o.net_revenue) > 30000
ORDER BY total_net_revenue DESC;



-- -----------------------------------------------------------------------------
-- PART B: COMMON TABLE EXPRESSIONS (CTEs) & COMPLEX LOGIC (Q6 - Q8)
-- -----------------------------------------------------------------------------

-- [Q6] Using a CTE, calculate the Total Spend per customer. In the main query,
--      classify customers into 'High Spender' (>= $20k), 'Mid Spender' ($5k-$20k),
--      and 'Low Spender' (< $5k). Count the number of customers in each bracket.
-- YOUR QUERY HERE:
WITH CustomerSpend AS (
    SELECT 
        c.customer_id, 
        COALESCE(SUM(o.net_revenue), 0) AS total_spend
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Completed'
    GROUP BY c.customer_id
),
Categorized AS (
    SELECT 
        customer_id,
        CASE 
            WHEN total_spend >= 20000 THEN 'High Spender'
            WHEN total_spend >= 5000 THEN 'Mid Spender'
            ELSE 'Low Spender'
        END AS spending_bracket
    FROM CustomerSpend
)
SELECT 
    spending_bracket, 
    COUNT(customer_id) AS customer_count
FROM Categorized
GROUP BY spending_bracket;


-- [Q7] Find customers who placed more than one completed order. Return customer_id,
--      customer_name, first order date, and most recent order date.
-- YOUR QUERY HERE:

SELECT 
    c.customer_id, 
    c.customer_name, 
    MIN(o.order_date) AS first_order_date, 
    MAX(o.order_date) AS most_recent_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(o.order_id) > 1;

-- [Q8] Using a RECURSIVE CTE, generate a date series from '2024-01-01' to '2024-01-10'
--      and count how many orders were placed on each calendar day (including 0-order days).
-- YOUR QUERY HERE:
WITH RECURSIVE DateSeries AS (
    SELECT CAST('2024-01-01' AS DATE) AS calendar_date
    UNION ALL
    SELECT DATE_ADD(calendar_date, INTERVAL 1 DAY)
    FROM DateSeries
    WHERE calendar_date < '2024-01-10'
)
SELECT 
    ds.calendar_date, 
    COUNT(o.order_id) AS order_count
FROM DateSeries ds
LEFT JOIN orders o ON ds.calendar_date = o.order_date
GROUP BY ds.calendar_date
ORDER BY ds.calendar_date;




-- -----------------------------------------------------------------------------
-- PART C: RANKING WINDOW FUNCTIONS (Q9 - Q12)
-- -----------------------------------------------------------------------------

-- [Q9] Find the highest paid employee in EACH department without using GROUP BY or subquery filters.
--      Use DENSE_RANK() or ROW_NUMBER() in a CTE.
-- YOUR QUERY HERE:
WITH RankedEmployees AS (
    SELECT 
        e.*, 
        DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk
    FROM employees e
)
SELECT 
    employee_id, 
    employee_name, 
    department_id, 
    salary
FROM RankedEmployees
WHERE rnk = 1;


-- [Q10] (Deduplication Simulation) If duplicate orders existed, how would you pick only
--       the earliest order per customer? Write a query using ROW_NUMBER() partitioned
--       by customer_id ordered by order_date ASC.
-- YOUR QUERY HERE:
WITH RankedOrders AS (
    SELECT 
        *, 
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC, order_id ASC) AS rn
    FROM orders
)
SELECT 
    order_id, 
    customer_id, 
    order_date, 
    net_revenue, 
    order_status
FROM RankedOrders
WHERE rn = 1;


-- [Q11] Divide all products into 4 equal price quartiles using NTILE(4) based on unit_price.
--       Display product_name, unit_price, and price_quartile (1 = lowest, 4 = highest).
-- YOUR QUERY HERE:
SELECT 
    product_name, 
    unit_price, 
    NTILE(4) OVER (ORDER BY unit_price ASC) AS price_quartile
FROM products;


-- [Q12] Rank all products by unit_price within their category using both RANK() and DENSE_RANK()
--       to demonstrate how ties are treated.
-- YOUR QUERY HERE:
SELECT 
    p.product_name, 
    p.category_id, 
    p.unit_price, 
    RANK() OVER (PARTITION BY p.category_id ORDER BY p.unit_price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.unit_price DESC) AS price_dense_rank
FROM products p;



-- -----------------------------------------------------------------------------
-- PART D: OFFSET FUNCTIONS: LAG & LEAD (Q13 - Q15)
-- -----------------------------------------------------------------------------

-- [Q13] (Month-over-Month Growth) Calculate the total net revenue for each calendar month,
--       and use LAG() to compute the previous month's revenue and the MoM Dollar Growth.
-- YOUR QUERY HERE:
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS ym, 
        SUM(net_revenue) AS monthly_revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT 
    ym, 
    monthly_revenue, 
    LAG(monthly_revenue) OVER (ORDER BY ym) AS prev_month_revenue,
    monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY ym) AS mom_dollar_growth
FROM MonthlyRevenue;


-- [Q14] (Customer Inactivity Interval) For each customer, list all their orders in chronological
--       order and use LAG() to calculate the days elapsed since their previous order.
-- YOUR QUERY HERE:
SELECT 
    customer_id, 
    order_id, 
    order_date, 
    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS prev_order_date,
    DATEDIFF(order_date, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date ASC)) AS days_elapsed
FROM orders;


-- [Q15] For each order, display the current order's date, customer_id, and use LEAD()
--       to show the date of that customer's next upcoming order.
-- YOUR QUERY HERE:
SELECT 
    order_id, 
    customer_id, 
    order_date AS current_order_date, 
    LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS next_order_date
FROM orders;



-- -----------------------------------------------------------------------------
-- PART E: AGGREGATE WINDOW FUNCTIONS & FRAMES (Q16 - Q20)
-- -----------------------------------------------------------------------------

-- [Q16] (Running Total) Calculate a running cumulative total of net revenue ordered chronologically
--       by order_date across all completed orders.
-- YOUR QUERY HERE:
SELECT 
    order_id, 
    order_date, 
    net_revenue, 
    SUM(net_revenue) OVER (ORDER BY order_date ASC, order_id ASC) AS running_total_revenue
FROM orders
WHERE order_status = 'Completed';



-- [Q17] (3-Day Moving Average) For each order date, calculate the daily revenue and a 3-day
--       moving average (current day and 2 preceding days) using ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- YOUR QUERY HERE:

WITH DailyRevenue AS (
    SELECT 
        order_date, 
        SUM(net_revenue) AS daily_revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY order_date
)
SELECT 
    order_date, 
    daily_revenue, 
    AVG(daily_revenue) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3day
FROM DailyRevenue;

-- [Q18] (Percentage of Total) For each product sold in completed orders, display product_name,
--       category_name, product revenue, and calculate what percentage that product contributes
--       to its parent category's total revenue.
-- YOUR QUERY HERE:
WITH ProductRevenue AS (
    SELECT 
        p.product_id, 
        p.product_name, 
        p.category_id, 
        c.category_name, 
        SUM(oi.quantity * oi.unit_price) AS product_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, p.category_id, c.category_name
)
SELECT 
    product_name, 
    category_name, 
    product_revenue, 
    (product_revenue / SUM(product_revenue) OVER (PARTITION BY category_id)) * 100 AS category_pct_contribution
FROM ProductRevenue;


-- [Q19] Calculate the difference between each employee's salary and the highest salary
--       in their department using MAX() OVER (PARTITION BY ...).
-- YOUR QUERY HERE:
SELECT 
    employee_id, 
    employee_name, 
    department_id, 
    salary, 
    MAX(salary) OVER (PARTITION BY department_id) - salary AS salary_diff_from_max
FROM employees;


-- [Q20] (Executive Retention Challenge) Identify customers who placed orders in two consecutive
--       months in 2024. Return distinct customer_id and customer_name.
-- YOUR QUERY HERE:
WITH CustomerMonths AS (
    SELECT DISTINCT 
        o.customer_id, 
        c.customer_name, 
        EXTRACT(MONTH FROM o.order_date) AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_date >= '2024-01-01' 
      AND o.order_date <= '2024-12-31'
),
MonthDiffs AS (
    SELECT 
        customer_id, 
        customer_name, 
        order_month, 
        LAG(order_month) OVER (PARTITION BY customer_id ORDER BY order_month ASC) AS prev_month
    FROM CustomerMonths
)
SELECT DISTINCT 
    customer_id, 
    customer_name
FROM MonthDiffs
WHERE order_month = prev_month + 1;