--- DISTRIBUTION SUPPLY CHAIN
-- 3 Tables: Product, Suppliers and Orders Tables

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--PRODUCT ANALYSIS
----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT * 
FROM ps.products;


-- The number of raw materials supplied by each supplier
SELECT SupplierID,
	COUNT(SupplierID) materials_supplied
FROM ps.products
GROUP BY SupplierID
ORDER BY materials_supplied DESC;

-- The DISTINCT number of products available
SELECT COUNT(DISTINCT RawMaterial) RawMaterial 
FROM ps.products;

-- The data is of from 2024-01-01 to 2024-12-09 (1 year)
SELECT 
	MIN(Transactiondate) oldest, 
	MAX(Transactiondate) newest
FROM ps.products;

--The average timetaken for a supplier to deliver the raw_materials
SELECT SupplierID,
	AVG(LeadTime_Days) timetaken
FROM ps.products
GROUP BY SupplierID
ORDER BY timetaken;

-- The total number of products each month
SELECT 
	MONTH(Transactiondate) mon_th,
	COUNT(ProductID) total_products
FROM ps.products
GROUP BY MONTH(Transactiondate)
ORDER BY total_products DESC;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--SUPPLIER ANALYSIS
----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT * 
FROM ps.suppliers;

SELECT COUNT(DISTINCT RawMaterial) RawMaterial, -- 13 RawMaterial
	COUNT(DISTINCT SupplierID) SupplierID, -- 10 Suppliers
	COUNT(DISTINCT SupplierName) SupplierName, -- 10 Suppliers
	COUNT(DISTINCT Country) Country, -- 10 Countries
	COUNT(DISTINCT Route) Route -- 2 Routes
FROM ps.suppliers;

--Which route delivers more raw materials: Sea>Air
SELECT Route,
	COUNT(DISTINCT RawMaterial) RawMaterial, --air 12 sea 13
	COUNT(RawMaterial) Total_RawMaterial
FROM ps.suppliers
GROUP BY Route;

SELECT Route, RawMaterial,
	COUNT(DISTINCT RawMaterial) RawMaterial --air does not deliver coal
FROM ps.suppliers
GROUP BY Route, RawMaterial;

SELECT * 
FROM ps.suppliers
WHERE RawMaterial = 'Coal'; --5 countries

--Number of countries in each Route: 7Sea > 3Air  
SELECT Route,
	COUNT(DISTINCT Country) Countrys
FROM ps.suppliers
GROUP BY Route;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--ORDERS ANALYSIS
----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT * 
FROM ps.orders;

--The total number of Orders: 47
SELECT 
	COUNT(DISTINCT OrderID) num_orders
FROM ps.orders;

--The RawMaterial with the:
SELECT RawMaterial,
	COUNT(*) num_orders,               --highest number of orders: Recycled Plastic 8
	SUM(Order_Quantity) Units_Sold      --highest number of units sold: Recycled Plastic 1564
FROM ps.orders
GROUP BY RawMaterial
ORDER BY Units_Sold DESC;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
---Further analysis
----------------------------------------------------------------------------------------------------------------------------------------------------------------
--CREATE VIEW ps.supplychain_summary AS 
SELECT 
	p.key_id,
	ProductID,
	OrderID,
	p.SupplierID,
	SupplierName,
	Country,
	Route,
	p.RawMaterial,
	ReorderLevel,
	LeadTime_Days,
	StockQuantity,
	avg_weekly_usage,
	(CAST(StockQuantity AS int) - CAST(ReorderLevel AS int)) / (CAST(avg_weekly_usage AS int)) AS stockweeks,
	(LeadTime_Days / 7) LeadTime_Weeks,
	 CASE 
        WHEN (CAST(StockQuantity AS int) - CAST(ReorderLevel AS int)) / (CAST(avg_weekly_usage AS int)) < (LeadTime_Days / 7) 
        THEN 'Reorder'
        ELSE 'Sufficient Stock' 
    END AS Status,
	ROUND(UnitPrice, 2) UnitPrice,
	Order_Quantity,
	ROUND((UnitPrice * Order_Quantity), 2) AS Revenue, --- create a new column of what i need
	Transactiondate

