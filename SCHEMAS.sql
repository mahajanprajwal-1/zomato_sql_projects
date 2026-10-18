--- Zomato Data Analysis using SQL
DROP TABLE IF EXISTS customers;

CREATE TABLE customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(25),
reg_date DATE
);
DROP TABLE IF EXISTS deliveries;
CREATE TABLE deliveries (
    delivery_id      INT PRIMARY KEY,
    order_id         INT,
    delivery_status  VARCHAR(35),
    delivery_time    TIME WITHOUT TIME ZONE,
    rider_id         INT,
	CONSTRAINT fk_orders FOREIGN KEY (order_id) REFERENCES orders(order_id),
	CONSTRAINT fk_riders FOREIGN KEY (rider_id) REFERENCES riders(rider_id)
);


CREATE TABLE restaurants (
    restaurant_id    INT PRIMARY KEY,
    restaurant_name  VARCHAR(55),
    city             VARCHAR(15),
    opening_hours    VARCHAR(55)
);

CREATE TABLE riders (
    rider_id    INT PRIMARY KEY,
    rider_name  VARCHAR(55),
    sign_up     DATE
);

CREATE TABLE orders (
    order_id       INT PRIMARY KEY,
    customer_id    INT ,
    restaurant_id  INT ,
    order_item     VARCHAR(55),
    order_date     DATE,
    order_time     TIME WITHOUT TIME ZONE,
    order_status   VARCHAR(55),
    total_amount   DOUBLE PRECISION
);

-- adding Foreign Key 
ALTER TABLE orders
ADD CONSTRAINT fk_customers
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);


ALTER TABLE orders
ADD CONSTRAINT fk_restaurants
FOREIGN KEY (restaurant_id)
REFERENCES  restaurants(restaurant_id);


--- END of Schemas

