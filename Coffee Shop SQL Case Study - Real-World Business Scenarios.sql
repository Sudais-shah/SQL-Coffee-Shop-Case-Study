/* 
                Coffee Shop SQL Case Study Project - Real-World Business Scenarios
=============================================================================
Context:
You're a Data Professional working for a coffee shop chain. Your job is to optimize operations, 
analyze trends, and ensure data accuracy using SQL.

   SQL Concept to Cover:
-	Joins & Exploration
-	Date/Time & Interval Arithmetic
-	Aggregation, GROUP BY & HAVING
-	Common Table Expressions (CTEs) & Subqueries
-	Window Functions & Ranking
-	Recursive CTEs
-	Conditional Logic, Pivoting & Un pivoting
-	View Creation & Safe Joins
-	Optimization Techniques  

Below are the tables present in the Database **/
SELECT * FROM coffeeshop;
SELECT * FROM ingredients;
SELECT * FROM inventary;
SELECT * FROM menu_items;
SELECT * FROM orders;
SELECT * FROM recipe;
SELECT * FROM rota;
SELECT * FROM shift;
SELECT * FROM staff;

--=====================================================================================
--              /**********    1. Employee Workload & Shift Management    **********/
--=====================================================================================
-- Q1:   Calculate total hours worked by each employee per week.
SELECT sf.staff_id , sf.first_name , sf.last_name , DATE_TRUNC('week', cs.date::DATE) AS week_start, 
       SUM(s.end_time - s.start_time) AS total_worked_hours
FROM staff sf
JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
JOIN shift s ON cs.shift_id = s.shift_id 
GROUP BY 1,2,3,4
ORDER BY sf.staff_id 

ALTER TABLE coffeeshop ALTER COLUMN date TYPE DATE USING date::DATE;

-- Q2:   Identify employees working overtime (more than 25 hours).
SELECT staff_id , first_name , last_name , week_start , total_worked_hours
FROM (
	SELECT sf.staff_id , sf.first_name , sf.last_name , DATE_TRUNC('week', cs.date::DATE) AS week_start, 
	       SUM(s.end_time - s.start_time) AS total_worked_hours
FROM staff sf
JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
JOIN shift s ON cs.shift_id = s.shift_id 
GROUP BY 1,2,3,4
ORDER BY sf.staff_id ) subquery
WHERE total_worked_hours > INTERVAL '25 HOURS'

-- Q3:  Rank employees based on total hours worked .  
WITH emp_worked_hours AS (
	SELECT sf.staff_id , sf.first_name , sf.last_name , DATE_TRUNC('week', cs.date::DATE) AS week_start, 
	       SUM(s.end_time - s.start_time) AS total_worked_hours
	FROM staff sf
	JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
	JOIN shift s ON cs.shift_id = s.shift_id 
	GROUP BY 1,2,3,4
	ORDER BY sf.staff_id 
)
SELECT staff_id , first_name , last_name , total_worked_hours ,
       -- RANK() OVER (ORDER BY total_worked_hours DESC) AS rank_top_working_employees
	   DENSE_RANK() OVER (ORDER BY total_worked_hours DESC) AS rank_top_working_employees
from emp_worked_hours	   

-- Q4: Suggest an optimized shift allocation to balance the workload.
WITH EmployeeHours AS (
	SELECT sf.staff_id , sf.first_name , sf.last_name , 
	       SUM(EXTRACT(EPOCH FROM (s.end_time - s.start_time)) / 3600 ) AS total_worked_hours
	FROM staff sf
	JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
	JOIN shift s ON cs.shift_id = s.shift_id 
	GROUP BY 1,2,3
	ORDER BY sf.staff_id 
),
OverWorked AS(
	SELECT staff_id , first_name , last_name , total_worked_hours
	FROM EmployeeHours
	WHERE total_worked_hours > 25
),
UnderWorked AS(
	SELECT staff_id , first_name , last_name , total_worked_hours
	FROM EmployeeHours
	WHERE total_worked_hours < 25
)
SELECT o.staff_id AS overworked_id , o.first_name AS overworked_firstname , 
       u.staff_id AS underworked_id , u.first_name AS underworked_firstname ,
	   'Consider Shift reallocation' AS suggestion 
