-- Change over time analysis

SELECT DATETRUNC(MONTH,order_date) as order_dates,
	SUM(sales_amount) as total_sales,
	COUNT(customer_key) as total_customers,
	SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
ORDER BY DATETRUNC(MONTH,order_date);

-- The progressive over time (in months)
	-- Add each row to next row.

SELECT order_date_in_month,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date_in_month) as running_total_sales,
	AVG(avg_price) OVER (ORDER BY order_date_in_month) as avg_price
FROM
(
SELECT DATETRUNC(month, order_date) as order_date_in_month,
	SUM(sales_amount) as total_sales,
	AVG(price) as avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
) sub_query ;

-- The progressive over time (in years)
	-- Add each row to next row.

SELECT order_date_in_year,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date_in_year) as running_total_sales,
	AVG(avg_price) OVER (ORDER BY order_date_in_year) as avg_price
FROM
(
	SELECT DATETRUNC(YEAR, order_date) as order_date_in_year,
		SUM(sales_amount) as total_sales,
		AVG(price) as avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(YEAR, order_date)
) sub_query ;

-- Performance analysis
	-- comparing current value with target value (like previos year)

/*
	--analyze yearly performance of the current product's sales to average sales 
	  comparing with average product sales of previos year.
*/

WITH yearly_product_sales AS (
	SELECT YEAR(s.order_date) as order_year,
		p.product_name,
		SUM(s.sales_amount) as current_sales
	FROM gold.fact_sales s LEFT JOIN gold.dim_products p
		ON s.product_key = p.product_key
	WHERE  YEAR(s.order_date) IS NOT NULL
	GROUP BY YEAR(s.order_date),p.product_name
)
SELECT 
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS average_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS Avg_diffrence,
	CASE
		WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above average'
		WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below average'
		ELSE 'Average'
	END Avg_change,
-- comparing with last year
	LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) as previos_year_sales,
	current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) as PYS_diffrence,
	CASE
		WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Progressive'
		WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Increase'
		ELSE 'No Change'
	END PYS_change
FROM yearly_product_sales
ORDER BY product_name;

-- The sales performance for each category By percentage
WITH categories_sales AS (
SELECT p.category,
	SUM(sales_amount) as total_sales
FROM gold.fact_sales s LEFT JOIN gold.dim_products p
	ON s.product_key = p.product_key
GROUP BY p.category
)
SELECT category,
	 total_sales,
	SUM(total_sales) OVER() as overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100, 2), '%') as percentage_of_sales
FROM categories_sales;

-- Data segmention
/*
Group customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history and spending more than €5,000.
	- Regular: Customers with at least 12 months of history but spending €5,000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

WITH customer_spending_with_dates_diff AS (
	SELECT c.customer_key as customer,
		SUM(s.sales_amount) as total_spending,
		MIN(order_date) as first_order,
		MAX(order_date) as last_order,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) as life_span
	FROM gold.fact_sales s LEFT JOIN gold.dim_customers c
	ON s.customer_key = c.customer_key
	GROUP BY c.customer_key
)
SELECT COUNT(customer) as number_of_customer,
	customer_segment
FROM (
	SELECT customer,
		total_spending,
		CASE
			WHEN life_span <= 12 AND total_spending > 5000 THEN 'VIP Customer'
			WHEN life_span <= 12 AND total_spending <= 5000 THEN 'Regular Customer'
			ELSE 'New Customer'
		END AS customer_segment
	FROM customer_spending_with_dates_diff) sub_quiery
GROUP BY customer_segment;