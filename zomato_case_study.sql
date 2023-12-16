create database zomato;
use zomato;

-- Users who have not placed order yet
SELECT user_id, name
FROM zomato_users 
where user_id not in
(select distinct user_id from zomato_orders);


-- Average Order value of different restaurant
SELECT orders.r_id, res.r_name, avg(orders.amount) as AOV
FROM zomato_orders as orders
INNER JOIN zomato_restaurants as res
ON orders.r_id = res.r_id
GROUP BY r_id
ORDER BY avg(amount) desc;

-- Average price per dish
-- Since same dish have different price in different restaurants
SELECT food.f_id, food.f_name, avg(menu.price) as avg_price
FROM zomato_food as food
INNER JOIN 
zomato_menu as menu
ON food.f_id = menu.f_id
GROUP BY food.f_id
ORDER BY avg(menu.price) desc;

-- which category have more food Non-Veg or Veg
SELECT type, count(type)
FROM zomato_food
GROUP BY type;

-- Number of orders in a restaurant in a particular month
SELECT monthname(orders.date) as month, rest.r_name, count(rest.r_name) as n_orders
FROM zomato_orders as orders
INNER JOIN 
zomato_restaurants as rest
ON rest.r_id = orders.r_id
GROUP BY month(orders.date), rest.r_id
ORDER BY month(orders.date) asc, count(rest.r_name) desc;


-- top performing restaurant in each month which has more number of orders
with cte as (
SELECT monthname(orders.date) as month, rest.r_name, count(rest.r_name) as n_orders,
row_number() over(partition by month(orders.date) order by count(rest.r_name) desc) as rankk
FROM zomato_orders as orders
INNER JOIN 
zomato_restaurants as rest
ON rest.r_id = orders.r_id
GROUP BY month(orders.date), rest.r_id)
SELECT month, r_name
FROM cte 
WHERE rankk = 1;

-- monthly revenue of each restaurant
SELECT MONTHNAME(orders.date), rest.r_name, sum(orders.amount)
FROM zomato_orders AS orders
INNER JOIN 
zomato_restaurants as rest
ON orders.r_id = rest.r_id
GROUP BY month(orders.date), orders.r_id
ORDER BY month(orders.date) asc, sum(orders.amount) desc;
  
-- order details of particular customer in a date range
SELECT user_id, order_id, r_id, date, amount
FROM zomato_orders
where user_id = 1 and date between "2022-05-21" and "2022-06-30";

-- How many unique customers does a restaurant have?
SELECT rest.r_name, count(distinct orders.user_id)
FROM zomato_restaurants as rest
INNER JOIN 
zomato_orders as orders
ON rest.r_id = orders.r_id
GROUP BY rest.r_id;


-- what is the usp of a particular restaurant
-- which is generating more revenue for that restaurant

with cte2 as (
with cte1 as (
SELECT rest.r_name, food.f_name, orders.amount
FROM zomato_orders as orders
INNER JOIN
zomato_order_details as details
ON orders.order_id = details.order_id
INNER JOIN
zomato_restaurants as rest
ON orders.r_id = rest.r_id
INNER JOIN 
zomato_food as food
ON food.f_id = details.f_id)
SELECT r_name, f_name, sum(amount) as revenue, rank() over(partition by r_name order by sum(amount) desc) as usp
FROM cte1
GROUP BY r_name, f_name 
ORDER BY r_name)
SELECT r_name, f_name
FROM cte2
WHERE usp = 1;


-- Find restaurant which has maximum repeated customers
with cte1 as(
SELECT r_id, user_id, count(*) AS n_orders
FROM zomato_orders
GROUP BY r_id, user_id
having n_orders > 1),
cte2 as (
SELECT r_id, count(r_id) as n_repeat_orders
FROM cte1 
GROUP BY r_id)
SELECT rest.r_name, cte2.n_repeat_orders
FROM cte2 
INNER JOIN
zomato_restaurants AS rest
ON cte2.r_id = rest.r_id
WHERE cte2.n_repeat_orders = (SELECT MAX(n_repeat_orders) FROM cte2);