FROM ps.products p
LEFT JOIN ps.suppliers s
	ON p.SupplierID = s.SupplierID
LEFT JOIN ps.orders o
	ON s.SupplierID = o.SupplierID;

	---RUN THE VIEW
SELECT *
FROM ps.supplychain_summary;

--The number of RawMaterial each supplier supplied out of 13 RawMaterial
SELECT SupplierName,
	COUNT(RawMaterial) Total_products,
	COUNT(DISTINCT RawMaterial) num_prods
FROM ps.supplychain_summary
GROUP BY SupplierName;

---Country that supplies the highest number of rawmaterials and total number of materials supplied
SELECT Country,
	COUNT(DISTINCT RawMaterial) RawMaterial, --Australia:10 
	COUNT(RawMaterial) Total_RawMaterial --UAE 
FROM ps.supplychain_summary
GROUP BY Country
ORDER BY Total_RawMaterial DESC;

--RawMaterial with the highest revenue: Nickel
--RawMaterial with the highest orders: Recycled Plastic
SELECT RawMaterial,
	ROUND(SUM(Revenue), 2) Total_Revenue, 
	COUNT(OrderID) Total_Quantity 
FROM ps.supplychain_summary
GROUP BY RawMaterial
ORDER BY Total_Revenue DESC;

-- WHY does Nickel generate more revenue despite fewer orders?
-- Let's compare pricing and order sizes
SELECT 
    RawMaterial,
    COUNT(OrderID) AS num_orders,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    ROUND(AVG(UnitPrice), 2) AS avg_unit_price,
    ROUND(AVG(Order_Quantity), 2) AS avg_order_size,
    ROUND(SUM(Revenue) / COUNT(OrderID), 2) AS revenue_per_order
FROM ps.supplychain_summary
WHERE RawMaterial IN ('Recycled Plastic', 'Nickel')
GROUP BY RawMaterial;

-- INSIGHT: Is Nickel more expensive per unit? Or do customers order it in larger quantities?
-- This tells you if it's a premium product or a bulk product


--Cheap and Expensive by RawMaterial
SELECT RawMaterial,
	MAX(UnitPrice) expensive,
	MIN(UnitPrice) cheap
FROM ps.supplychain_summary
GROUP BY RawMaterial

--Number of products in each status
SELECT 
	RawMaterial,
	Status,
	COUNT(ProductID) products
FROM ps.supplychain_summary
GROUP BY Status, RawMaterial;

-- Products at risk of stockout
SELECT RawMaterial, SupplierName, 
    StockQuantity, ReorderLevel, stockweeks, LeadTime_Weeks
FROM ps.supplychain_summary
WHERE Status = 'Reorder'
ORDER BY stockweeks ASC;

-- Best performing suppliers
SELECT SupplierName, Country, Route,
    COUNT(DISTINCT RawMaterial) AS materials_supplied,
    AVG(LeadTime_Days) AS avg_lead_time,
    SUM(Revenue) AS total_revenue
FROM ps.supplychain_summary
GROUP BY SupplierName, Country, Route
ORDER BY total_revenue DESC;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
---Change Over Time Analysis
----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analysis of Revenue over time
SELECT
    MONTH(Transactiondate) AS order_month,
    ROUND(SUM(Revenue), 1) AS total_revenue,
    COUNT(DISTINCT OrderID) AS total_orders,
    SUM(Order_Quantity) AS total_quantity
FROM ps.supplychain_summary
GROUP BY  MONTH(Transactiondate)
ORDER BY  MONTH(Transactiondate);

--- Cumulative Analysis
SELECT
	order_date,
	total_revenue,
	ROUND(SUM(total_revenue) OVER (ORDER BY order_date), 2) AS running_total_sales,
	ROUND(AVG(avg_price) OVER (ORDER BY order_date), 2) AS moving_average_price
FROM
(
    SELECT 
        DATETRUNC(month, Transactiondate) AS order_date,
        ROUND(SUM(Revenue), 2) AS total_revenue,
        AVG(UnitPrice) AS avg_price
    FROM ps.supplychain_summary
    GROUP BY DATETRUNC(month, Transactiondate)
) t

