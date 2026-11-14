-- Лабораторная работа 5
-- Магазин одежды
-- MySQL 8.0
-- Внимание: при повторном запуске база clothing_store создается заново!

-- Часть 1. Создание базы и таблиц
DROP DATABASE IF EXISTS clothing_store;
CREATE DATABASE clothing_store;
USE clothing_store;

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    size VARCHAR(10),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    CHECK (price >= 0),
    CHECK (stock_quantity >= 0)
);

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    status VARCHAR(30) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE (order_id, product_id),
    CHECK (quantity > 0),
    CHECK (unit_price >= 0)
);

-- Добавляем адрес покупателя
ALTER TABLE customers ADD address VARCHAR(200);

-- Добавляем данные
INSERT INTO categories 
VALUES
(1, 'Футболки'), (2, 'Джинсы'), (3, 'Куртки');

INSERT INTO customers 
VALUES
(1, 'Анна Иванова', '89001112233', 'anna@mail.ru', 'Москва'),
(2, 'Мария Петрова', '89004445566', 'maria@mail.ru', 'Казань'),
(3, 'Иван Сидоров', '89007778899', 'ivan@mail.ru', 'Тула');

INSERT INTO products 
VALUES
(1, 'Белая футболка', 1, 'M', 1700, 20),
(2, 'Синие джинсы', 2, 'L', 3500, 15),
(3, 'Чёрная куртка', 3, 'M', 7000, 8),
(4, 'Чёрная футболка', 1, 'S', 1800, 12);

INSERT INTO orders 
VALUES
(1, 1, '2026-10-01', 'completed'),
(2, 2, '2026-10-03', 'completed'),
(3, 3, '2026-10-05', 'new');

INSERT INTO order_items 
VALUES
(1, 1, 1, 2, 1500),
(2, 1, 2, 1, 3500),
(3, 2, 3, 1, 7000),
(4, 3, 4, 2, 1800);

-- Меняем цену
UPDATE products SET price = 1750 WHERE product_id = 1;

-- Добавляем и удаляем тестовую категорию
INSERT INTO categories VALUES (99, 'Тестовая');
DELETE FROM categories WHERE category_id = 99;

-- Создаем пользователя с правом просмотра
-- Для этого нужны права администратора MySQL
CREATE USER IF NOT EXISTS 'clothing_reader'@'localhost' IDENTIFIED BY 'ChangeMe_2026!';
GRANT SELECT ON clothing_store.* TO 'clothing_reader'@'localhost';

-- Смотрим поля таблиц
DESCRIBE categories;
DESCRIBE customers;
DESCRIBE products;
DESCRIBE orders;
DESCRIBE order_items;

-- Часть 2. Запросы

-- 1. Товары с ценой от 1750, сортировка по цене
SELECT product_name, price
FROM products
WHERE price >= 1750
ORDER BY price DESC;

-- 2. Заказы с именами покупателей и товарами
SELECT orders.order_id, customers.full_name, products.product_name, order_items.quantity
FROM orders
JOIN customers ON orders.customer_id = customers.customer_id
JOIN order_items ON orders.order_id = order_items.order_id
JOIN products ON order_items.product_id = products.product_id;

-- 3. Количество товаров, остатки, средняя, самая большая и маленькая цена
SELECT COUNT(*) AS kolichestvo,
       SUM(stock_quantity) AS ostatok,
       AVG(price) AS srednyaya_cena,
       MAX(price) AS max_cena,
       MIN(price) AS min_cena
FROM products;

-- 4. Продажи товаров по завершенным заказам
SELECT products.product_name,
       SUM(order_items.quantity) AS prodano,
       SUM(order_items.quantity * order_items.unit_price) AS vyruchka
FROM products
JOIN order_items ON products.product_id = order_items.product_id
JOIN orders ON order_items.order_id = orders.order_id
WHERE orders.status = 'completed'
GROUP BY products.product_id, products.product_name
HAVING SUM(order_items.quantity) >= 1;

-- 5. Покупатели, у которых есть завершенные заказы (IN)
SELECT full_name FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM orders WHERE status = 'completed'
);

-- 6. Товары, цена которых не меньше цен всех футболок (ALL)
SELECT product_name, price FROM products
WHERE price >= ALL (
    SELECT price FROM products WHERE category_id = 1
);

-- 7. Проверка количества на складе и цены
SELECT product_name, stock_quantity,
    CASE
        WHEN stock_quantity < 10 THEN 'Мало'
        WHEN stock_quantity < 20 THEN 'Средне'
        ELSE 'Достаточно'
    END AS ostatki,
    IF(price >= 3000, 'Дорогой', 'Недорогой') AS cena
FROM products;

-- 8. Представление для отчета о продажах
CREATE VIEW sales_report AS
SELECT products.product_name,
       SUM(order_items.quantity) AS prodano,
       SUM(order_items.quantity * order_items.unit_price) AS vyruchka
FROM products
JOIN order_items ON products.product_id = order_items.product_id
JOIN orders ON order_items.order_id = orders.order_id
WHERE orders.status = 'completed'
GROUP BY products.product_id, products.product_name;
SELECT * FROM sales_report;

-- 9. Смотрим план запроса до и после индекса
EXPLAIN SELECT * FROM orders WHERE order_date = '2026-10-01';
CREATE INDEX idx_date ON orders(order_date);
EXPLAIN SELECT * FROM orders WHERE order_date = '2026-10-01';

-- 10. Транзакция: пробуем оформить заказ и уменьшить остаток
START TRANSACTION;
UPDATE orders SET status = 'completed' WHERE order_id = 3;
UPDATE products SET stock_quantity = stock_quantity - 2
WHERE product_id = 4 AND stock_quantity >= 2;
SELECT * FROM orders WHERE order_id = 3;
SELECT * FROM products WHERE product_id = 4;
ROLLBACK;
-- ROLLBACK отменяет изменения. Для сохранения используют COMMIT.

-- 11. Подготовленный запрос с параметром цены
SET @cena = 1800;
PREPARE zapros FROM 'SELECT product_name, price FROM products WHERE price >= ?';
EXECUTE zapros USING @cena;
DEALLOCATE PREPARE zapros;
