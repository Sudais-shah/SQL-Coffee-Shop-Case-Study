 -- =============================================================================
 --         Coffee Shop SQL Case Study - Real-World Business Scenarios
 -- Context:
--  You're a Data Professional working for a coffee shop chain. Your job is to optimize operations, 
--  analyze trends, and ensure data accuracy using SQL.

SELECT * FROM coffeeshop;
SELECT * FROM ingredients;
SELECT * FROM inventary;
SELECT * FROM menu_items;
SELECT * FROM orders;
SELECT * FROM recipe;
SELECT * FROM rota;
SELECT * FROM shift;
SELECT * FROM staff;

--//**************************************************************************************************************//
--              /**********    1. Employee Workload & Shift Management    **********/

-- Q1:   Calculate total hours worked by each employee per week.
SELECT sf.staff_id , sf.first_name , sf.last_name , DATE_TRUNC('week', cs.date) AS week_start,
      SUM(s.end_time - s.start_time) AS total_worked_hours 
-- HERE WE CAN ALSO USE -> ROUND(SUM(EXTRACT(EPOCH FROM (s.end_time - s.start_time)) / 3600),2) AS total_worked_hours
FROM staff sf
JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
JOIN shift s ON cs.shift_id = s.shift_id 
GROUP BY 1,2,3,4
ORDER BY sf.staff_id;

-- Q2:   Identify employees working overtime (more than 25 hours).
SELECT staff_id , first_name , last_name , week_start , total_worked_hours
FROM (
       SELECT sf.staff_id , sf.first_name , sf.last_name , DATE_TRUNC('week', cs.date) AS week_start,
              SUM(s.end_time - s.start_time) AS total_worked_hours       
       FROM staff sf
       JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
       JOIN shift s ON cs.shift_id = s.shift_id 
       GROUP BY 1,2,3,4
       ORDER BY sf.staff_id ) subquery
WHERE total_worked_hours > INTERVAL '25 HOURS';

-- Q3:  Rank employees based on total hours worked .
WITH emp_worked_hours AS (
SELECT sf.staff_id , sf.first_name , sf.last_name ,
       SUM(s.end_time - s.start_time) AS total_worked_hours
FROM staff sf
JOIN coffeeshop cs ON sf.staff_id = cs.staff_id 
JOIN shift s ON cs.shift_id = s.shift_id 
GROUP BY 1,2,3
ORDER BY sf.staff_id )

SELECT staff_id , first_name , last_name , total_worked_hours ,
       RANK() OVER (ORDER BY total_worked_hours DESC) rank_top_woking_employees
FROM emp_worked_hours;

-- Q4: Suggest an optimized shift allocation to balance the workload.
WITH EmployeeHours AS (
    SELECT  cs.staff_id, sf.first_name, sf.last_name,	
           SUM(EXTRACT(EPOCH FROM (s.end_time - s.start_time)) / 3600) AS total_worked_hours
    FROM coffeeshop cs
    JOIN shift s ON cs.shift_id = s.shift_id
    JOIN staff sf ON cs.staff_id = sf.staff_id
    GROUP BY cs.staff_id, sf.first_name, sf.last_name
),
Overworked AS ( 
    SELECT staff_id, first_name, last_name, total_worked_hours
    FROM EmployeeHours
    WHERE total_worked_hours > 25
),
Underworked AS (
    SELECT staff_id, first_name, last_name, total_worked_hours
    FROM EmployeeHours
    WHERE total_worked_hours < 25
)
SELECT 
    o.staff_id AS overworked_staff_id,
    o.first_name AS overworked_name,
    u.staff_id AS underworked_staff_id,
    u.first_name AS underworked_name,
    'Consider reallocating shifts' AS suggestion
FROM Overworked o
CROSS JOIN Underworked u;

--            /********    2. Preventing Shift Overlaps & Scheduling Optimization     ********/

-- Q5: Detect employees with overlapping shifts (same date, overlapping times).

-- Solution 1 using CTE: 
WITH repeated_shifts AS (
    SELECT shift_id, date
    FROM coffeeshop
    GROUP BY shift_id, date
    HAVING COUNT(*) > 1 
)
SELECT  cs.shift_id, cs.date, cs.staff_id, st.first_name, st.last_name, s.start_time, s.end_time
FROM coffeeshop cs
JOIN shift s ON cs.shift_id = s.shift_id
JOIN staff st ON cs.staff_id = st.staff_id
JOIN repeated_shifts rs ON cs.shift_id = rs.shift_id AND cs.date = rs.date
ORDER BY cs.date, cs.shift_id;

