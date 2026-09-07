-- =============================================================================
-- ENTERPRISE ANALYTICS DATABASE SCHEMA & SEED DATA
-- Database Name: enterprise_retail_db
-- =============================================================================

DROP DATABASE IF EXISTS enterprise_retail_db;
CREATE DATABASE enterprise_retail_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE enterprise_retail_db;

-- -----------------------------------------------------------------------------
-- 1. TABLE: departments
-- -----------------------------------------------------------------------------
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    office_location VARCHAR(100) NOT NULL
);

-- -----------------------------------------------------------------------------
-- 2. TABLE: employees (Self-Referencing Manager-Employee Hierarchy)
-- -----------------------------------------------------------------------------
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    hire_date DATE NOT NULL,
    department_id INT,
    manager_id INT,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- -----------------------------------------------------------------------------
-- 3. TABLE: customers
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    city VARCHAR(50) NOT NULL,
    country VARCHAR(50) NOT NULL,
    segment VARCHAR(30) NOT NULL, -- 'Consumer', 'Corporate', 'Home Office'
    join_date DATE NOT NULL
);

-- -----------------------------------------------------------------------------
-- 4. TABLE: categories
-- -----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- 5. TABLE: products
-- -----------------------------------------------------------------------------
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 6. TABLE: orders
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE,
    ship_mode VARCHAR(30) NOT NULL, -- 'Standard', 'Express', 'Same Day'
    order_status VARCHAR(30) NOT NULL, -- 'Completed', 'Shipped', 'Refunded', 'Cancelled'
    sales_rep_id INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (sales_rep_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- -----------------------------------------------------------------------------
-- 7. TABLE: order_items (Line Items with Quantity & Pricing)
-- -----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_pct DECIMAL(4, 2) DEFAULT 0.00, -- e.g. 0.15 = 15%
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- =============================================================================
-- DATA INGESTION & SEED RECORDS
-- =============================================================================

-- Departments
INSERT INTO departments (department_id, department_name, office_location) VALUES
(1, 'Executive Leadership', 'New York'),
(2, 'Sales & Commercial', 'Chicago'),
(3, 'Data & Technology', 'San Francisco'),
(4, 'Supply Chain & Operations', 'Austin'),
(5, 'Customer Support', 'Miami');

-- Employees (Hierarchical Structure)
INSERT INTO employees (employee_id, first_name, last_name, email, salary, hire_date, department_id, manager_id) VALUES
(1, 'Eleanor', 'Vance', 'eleanor.vance@company.com', 185000.00, '2020-01-15', 1, NULL),     -- Chief Executive
(2, 'Marcus', 'Brody', 'marcus.brody@company.com', 125000.00, '2020-03-01', 2, 1),        -- VP Sales
(3, 'Sophia', 'Chen', 'sophia.chen@company.com', 135000.00, '2020-06-15', 3, 1),          -- Head of Data
(4, 'David', 'Miller', 'david.miller@company.com', 92000.00, '2021-02-10', 2, 2),         -- Senior Sales Rep
(5, 'Jessica', 'Alba', 'jessica.alba@company.com', 98000.00, '2021-04-12', 2, 2),         -- Senior Sales Rep
(6, 'Carlos', 'Santana', 'carlos.santana@company.com', 130000.00, '2021-08-01', 2, 2),     -- Star Rep (Higher salary than manager Marcus!)
(7, 'Rachel', 'Zane', 'rachel.zane@company.com', 85000.00, '2022-01-10', 3, 3),           -- Data Analyst
(8, 'Harvey', 'Specter', 'harvey.specter@company.com', 140000.00, '2022-05-18', 3, 3),    -- Senior Architect
(9, 'Donna', 'Paulsen', 'donna.paulsen@company.com', 75000.00, '2022-09-01', 5, 1),       -- Operations Lead
(10, 'Mike', 'Ross', 'mike.ross@company.com', 68000.00, '2023-03-15', 5, 9);             -- Support Specialist

-- Categories
INSERT INTO categories (category_id, category_name) VALUES
(1, 'Technology'),
(2, 'Office Supplies'),
(3, 'Furniture'),
(4, 'Cloud Subscriptions');

-- Products
INSERT INTO products (product_id, product_name, category_id, unit_price, cost_price, stock_quantity) VALUES
(1, 'Enterprise Laptop Pro 16', 1, 2400.00, 1650.00, 85),
(2, 'Ultra-Wide Monitor 34-inch', 1, 750.00, 480.00, 120),
(3, 'Wireless Noise-Cancelling Headset', 1, 250.00, 130.00, 300),
(4, 'Ergonomic Mesh Office Chair', 3, 450.00, 260.00, 60),
(5, 'Motorized Standing Desk 60x30', 3, 680.00, 390.00, 45),
(6, 'Executive Oak Bookshelf', 3, 320.00, 180.00, 30),
(7, 'Heavy-Duty Paper Shredder', 2, 120.00, 65.00, 150),
(8, 'Premium Gel Ink Pens (Box of 50)', 2, 45.00, 18.00, 500),
(9, 'Multi-Purpose Laser Paper (10 Reams)', 2, 60.00, 32.00, 400),
(10, 'Cloud Storage Enterprise License (Annual)', 4, 1200.00, 400.00, 999),
(11, 'SaaS Analytics Platform Seat (Annual)', 4, 1800.00, 600.00, 999);

-- Customers
INSERT INTO customers (customer_id, customer_name, email, city, country, segment, join_date) VALUES
(1, 'Acme Global Corp', 'purchasing@acmeglobal.com', 'New York', 'USA', 'Corporate', '2023-01-10'),
(2, 'TechNova Solutions', 'it@technovasolutions.com', 'San Francisco', 'USA', 'Corporate', '2023-02-14'),
(3, 'Apex Financial Group', 'procurement@apexfin.com', 'Chicago', 'USA', 'Corporate', '2023-03-20'),
(4, 'Beacon Design Studio', 'sarah@beacondesign.com', 'Austin', 'USA', 'Home Office', '2023-05-12'),
(5, 'Johnathan Doe', 'john.doe@gmail.com', 'Miami', 'USA', 'Consumer', '2023-06-01'),
(6, 'Elena Rostova', 'elena.rostova@outlook.com', 'Seattle', 'USA', 'Consumer', '2023-07-22'),
(7, 'Quantum Logistics Ltd', 'supply@quantumlog.com', 'London', 'UK', 'Corporate', '2023-08-15'),
(8, 'BrightPath Consulting', 'admin@brightpath.com', 'Toronto', 'Canada', 'Home Office', '2023-09-05'),
(9, 'Lucas Vance', 'lucas.vance@yahoo.com', 'Boston', 'USA', 'Consumer', '2023-11-18'),
(10, 'Zenith Media Partners', 'ops@zenithmedia.com', 'Los Angeles', 'USA', 'Corporate', '2024-01-08');

-- Orders
INSERT INTO orders (order_id, customer_id, order_date, ship_date, ship_mode, order_status, sales_rep_id) VALUES
(101, 1, '2024-01-15', '2024-01-18', 'Express', 'Completed', 4),
(102, 2, '2024-01-20', '2024-01-25', 'Standard', 'Completed', 6),
(103, 3, '2024-02-02', '2024-02-04', 'Same Day', 'Completed', 5),
(104, 4, '2024-02-10', '2024-02-14', 'Standard', 'Completed', 4),
(105, 5, '2024-02-15', '2024-02-20', 'Standard', 'Refunded', NULL),
(106, 1, '2024-03-01', '2024-03-03', 'Express', 'Completed', 6),
(107, 7, '2024-03-12', '2024-03-18', 'Standard', 'Completed', 4),
(108, 8, '2024-03-25', '2024-03-28', 'Express', 'Completed', 5),
(109, 2, '2024-04-05', '2024-04-09', 'Standard', 'Completed', 6),
(110, 10, '2024-04-18', '2024-04-20', 'Express', 'Completed', 6),
(111, 6, '2024-05-02', '2024-05-06', 'Standard', 'Completed', NULL),
(112, 3, '2024-05-15', '2024-05-17', 'Same Day', 'Completed', 5),
(113, 9, '2024-05-20', NULL, 'Standard', 'Cancelled', NULL),
(114, 1, '2024-06-01', '2024-06-04', 'Express', 'Completed', 6),
(115, 4, '2024-06-12', '2024-06-16', 'Standard', 'Completed', 4);

-- Order Items (Line Items)
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_pct) VALUES
-- Order 101 (Acme Global)
(1, 101, 1, 5, 2400.00, 0.10),   -- 5 Laptops ($10,800 net)
(2, 101, 2, 5, 750.00, 0.05),    -- 5 Monitors ($3,562.50 net)
(3, 101, 10, 5, 1200.00, 0.00),  -- 5 Cloud Licenses ($6,000 net)

