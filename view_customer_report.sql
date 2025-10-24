CREATE VIEW view_customer_report AS 

WITH base_quiery AS (
SELECT 
s.order_number,
s.product_key,
s.order_date,
s.sales_amount,
s.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) as customer_name,
DATEDIFF(YEAR, c.birthdate, GETDATE()) as age
FROM gold.fact_sales s LEFT JOIN gold.dim_customers c
	ON s.customer_key = c.customer_key
WHERE order_date IS NOT NULL
), customer_aggregations AS (
SELECT customer_key,
	customer_name,
	age,
	COUNT(DISTINCT order_number) as total_orders,
	SUM(sales_amount) as total_sales,
	COUNT(DISTINCT product_key) AS total_products,
	SUM(quantity) as total_quantity,
	MAX(order_date) as last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) as life_span
FROM base_quiery
GROUP BY customer_key,
	customer_name,
	age)
SELECT customer_key,
	customer_name,
	age,
	CASE
		WHEN age <= 20 then 'Under 20'
		WHEN age BETWEEN 21 AND 35 then '21-35'
		WHEN age BETWEEN 35 AND 49 then '35-49'
		WHEN age BETWEEN 50 AND 69 then '50-69'
		WHEN age BETWEEN 70 AND 89 then '70-89'
		ELSE 'Above 90'
	END as Age_Range,
	CASE
		WHEN life_span >= 12 AND total_sales > 5000 THEN 'VIP Custpmer'
		WHEN life_span >= 12 AND total_sales <= 5000 THEN 'Regular Customer'
		ELSE 'New customer'
	END AS customer_segment,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) as last_active,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	life_span,
-- Average order value (AOV)
	CASE 
		WHEN total_sales = 0 THEN 0
		ELSE total_sales / total_orders
	END AS average_order_value,
-- Average monthly spend
	CASE 
		WHEN life_span = 0 THEN total_sales
		ELSE total_sales / life_span
	END AS average_monthly_spend
FROM customer_aggregations;