--Revenue MoM%
SELECT order_month, current_revenue,
	LAG(current_revenue) OVER (ORDER BY order_month) AS pm_revenue,
    current_revenue - LAG(current_revenue) OVER (ORDER BY order_month) AS diff_pm,
    CASE 
        WHEN current_revenue - LAG(current_revenue) OVER (ORDER BY order_month) > 0 THEN 'Increase'
        WHEN current_revenue - LAG(current_revenue) OVER (ORDER BY order_month) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS pm_change
FROM
(SELECT
    DATETRUNC(month, Transactiondate) AS order_month,
    ROUND(SUM(Revenue), 2) AS current_revenue
FROM ps.supplychain_summary
GROUP BY  DATETRUNC(month, Transactiondate)
)t

--Product Revenue MoM%

SELECT order_month, RawMaterial, current_revenue,
LAG(current_revenue) OVER (PARTITION BY RawMaterial ORDER BY order_month) AS pm_revenue,
    current_revenue - LAG(current_revenue) OVER (PARTITION BY RawMaterial ORDER BY order_month) AS diff_pm,
    CASE 
        WHEN current_revenue - LAG(current_revenue) OVER (PARTITION BY RawMaterial ORDER BY order_month) > 0 THEN 'Increase'
        WHEN current_revenue - LAG(current_revenue) OVER (PARTITION BY RawMaterial ORDER BY order_month) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS pm_change
FROM
(SELECT RawMaterial,
    DATETRUNC(month, Transactiondate) AS order_month,
    ROUND(SUM(Revenue), 2) AS current_revenue
FROM ps.supplychain_summary
GROUP BY  DATETRUNC(month, Transactiondate), RawMaterial
--ORDER BY  DATETRUNC(month, Transactiondate)
)t

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SUPPLYCHAIN OVERVIEW (What would be part of the final report)
----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Joining all the 3 tables
---Pick the columns i need only and any computations i need to do
WITH base_query AS(
SELECT 
	p.key_id,
	ProductID,
	OrderID,
	p.SupplierID,
	SupplierName,
	Country,
	Route,
	p.RawMaterial,
	ReorderLevel,
	LeadTime_Days,
	StockQuantity,
	avg_weekly_usage,
	(CAST(StockQuantity AS int) - CAST(ReorderLevel AS int)) / (CAST(avg_weekly_usage AS int)) AS stockweeks,
	(LeadTime_Days / 7) LeadTime_Weeks,
	 CASE 
        WHEN (CAST(StockQuantity AS int) - CAST(ReorderLevel AS int)) / (CAST(avg_weekly_usage AS int)) < (LeadTime_Days / 7) 
        THEN 'Reorder'
        ELSE 'Sufficient Stock' 
    END AS Status,
	ROUND(UnitPrice, 2) UnitPrice,
	Order_Quantity,
	ROUND((UnitPrice * Order_Quantity), 2) AS Revenue, --- create a new column of what i need
	Transactiondate

FROM ps.products p
LEFT JOIN ps.suppliers s
	ON p.SupplierID = s.SupplierID
LEFT JOIN ps.orders o
	ON s.SupplierID = o.SupplierID
),
calc_query AS(
SELECT
	DATETRUNC(month, Transactiondate) order_month,
	RawMaterial, SupplierName, Country, Route, Status,
	COUNT(DISTINCT RawMaterial) Total_Products,
	COUNT(DISTINCT OrderID) Total_Orders,
	--COUNT(DISTINCT SupplierName) Total_Suppliers,
	COUNT(DISTINCT Country) Countries,
	SUM(Order_Quantity) Total_Order_Quantity,
	SUM(Revenue) Total_Revenue
FROM base_query 
GROUP BY DATETRUNC(month, Transactiondate),RawMaterial, SupplierName, Country, Route, Status
)
SELECT * 
FROM calc_query;

-- Overall Business Metrics
SELECT 
    COUNT(DISTINCT SupplierID) AS total_suppliers,
    COUNT(DISTINCT ProductID) AS total_products,
    COUNT(DISTINCT OrderID) AS total_orders,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    ROUND(AVG(Revenue), 2) AS avg_order_value
FROM ps.supplychain_summary;






