-- Order 102 (TechNova)
(4, 102, 11, 10, 1800.00, 0.15), -- 10 SaaS Seats ($15,300 net)
(5, 102, 3, 10, 250.00, 0.00),   -- 10 Headsets ($2,500 net)

-- Order 103 (Apex Financial)
(6, 103, 1, 8, 2400.00, 0.12),   -- 8 Laptops ($16,896 net)
(7, 103, 5, 8, 680.00, 0.08),    -- 8 Standing Desks ($4,996.80 net)

-- Order 104 (Beacon Design)
(8, 104, 4, 2, 450.00, 0.00),    -- 2 Chairs ($900 net)
(9, 104, 8, 4, 45.00, 0.00),     -- 4 Boxes of Pens ($180 net)

-- Order 105 (Johnathan Doe - Refunded)
(10, 105, 3, 1, 250.00, 0.00),   -- 1 Headset ($250)

-- Order 106 (Acme Global)
(11, 106, 11, 15, 1800.00, 0.20),-- 15 SaaS Seats ($21,600 net)

-- Order 107 (Quantum Logistics)
(12, 107, 7, 3, 120.00, 0.00),   -- 3 Shredders ($360 net)
(13, 107, 9, 20, 60.00, 0.10),   -- 20 Paper Reams ($1,080 net)