-- month over month revenue growth of zomato
with cte as (
SELECT monthname(date) as month, sum(amount) as revenue
FROM zomato_orders
GROUP BY month(date)
ORDER BY month(date))
SELECT month, revenue - lag(revenue) over() as growth
FROM cte;

-- customer's favorite foood
WITH cte1 AS (
SELECT orders.user_id, details.f_id, count(details.f_id) as n_orders
FROM zomato_orders as orders
INNER JOIN 
zomato_order_details as details
ON orders.order_id = details.order_id
GROUP BY orders.user_id, details.f_id),
cte2 as 
(SELECT user_id, f_id, n_orders, row_number() over(partition by user_id order by n_orders desc) AS rank_num
FROM cte1)
SELECT users.name, food.f_name
FROM cte2
INNER JOIN 
zomato_users as users
ON cte2.user_id = users.user_id
INNER JOIN 
zomato_food as food
ON cte2.f_id = food.f_id;

-- Most loyal customer for each restaurants may be to give him gifts

WITH cte as (
SELECT r_id, user_id, count(user_id) as n_orders
FROM zomato_orders
GROUP BY r_id, user_id),
cte2 as (
SELECT r_id, user_id, n_orders, max(n_orders) over(partition by r_id) as max_orders
FROM cte)
SELECT rest.r_name, users.name
FROM cte2
INNER JOIN 
zomato_restaurants as rest
ON cte2.r_id = rest.r_id
INNER JOIN
zomato_users as users 
ON users.user_id = cte2.user_id
WHERE cte2.n_orders = cte2.max_orders
ORDER BY cte2.r_id; 


-- month over month revenue growth of a restaurant
-- lets see for Dominos
with cte as (
SELECT monthname(date) AS month, sum(amount) as revenue
FROM zomato_orders 
where r_id IN
(SELECT r_id FROM zomato_restaurants where r_name = "Dominos")
GROUP BY month(date)
ORDER BY month(date))
SELECT month, revenue - lag(revenue) over() as revenue_growth
FROM cte;


-- Most paired product
-- so the products which are bought together will have 
with cte as (
SELECT orders.order_id, GROUP_CONCAT(food.f_name) as food_items
FROM zomato_orders as orders
INNER JOIN
zomato_order_details as details
ON orders.order_id = details.order_id
INNER JOIN 
zomato_food as food
ON details.f_id = food.f_id
GROUP BY orders.order_id)
SELECT food_items, count(food_items)
FROM cte
GROUP BY food_items
ORDER BY count(food_items) DESC;

-- restaurant's average rating
SELECT rest.r_name, round(avg(orders.restaurant_rating),1) as avg_rating
FROM zomato_orders AS orders
INNER JOIN 
zomato_restaurants AS rest
ON orders.r_id = rest.r_id
WHERE orders.restaurant_rating != ""
GROUP BY rest.r_id;


-- orders delivered and average rating of each delivery partner
SELECT orders.partner_id, partner.partner_name, count(*) as orders_served, 
round(avg(delivery_rating),1) as Avg_rating
FROM zomato_orders AS orders
INNER JOIN
zomato_delivery_partner as partner
ON partner.partner_id = orders.partner_id
GROUP BY orders.partner_id;



-- who delivered most orders in each month
WITH cte as (
SELECT monthname(date) as month, partner_id, count(*) as n_orders
FROM zomato_orders
GROUP BY month(date),partner_id
ORDER BY month(date)),
cte2 as(
SELECT month, partner_id, n_orders, max(n_orders) over(partition by month) as max_orders
FROM cte)
SELECT cte2.month, partner.partner_name
FROM cte2
INNER JOIN 
zomato_delivery_partner as partner
ON cte2.partner_id = partner.partner_id
where n_orders = max_orders;


-- what is the average delivery time of each delivery partner

SELECT partner.partner_name, round(avg(delivery_time),1) as avg_time
FROM zomato_orders as orders
INNER JOIN 
zomato_delivery_partner as partner
ON orders.partner_id = partner.partner_id
GROUP BY orders.partner_id;






