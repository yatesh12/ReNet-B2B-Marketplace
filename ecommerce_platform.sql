
-- Multi-Vendor E-commerce Platform SQL Schema and Queries

-- 1. Database creation
CREATE DATABASE IF NOT EXISTS ecommerce_platform;
USE ecommerce_platform;

-- 2. Core Tables

-- Vendors
CREATE TABLE vendors (
    vendor_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- Subcategories
CREATE TABLE subcategories (
    subcategory_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    UNIQUE (category_id, name)
);

-- Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    subcategory_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (subcategory_id) REFERENCES subcategories(subcategory_id)
);

-- Vendor Inventory (product availability per vendor)
CREATE TABLE vendor_inventory (
    vendor_id INT NOT NULL,
    product_id INT NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    price_override DECIMAL(10,2),
    PRIMARY KEY (vendor_id, product_id),
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Customers
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Addresses
CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    vendor_id INT NOT NULL,
    address_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending','Processing','Shipped','Delivered','Cancelled') DEFAULT 'Pending',
    total_amount DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

-- Order Items
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 3. Indexing Strategies

-- Full-text index on product name and description
CREATE FULLTEXT INDEX idx_prod_name_desc ON products(name, description);

-- Index for quick vendor lookup by product stock
CREATE INDEX idx_vendor_inventory_stock ON vendor_inventory(stock);

-- Composite index on orders to speed up filtering by customer and date
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);

-- 4. Sample Stored Procedures

-- Add new product
DELIMITER $$
CREATE PROCEDURE add_product (
    IN p_subcat_id INT,
    IN p_name VARCHAR(255),
    IN p_desc TEXT,
    IN p_price DECIMAL(10,2)
)
BEGIN
    INSERT INTO products(subcategory_id, name, description, base_price)
    VALUES(p_subcat_id, p_name, p_desc, p_price);
END $$
DELIMITER ;

-- Update stock for a vendor
DELIMITER $$
CREATE PROCEDURE update_stock (
    IN p_vendor_id INT,
    IN p_product_id INT,
    IN p_new_stock INT
)
BEGIN
    INSERT INTO vendor_inventory(vendor_id, product_id, stock)
    VALUES(p_vendor_id, p_product_id, p_new_stock)
    ON DUPLICATE KEY UPDATE stock = p_new_stock;
END $$
DELIMITER ;

-- 5. Sample Queries

-- Find top 10 best-selling products
SELECT p.product_id, p.name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.name
ORDER BY total_sold DESC
LIMIT 10;

-- Search products by keyword
SELECT product_id, name, base_price
FROM products
WHERE MATCH(name, description) AGAINST('laptop' IN NATURAL LANGUAGE MODE);

-- Get nearest vendor stocking a given product (assuming customer location passed)
SELECT vi.vendor_id, v.name, vi.stock,
       (6371 * ACOS(
           COS(RADIANS(:cust_lat)) * COS(RADIANS(a.latitude)) *
           COS(RADIANS(a.longitude) - RADIANS(:cust_lon)) +
           SIN(RADIANS(:cust_lat)) * SIN(RADIANS(a.latitude))
       )) AS distance_km
FROM vendor_inventory vi
JOIN vendors v ON vi.vendor_id = v.vendor_id
JOIN addresses a ON a.customer_id = v.vendor_id
WHERE vi.product_id = :product_id AND vi.stock > 0
ORDER BY distance_km
LIMIT 1;
