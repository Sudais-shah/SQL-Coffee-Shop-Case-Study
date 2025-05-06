CREATE TABLE Ingredients (
    ing_id VARCHAR(10) PRIMARY KEY,
    ing_name VARCHAR(100) NOT NULL,
    ing_weight INTEGER NOT NULL,
    ing_meas VARCHAR(16),
    ing_price DECIMAL(10,2)
);

CREATE TABLE Inventary (
    inv_id VARCHAR(10) PRIMARY KEY,
    ing_id VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity >= 0)
);

CREATE TABLE menu_items (
    item_id VARCHAR(10) PRIMARY KEY,
    sku VARCHAR(20) NOT NULL,
    item_name VARCHAR(50) NOT NULL,
    item_cat VARCHAR(30) NOT NULL,
    item_size VARCHAR(10) NOT NULL,
    item_price DECIMAL(5,2) NOT NULL CHECK(item_price >= 0)
);

CREATE TABLE orders (
    row_id SERIAL PRIMARY KEY,
    order_id TEXT,
    created_at TEXT,
    item_id VARCHAR(10),
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    cust_name VARCHAR(50),
    in_or_out TEXT
);

CREATE TABLE recipe (
    row_id SERIAL PRIMARY KEY,
    recipe_id VARCHAR(20) NOT NULL,
    ing_id VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0)
);

CREATE TABLE rota (
    row_id SERIAL PRIMARY KEY,
    rota_id VARCHAR(10),
    date DATE,
    shift_id VARCHAR(10),
    staff_id VARCHAR(10)
);

CREATE TABLE shift (
    shift_id VARCHAR(10) PRIMARY KEY,
    day_of_week VARCHAR(10),
    start_time TIME,
    end_time TIME
);

CREATE TABLE staff (
    staff_id VARCHAR(10) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    position VARCHAR(50),
    sal_per_hour DECIMAL(10,2)
);

CREATE TABLE coffeeshop (
    row_id SERIAL PRIMARY KEY,
    rota_id VARCHAR(10),
    shift_id VARCHAR(10),
    staff_id VARCHAR(10),
    date DATE
);

SELECT * FROM coffeeshop;
SELECT * FROM ingredients;
SELECT * FROM inventary;
SELECT * FROM menu_items;
SELECT * FROM orders;
SELECT * FROM recipe;
SELECT * FROM rota;
SELECT * FROM shift;
SELECT * FROM staff;