--Solution 2 using SubQuery:
SELECT  cs.shift_id, cs.date, cs.staff_id, st.first_name, st.last_name, s.start_time, s.end_time
FROM coffeeshop cs
JOIN shift s ON cs.shift_id = s.shift_id
JOIN staff st ON cs.staff_id = st.staff_id
WHERE (cs.shift_id, cs.date) IN ( 
  SELECT shift_id, date
  FROM coffeeshop
  GROUP BY shift_id, date
  HAVING COUNT(*) > 1
)
ORDER BY cs.date, cs.shift_id;

-- Q6: Identify shifts with insufficient staff and recommend fixes.
--     Lets assume shift's to which one employee is asighned are shifts with insufficient staff.
WITH shift_assighned AS (
     SELECT shift_id , COUNT(staff_id) AS total_staff_assighned
     FROM coffeeshop
     GROUP BY shift_id 
     HAVING COUNT(staff_id) < 2
	 ORDER BY shift_id ASC
)
SELECT sa.shift_id , s.day_of_week , s.start_time , s.end_time ,  sa.total_staff_assighned
FROM shift_assighned sa
JOIN shift s ON sa.shift_id = s.shift_id
ORDER BY sa.shift_id ASC

--               /********       3. Sales & Revenue Analysis        ********/
--Q7:  Identify busiest hours based on total sales.

SELECT EXTRACT(HOUR FROM o.created_at::TIMESTAMP) AS busiest_hour , SUM(o.quantity * mi.item_price) AS total_sales
FROM orders o 
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY busiest_hour
ORDER BY total_sales DESC 