-- Order 108 (BrightPath Consulting)
(14, 108, 2, 2, 750.00, 0.00),   -- 2 Monitors ($1,500 net)
(15, 108, 4, 2, 450.00, 0.05),   -- 2 Chairs ($855 net)

-- Order 109 (TechNova)
(16, 109, 1, 12, 2400.00, 0.15), -- 12 Laptops ($24,480 net)
(17, 109, 2, 12, 750.00, 0.10),  -- 12 Monitors ($8,100 net)

-- Order 110 (Zenith Media)
(18, 110, 10, 20, 1200.00, 0.25),-- 20 Cloud Licenses ($18,000 net)

-- Order 111 (Elena Rostova)
(19, 111, 3, 1, 250.00, 0.00),   -- 1 Headset ($250 net)
(20, 111, 8, 2, 45.00, 0.00),    -- 2 Pens ($90 net)

-- Order 112 (Apex Financial)
(21, 112, 11, 10, 1800.00, 0.10),-- 10 SaaS Seats ($16,200 net)

-- Order 113 (Lucas Vance - Cancelled)
(22, 113, 1, 1, 2400.00, 0.00),

-- Order 114 (Acme Global)
(23, 114, 5, 10, 680.00, 0.10),  -- 10 Desks ($6,120 net)
(24, 114, 4, 10, 450.00, 0.10),  -- 10 Chairs ($4,050 net)

-- Order 115 (Beacon Design)
(25, 115, 2, 1, 750.00, 0.00);   -- 1 Monitor ($750 net)

-- =============================================================================
-- VERIFICATION TEST QUERY
-- =============================================================================
SELECT 
    t.table_name AS 'Table Name', 
    t.table_rows AS 'Estimated Row Count'
FROM information_schema.tables t
WHERE t.table_schema = 'enterprise_retail_db';