FROM OverWorked o
CROSS JOIN UnderWorked u

--=====================================================================================
--            /********    2. Preventing Shift Overlaps & Scheduling Optimization     ********/
--=====================================================================================
-- Q5: Detect employees with overlapping shifts (same date, overlapping times) 
WITH Overlappingshifts AS(
	SELECT cs.shift_id , cs.date, s.start_time , s.end_time , 
	       STRING_AGG(st.first_name || ' ' || st.last_name, ' | ') AS employees,
		   COUNT(*) AS employees_count
	FROM coffeeshop cs 	   
	JOIN shift s ON cs.shift_id = s.shift_id 
	JOIN staff st ON cs.staff_id = st.staff_id
	GROUP BY cs.shift_id , cs.date, s.start_time, s.end_time
	HAVING COUNT(*) > 1
)
SELECT shift_id, date, start_time, end_time, employees, employees_count
FROM Overlappingshifts
ORDER BY date, shift_id

-- Q6: Identify shifts with insufficient staff.
--     Condition : If one or less than one employee are assighned to a shift is a shift with insufficeint staff
SELECT cs.shift_id , cs.date, s.start_time , s.end_time , 
	       STRING_AGG(st.first_name || ' ' || st.last_name, ' | ') AS employees,
		   COUNT(*) AS employees_count
	FROM coffeeshop cs 	   
	JOIN shift s ON cs.shift_id = s.shift_id 
	JOIN staff st ON cs.staff_id = st.staff_id
	GROUP BY cs.shift_id , cs.date, s.start_time, s.end_time
	HAVING COUNT(*) <= 1

--=====================================================================================
--               /********       3. Sales & Revenue Analysis        ********/
--=====================================================================================
--Q7:  Identify busiest hours based on total sales.
SELECT EXTRACT(HOUR FROM o.created_at::TIMESTAMP) AS busiest_hours , 
       SUM(o.quantity * mi.item_price) AS total_sales
FROM orders o	   
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY busiest_hours
ORDER BY total_sales DESC

--Q8:  Create a view summarizing total revenue per month, orders, and average order value.
CREATE VIEW monthly_kpis AS 
SELECT EXTRACT(MONTH FROM CAST(o.created_at AS TIMESTAMP)) AS month, SUM(o.quantity * mi.item_price) AS revenue_per_month,
       SUM(o.quantity) AS orders_per_month, 
	   ROUND(SUM(o.quantity * mi.item_price) / COUNT(DISTINCT o.order_id),2) AS avg_order_value
FROM orders o 
JOIN menu_items mi ON o.item_id = mi.item_id 
GROUP BY month 
ORDER BY month ASC

--Q9: Determine the most profitable category Like Hot Drinks, Cold Drinks, Pastries, etc.
SELECT mi.item_cat AS profitable_category, 
       SUM(CASE WHEN o.in_or_out = 'out' THEN o.quantity ELSE 0 END) AS quantity_sold_out,
	   SUM(CASE WHEN o.in_or_out = 'in' THEN o.quantity ELSE 0 END) AS quantity_sold_in,
	   SUM(o.quantity) AS total_quantity_sold,
	   SUM(o.quantity * mi.item_price) AS revenue_per_category
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_cat
ORDER BY total_quantity_sold DESC
LIMIT 1