--Q8:  Create a view summarizing total revenue per month, orders, and average order value.
CREATE VIEW monthly_kpis AS
SELECT EXTRACT(MONTH FROM o.created_at::TIMESTAMP) AS month , SUM(o.quantity * mi.item_price) AS revenue_per_month , 
       SUM(DISTINCT o.quantity) AS orders_per_month , 
	    ROUND(SUM(o.quantity * mi.item_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id 
GROUP BY month 
ORDER BY month ASC

--Q9: Determine the most profitable category (Hot Drinks, Cold Drinks, Pastries, etc.).
SELECT DISTINCT mi.item_cat AS profitable_category, 
      SUM(CASE WHEN o.in_or_out = 'out' THEN o.quantity ELSE 0 END) AS quantity_sold_out,
	  SUM(CASE WHEN o.in_or_out = 'in' THEN o.quantity ELSE 0 END) AS quantity_sold_in,
	  SUM(o.quantity) AS total_quantity_sold
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id 
GROUP BY mi.item_cat
ORDER BY quantity_sold_out DESC

/*** Output:
profitable_category   |      quantity_sold_out  |  quantity_sold_in  |  total_quantity_sold
"Hot Drinks"	               128                          113	             277
"Cold Drinks"                  67                           52                  154
"Snacks"	                    8                            17  	              35
 
--Q10: UNPIVOT this results into these columns 
-> profitable_category  |	sale_type |	quantity_sold  ***/

SELECT  mi.item_cat AS profitable_category, 
        'quantity_sold_out' AS sale_type ,
         SUM(CASE WHEN o.in_or_out = 'out' THEN o.quantity ELSE 0 END) AS quantity_sold
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id 
GROUP BY mi.item_cat

UNION ALL 

SELECT  mi.item_cat , 
        'quantity_sold_in' ,
          SUM(CASE WHEN o.in_or_out = 'in' THEN o.quantity ELSE 0 END) 
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id 
GROUP BY mi.item_cat
        
UNION ALL 

SELECT  mi.item_cat , 
        'total_quantity' ,
         SUM(o.quantity) 
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id 
GROUP BY mi.item_cat

--         /********       4. Customer Order Patterns & Retention   ********\

--Q11: Find customers who order at least 5 times per week.
SELECT cust_name, EXTRACT(MONTH FROM created_at::TIMESTAMP) AS month,
       EXTRACT(WEEK FROM created_at::TIMESTAMP) AS week, 
	   FLOOR((EXTRACT(DAY FROM created_at::TIMESTAMP) - 1) / 7) + 1 AS week_of_month,
       COUNT(*) AS total_orders
FROM orders
GROUP BY cust_name, week , month , week_of_month 
HAVING COUNT(*) >= 5
ORDER BY total_orders ASC;

--Q12: Identify customers who haven't placed an order in the last 30 days.
SELECT DISTINCT created_at, cust_name
FROM orders 
WHERE created_at::TIMESTAMP > CAST(CURRENT_DATE AS TIMESTAMP) - INTERVAL '30 DAYS'
ORDER BY cust_name ASC

--Lets Assume we are writing this query at 2024-03-15

SELECT DISTINCT cust_name , order_id , created_at , item_id , quantity 
FROM orders
WHERE created_at::TIMESTAMP > DATE '2024-03-15' - INTERVAL '30 days' 
ORDER BY cust_name ASC;
 
--Q13: Determine preferred order times like morning, afternoon and evening.
SELECT COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) >= 5 AND EXTRACT(HOUR FROM created_at::TIMESTAMP) < 11
       THEN 1  END ) AS morning,
	   COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) >= 12 AND EXTRACT(HOUR FROM created_at::TIMESTAMP) < 16
       THEN 1  END ) AS afternoon,
	   COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) >= 17 AND EXTRACT(HOUR FROM created_at::TIMESTAMP) < 20
       THEN 1  END ) AS evening,
	   COUNT(EXTRACT(HOUR FROM created_at::TIMESTAMP)) AS total
FROM orders

--USING BETWEEN 
SELECT COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  5 AND  10
       THEN 1  END ) AS morning,
	   COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  12 AND 15
       THEN 1  END ) AS afternoon,
	   COUNT(CASE WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN  17 AND  19
       THEN 1  END ) AS evening,
	   COUNT(EXTRACT(HOUR FROM created_at::TIMESTAMP)) AS total
FROM orders

--            /********        5. Pricing & Product Demand Analysis   ********\

--Q14: Identify top 5 best-selling items and their revenue contribution.
SELECT mi.item_name , o.item_id , SUM(quantity) AS quantity_sold , SUM(o.quantity * mi.item_price) AS revenue_contribution
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY 1,2   -- oR mi.item_name , o.item_id
ORDER BY revenue_contribution DESC
LIMIT 5;

--Q15: Find least-selling items and suggest potential removal or discounts.
SELECT mi.item_name , o.item_id , SUM(quantity) AS quantity_sold , SUM(o.quantity * mi.item_price) AS revenue_contribution,
       CASE WHEN SUM(quantity) < 5  THEN 'Removal'
	        WHEN SUM(quantity) <= 10 AND  SUM(o.quantity * mi.item_price) > 40 THEN 'Discount'
	        WHEN SUM(quantity) BETWEEN 10 AND 15 THEN 'Discount'
			WHEN SUM(quantity) > 15 THEN 'Keep'
			END AS status_recommendation, 
	   CASE WHEN SUM(quantity) < 5  THEN 'Very low sales'
	        WHEN SUM(quantity) <= 10 AND  SUM(o.quantity * mi.item_price) > 40 THEN 'High price items'
	        WHEN SUM(quantity) BETWEEN 10 AND 15 THEN 'Medium sales'
			WHEN SUM(quantity) > 15 THEN 'High sales'
			END AS reason
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY  mi.item_name , o.item_id 
ORDER BY quantity_sold , revenue_contribution ASC;

-- Q16: Identify best-selling items so far and recommend focus areas for marketing campaigns.
SELECT  mi.item_name , mi.item_cat, SUM(o.quantity) AS total_quantity_sold,
    CASE WHEN SUM(o.quantity) >= 30 THEN 'Top Seller - Focus marketing'
         WHEN SUM(o.quantity) BETWEEN 20 AND 29 THEN 'Moderate Seller - Some marketing'
         ELSE 'Low Seller - Little or no marketing'
    END AS marketing_recommendation
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY mi.item_name, mi.item_cat
ORDER BY total_quantity_sold DESC;

--                /********   6.Forecasting Ingredient Stock  ********\
-- Q16: List all ingredients that are running low in inventory (quantity less than 5)
WITH low_ing AS (
SELECT inv.inv_id , ing.ing_id , ing.ing_name , ing_weight , ing_meas AS measurement , 
       SUM(inv.quantity) AS total_quantity
FROM ingredients ing
JOIN inventary inv ON ing.ing_id = inv.ing_id 
GROUP BY 1,2,3
ORDER BY total_quantity ASC )

SELECT * FROM low_ing WHERE total_quantity < 5;

-- Q17: Estimate the number of shifts a staff member has worked since the beginning of the year.
WITH RECURSIVE ordered_shifts AS (
  SELECT staff_id, date,
         ROW_NUMBER() OVER (PARTITION BY staff_id ORDER BY date) AS rn
  FROM rota
  WHERE date >= '2023-01-01' ),
shift_count AS (
    SELECT staff_id, rn, 1 AS shift_count
    FROM ordered_shifts
    WHERE rn = 1
    UNION ALL
    SELECT os.staff_id, os.rn, sc.shift_count + 1
    FROM ordered_shifts os
    JOIN shift_count sc ON os.staff_id = sc.staff_id AND os.rn = sc.rn + 1 )
SELECT  staff_id, MAX(shift_count) AS total_shifts_worked
FROM shift_count
GROUP BY staff_id
ORDER BY total_shifts_worked DESC;

-- Q18: Identify Frequently Ordered Menu Item Chains like Coffee -> Muffin -> Cookie.
WITH RECURSIVE item_chains AS (
    SELECT  o.order_id, o.item_id, mi.item_name, o.created_at, 
	        1 AS chain_length, mi.item_name::TEXT AS chain_path
    FROM orders o
    JOIN menu_items mi ON o.item_id = mi.item_id

    UNION ALL

    SELECT  ic.order_id, o.item_id, mi.item_name, o.created_at, 
	        ic.chain_length + 1, ic.chain_path || ' -> ' || mi.item_name
    FROM item_chains ic
    JOIN orders o ON o.order_id = ic.order_id AND o.created_at > ic.created_at
    JOIN menu_items mi ON o.item_id = mi.item_id
    WHERE ic.chain_length < 3 )

SELECT mi1.item_name || ' -> ' || mi2.item_name AS item_chain, COUNT(*) AS frequency
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN menu_items mi1 ON o1.item_id = mi1.item_id
JOIN menu_items mi2 ON o2.item_id = mi2.item_id
GROUP BY item_chain
ORDER BY frequency DESC
LIMIT 20;

--    /********  7.  Customer Segmentation & Loyalty Analysis    ********\
-- Q19: Identify customers eligible for loyalty rewards based on order frequency.

-- customers who ordered on 5+ different days and with 10+ orders in total.
SELECT cust_name, COUNT(DISTINCT created_at) AS total_orders
FROM orders
GROUP BY cust_name
HAVING COUNT(DISTINCT created_at) >= 5 AND COUNT(DISTINCT created_at) > 10 
--
WITH customer_order_summary AS (
    SELECT cust_name, MIN(created_at::date) AS first_order_date,
           MAX(created_at::date) AS last_order_date,
           COUNT(DISTINCT created_at::date) AS total_order_days
    FROM orders
    GROUP BY cust_name ),
avg_gap AS (
    SELECT cust_name, first_order_date, last_order_date, total_order_days,
        CASE   
            WHEN total_order_days > 1 THEN 
                (last_order_date - first_order_date) * 1.0 / (total_order_days - 1) ELSE NULL
        END AS avg_days_between_orders
    FROM customer_order_summary)
SELECT * FROM avg_gap
WHERE avg_days_between_orders <= 1 AND total_order_days >= 3
ORDER BY avg_days_between_orders;

-- Q20: Which menu items are most popular by time of day (morning, afternoon, evening)?
--Solution 1 
WITH orders_by_time AS (
    SELECT item_id,
        CASE 
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 5 AND 10 THEN 'Morning'
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 12 AND 15 THEN 'Afternoon'
           WHEN EXTRACT(HOUR FROM created_at::TIMESTAMP) BETWEEN 17 AND 19 THEN 'Evening' END AS time_of_day
    FROM orders),
ranked_items AS (
    SELECT  item_id, time_of_day, COUNT(*) AS order_count,
            ROW_NUMBER() OVER (PARTITION BY time_of_day ORDER BY COUNT(*) DESC) AS rank
    FROM orders_by_time
    WHERE time_of_day IS NOT NULL
    GROUP BY item_id, time_of_day)
	
SELECT  time_of_day, COALESCE(CAST(ri.item_id AS TEXT), 'No Item') AS item_id, COALESCE(mi.item_name, 'No Data') AS item_name,
        COALESCE(ri.order_count, 0) AS order_count
FROM ranked_items ri
LEFT JOIN menu_items mi ON ri.item_id = mi.item_id
WHERE ri.rank = 1
ORDER BY time_of_day ASC;


--                   /********   8. Employee Performance & Sales Contribution  ********\
-- Q20: Find employees working during the highest-revenue shifts.
SELECT  r.shift_id, r.staff_id, r.date AS shift_date, SUM(o.quantity * mi.item_price) AS total_shift_revenue
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
JOIN rota r ON o.created_at::date = r.date
JOIN shift s ON r.shift_id = s.shift_id
WHERE o.created_at::time BETWEEN s.start_time AND s.end_time
GROUP BY r.shift_id, r.staff_id, r.date
ORDER BY total_shift_revenue DESC;

SELECT * FROM coffeeshop;
SELECT * FROM ingredients;
SELECT * FROM inventary;
SELECT * FROM menu_items;
SELECT * FROM orders;
SELECT * FROM recipe;
SELECT * FROM rota;
SELECT * FROM shift;
SELECT * FROM staff;

-- Q21: Rank employees based on total revenue generated per shift.
SELECT  r.shift_id, r.staff_id, r.date AS shift_date, SUM(o.quantity * mi.item_price) AS total_shift_revenue,
        RANK() OVER (ORDER BY  SUM(o.quantity * mi.item_price) DESC) AS revenue_rank
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
JOIN rota r ON o.created_at::date = r.date
JOIN shift s ON r.shift_id = s.shift_id
WHERE o.created_at::time BETWEEN s.start_time AND s.end_time
GROUP BY r.shift_id, r.staff_id, r.date
ORDER BY total_shift_revenue DESC;

