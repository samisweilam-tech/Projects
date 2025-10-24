-- Product report
/*
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
*/
CREATE VIEW view_product_report AS 


WITH basic_query AS (
SELECT p.product_id,
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost,
	s.sales_amount,
	s.quantity,
	s.order_date,
	s.customer_key,
	s.order_number
FROM gold.fact_sales s LEFT JOIN gold.dim_products p
	ON s.product_key = p.product_key
WHERE s.order_date IS NOT NULL
),

-- Aggrgation table

 aggregation_table AS(

SELECT product_key,
    product_name,
    category,
    subcategory,
    cost,
	SUM(sales_amount) as total_sales,
	SUM(quantity) as quantity,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) as life_span,
	MAX(order_date) as last_order,
	COUNT(DISTINCT(order_number)) as total_orders,
	COUNT(DISTINCT(customer_key)) as total_customers,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
FROM basic_query
GROUP BY  product_key,
    product_name,
    category,
    subcategory,
    cost
)

-- Final table
SELECT product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_order,
	DATEDIFF(MONTH, last_order, GETDATE()) AS recency_in_months,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	life_span,
	total_orders,
	total_sales,
	quantity,
	total_customers,
	avg_selling_price,
-- Average Order Revenue
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,

-- Average Month Revenue
	CASE
		WHEN life_span = 0 THEN total_sales
		ELSE total_sales / life_span
	END AS avg_monthly_revenue
FROM aggregation_table