-- ====================================================================================
--         /********       4. Customer Order Patterns & Retention   ********\
--=====================================================================================
--Q10: Find customers who order at least 14 times per week.
SELECT  cust_name, EXTRACT(MONTH FROM created_at::TIMESTAMP) AS month , 
		EXTRACT(WEEK FROM created_at::TIMESTAMP) AS week_of_year, 
		FLOOR((EXTRACT(DAY FROM created_at::TIMESTAMP) - 1) / 7 ) + 1 AS week_of_month,
		COUNT(*) AS total_orders
FROM orders
-- WHERE EXTRACT(MONTH FROM created_at::TIMESTAMP) = 2
GROUP BY cust_name,  month, week_of_year, week_of_month
HAVING COUNT(*) >= 14 
ORDER BY total_orders ASC

--Q11: Identify customers who haven't placed an order in the last 30 days.
SELECT DISTINCT cust_name 
FROM orders
WHERE cust_name NOT IN (
	SELECT DISTINCT cust_name 
	FROM orders
	WHERE created_at::TIMESTAMP > CURRENT_DATE - INTERVAL '30 days'
	)

-- Lets say we are writing this query on 2024/03/15
SELECT DISTINCT cust_name 
FROM orders
WHERE cust_name NOT IN (
	SELECT DISTINCT cust_name 
	FROM orders
	WHERE created_at::TIMESTAMP > DATE '2024/03/15' - INTERVAL '30 days'
	)
-------------------------- WITH LEFT JOIN 
SELECT DISTINCT o1.cust_name 
FROM orders o1
LEFT JOIN (
	SELECT DISTINCT cust_name 
	FROM orders
	WHERE created_at::TIMESTAMP > DATE '2024/03/15' - INTERVAL '30 days'
	) o2
ON o1.cust_name = o2.cust_name
WHERE o2.cust_name IS NULL

--Q12: Determine preferred order times like morning, afternoon and evening.
-- Pivot Version:
SELECT order_period, order_count
FROM(
SELECT CASE WHEN EXTRACT(HOURS FROM created_at::TIMESTAMP) BETWEEN 5 AND 10 THEN 'Morning'
            WHEN EXTRACT(HOURS FROM created_at::TIMESTAMP) BETWEEN 12 AND 15 THEN 'Afternoon'
            WHEN EXTRACT(HOURS FROM created_at::TIMESTAMP) BETWEEN 17 AND 19 THEN 'Evening'
			ELSE 'Other' END AS order_period, COUNT(*) AS order_count
			FROM orders
			GROUP BY order_period

UNION ALL 

SELECT 'Total' AS order_period, COUNT(*) AS order_count
FROM orders) AS combined_result

ORDER BY order_period = 'Morning' DESC, order_period = 'Afternoon' DESC, order_period = 'Evening' DESC,
         order_period = 'Other' DESC, order_period = 'Total' DESC

		 
-- Pivot Version:
SELECT  COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  5 AND  10 THEN 1 END ) AS morning,             
		COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  12 AND 15 THEN 1 END ) AS afternoon,             
		COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  17 AND  19  THEN 1 END ) AS evening,
		COUNT(CASE 
				WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) NOT BETWEEN 5 AND 10 
				AND EXTRACT(HOUR FROM created_at::TIMESTAMP) NOT BETWEEN 12 AND 15 
				AND EXTRACT(HOUR FROM created_at::TIMESTAMP) NOT BETWEEN 17 AND 19 
		THEN 1 
		END) AS other,
		COUNT(EXTRACT(HOUR FROM created_at::TIMESTAMP)) AS total
FROM orders

/**  OUTPUT OF UNPIVOTED VERSION:

"Afternoon" | 228
"Evening"	|  6
"Morning"	|  242
"Other"	    |  45
"Total"     |  521

OUTPUT OF PIVOTED VERSION:

"morning" | "afternoon" | "evening" | other |  "total"
   242	   |    228  	  |   6	     |  45   |   521     **/

--=====================================================================================
--            /********        5. Pricing & Product Demand Analysis   ********\
--=====================================================================================
--Q13: Identify top 5 best-selling items and their revenue contribution.
SELECT mi.item_name, o.item_id, SUM(o.quantity) AS quantity_sold, 
	   SUM(o.quantity * mi.item_price) AS revenue_contribution
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY 1,2 --or mi.item_name, o.item_id
ORDER BY quantity_sold DESC 
LIMIT 5;

SELECT * FROM menu_items;
SELECT * FROM orders;


--Q14: Find least-selling items and suggest potential removal or discounts.
SELECT mi.item_name, o.item_id, SUM(o.quantity) AS quantity_sold, 
	   SUM(o.quantity * mi.item_price) AS revenue_contribution, 
	   CASE WHEN SUM(quantity) < 5 THEN 'Removal'
		   WHEN SUM(quantity) <=10 AND SUM(o.quantity * mi.item_price) > 40 THEN 'Discount'
		   WHEN SUM(quantity) BETWEEN 10 AND 15 THEN 'Discount'
		   WHEN SUM(quantity) > 15 THEN 'Keep' END AS status_recommendation,
		CASE WHEN SUM(quantity) < 5 THEN 'Very Low Sales'
		   WHEN SUM(quantity) <=10 AND SUM(o.quantity * mi.item_price) > 40 THEN 'High Price Items'
		   WHEN SUM(quantity) BETWEEN 10 AND 15 THEN 'Medium Sales'
		   WHEN SUM(quantity) > 15 THEN 'High Sales' END AS reason
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY 1,2 --or mi.item_name, o.item_id
ORDER BY quantity_sold, revenue_contribution ASC;

-- Q15: Identify best-selling items so far and recommend focus areas for marketing campaigns.
SELECT mi.item_name, mi.item_cat, SUM(o.quantity) AS total_quantity_sold, 
		CASE WHEN SUM(o.quantity) >= 30 THEN 'Top Seller - Focus Marketing'
			 WHEN SUM(o.quantity) BETWEEN 20 AND 29 THEN 'Moderate Seller - Some Marketing'
			 ELSE 'Low Seller - Little or No Marketing' END AS marketing_recommendation
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_name, mi.item_cat
ORDER BY total_quantity_sold DESC;

--=====================================================================================
--                /********   6.Forecasting Ingredient Stock  ********\
--=====================================================================================
-- Q16: List all ingredients that are running low in inventory (quantity less than 5)
WITH ing_quantity AS(
		SELECT ing.ing_id, ing.ing_name, ing.ing_weight, ing_meas AS measurment, SUM(inv.quantity) AS quantity_left
		FROM ingredients ing
		JOIN inventary inv ON ing.ing_id = inv.ing_id
		GROUP BY ing.ing_id, ing.ing_name, ing.ing_weight, measurment)
SELECT * FROM ing_quantity 
WHERE quantity_left < 5
ORDER BY quantity_left ASC;

-- Q17: Estimate the number of shifts a staff member has worked since the beginning of the year.
WITH ordered_shifts AS (
	SELECT staff_id, date, ROW_NUMBER() OVER (PARTITION BY staff_id ORDER BY date) AS rn
	FROM rota
	WHERE date >= '2024-01-01')
SELECT staff_id, MAX(rn) AS total_shift_worked
FROM ordered_shifts
GROUP BY staff_id
ORDER BY total_shift_worked ASC;


-- Solution 2
SELECT staff_id, COUNT(*) AS total_shift_worked
FROM rota
GROUP BY staff_id
ORDER BY total_shift_worked ASC;

-- Q18: Identify Frequently Ordered Menu Item Chains like Coffee -> Muffin -> Cookies.
SELECT mi1.item_name || '->' || mi2.item_name AS item_chain, COUNT(*) AS frequency, 2 AS chain_length
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN menu_items mi1 ON o1.item_id = mi1.item_id
JOIN menu_items mi2 ON o2.item_id = mi2.item_id
GROUP BY item_chain

UNION ALL 

SELECT mi1.item_name || '->' || mi2.item_name || '->' || mi3.item_name AS item_chain, COUNT(*) AS frequency, 3 AS chain_length
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN orders o3 ON o1.order_id = o3.order_id AND o2.item_id < o3.item_id
JOIN menu_items mi1 ON o1.item_id = mi1.item_id
JOIN menu_items mi2 ON o2.item_id = mi2.item_id
JOIN menu_items mi3 ON o3.item_id = mi3.item_id
GROUP BY item_chain
ORDER BY chain_length DESC, frequency DESC

--=====================================================================================
--    /********  7.  Customer Segmentation & Loyalty Analysis    ********\
--=====================================================================================
-- Q19: Find customers with 10+ orders spread over 5 or more days for loyalty rewards.
SELECT cust_name, COUNT(*) AS total_orders, COUNT(DISTINCT created_at::DATE) AS distinct_order_days
FROM orders
GROUP BY cust_name
HAVING COUNT(*) >= 10 AND COUNT(DISTINCT CAST(created_at AS DATE)) >= 5

-- Q20: Which menu items are most popular by time of day (morning, afternoon, evening)?
SELECT t.time_of_day, COALESCE(t.item_id, 'No Item'), COALESCE(mi.item_name, 'NO Data'), t.order_count
FROM 
	(SELECT o.item_id, CASE WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 5 AND 11 THEN 'Morning'
						WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 12 AND 16 THEN 'Afternoon'
						WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 17 AND 20 THEN 'Evening' END AS time_of_day,
	COUNT(*) AS order_count,
	ROW_NUMBER() OVER(PARTITION BY CASE WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 5 AND 11 THEN 'Morning'
						WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 12 AND 16 THEN 'Afternoon'
						WHEN EXTRACT(HOUR FROM o.created_at::TIMESTAMP) BETWEEN 17 AND 20 THEN 'Evening' END 
						ORDER BY COUNT(*) DESC) AS rank
	FROM orders o 
	GROUP BY o.item_id, time_of_day) t
LEFT JOIN menu_items mi ON t.item_id = mi.item_id	
WHERE t.rank = 1

---Cte Version:
WITH orders_by_time AS (
    SELECT item_id,
        CASE 
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 5 AND 11 THEN 'Morning'
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 12 AND 16 THEN 'Afternoon'
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 17 AND 20 THEN 'Evening' END AS time_of_day
    FROM orders),
ranked_items AS (
    SELECT  item_id, time_of_day, COUNT(*) AS order_count,
            ROW_NUMBER() OVER (PARTITION BY time_of_day ORDER BY COUNT(*) DESC) AS rank
    FROM orders_by_time
    WHERE time_of_day IS NOT NULL
    GROUP BY item_id, time_of_day)
	
SELECT time_of_day, COALESCE(CAST(ri.item_id AS TEXT), 'No Item') AS item_id, COALESCE(mi.item_name, 'No Data') AS item_name,
       COALESCE(ri.order_count, 0) AS order_count
FROM ranked_items ri
LEFT JOIN menu_items mi ON ri.item_id = mi.item_id
WHERE ri.rank = 1
ORDER BY time_of_day ASC;

--=====================================================================================
--                   /********   8. Employee Performance & Sales Contribution  ********\
--=====================================================================================
-- Q21: Find employees working during the highest-revenue shifts.
WITH shift_revenue AS (
	SELECT r.shift_id, r.date AS shift_date, SUM(o.quantity * mi.item_price) AS total_shift_revenue
	FROM orders o
	JOIN menu_items mi ON o.item_id = mi.item_id
	JOIN rota r ON o.created_at::date = r.date
	JOIN shift s ON r.shift_id = s.shift_id
	WHERE o.created_at::time BETWEEN s.start_time AND s.end_time
	GROUP BY r.shift_id, r.date),
max_revenue AS(
	SELECT MAX(total_shift_revenue) AS max_rev
	FROM shift_revenue
)	
SELECT sr.shift_id, r.staff_id, sr.shift_date, sr.total_shift_revenue
FROM shift_revenue sr
JOIN rota r ON sr.shift_id = r.shift_id AND sr.shift_date = r.date
JOIN max_revenue mr ON sr.total_shift_revenue = mr.max_rev

-- Q22: Rank employees based on their total revenue generated across all shifts.
WITH employee_revenue AS (
    SELECT r.staff_id, COUNT(DISTINCT o.order_id) AS total_orders, SUM(o.quantity) AS total_quantity, 
	SUM(o.quantity * mi.item_price) AS total_revenue, AVG(mi.item_price) AS avg_item_price                 
    FROM orders o
    JOIN menu_items mi ON o.item_id = mi.item_id
    JOIN rota r       ON o.created_at::date = r.date
    JOIN shift s      ON r.shift_id = s.shift_id
    WHERE o.created_at::time BETWEEN s.start_time AND s.end_time
    GROUP BY r.staff_id
)
SELECT staff_id, total_orders, total_quantity, total_revenue, avg_item_price,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM employee_revenue
ORDER BY revenue_rank;