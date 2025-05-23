-- Name: Rabbia Munir
-- Data Analytics Bootcamp
-- Capstone Project 1 Northwind Sales and RFM Analysis
-- Date : 22-03-2025


-- 1. Add Sales (Gross Revenue) in OrderDetails table
alter table `order details` add Sales float(10);
update `order details` 
set Sales= sum(UnitPrice * Quantity);


-- 2. Product wise Total sales
select ProductName, round(sum(Sales),2) as TotalSales
from `order details`
join products using (ProductID)
group by ProductName order by TotalSales desc;

-- 3. Employee wise Total sales
select concat(FirstName," ",LastName) as employee,
round(sum(Sales), 2) as TotalSales 
from orders join employees using (EmployeeID)
join `order details` using (OrderId)
group by employee order by TotalSales desc;


-- 4. Countrywise Total quantity
select country, sum(Quantity) as TotalQuantity
from customers join orders using (customerID)
join `order details` using (orderID)
group by Country order by TotalQuantity desc;

-- 5. Companyname, country wise TotalSales and TotalQuantity
select CompanyName, country, round(sum(Sales),2) as TotalSales, sum(Quantity)
from customers natural join orders
natural join `order details` group by CompanyName, Country order by TotalSales desc;

-- 6. Year wise Sales
alter table orders add OrderYear int(4);
update orders set OrderYear=year(shippeddate);
select OrderYear, round(sum(Sales),2) from Orders
join `order details` using (OrderID)
group by OrderYear;

-- 7. Top 10 suppliers company name
alter table Products add Purchases float(10);
update Products set Purchases=(UnitsInStock+UnitsOnOrder)*UnitPrice;
Select Purchases from Products;
select Companyname, round(sum(Purchases),2) as TotalPurchase from products
join suppliers using (supplierID)
group by CompanyName order by TotalPurchase desc limit 10;


-- 9. which shipvia most Freight?
select ShipVia, sum(Freight) from orders
group by ShipVia;

-- 10. Categories wise Total Sales
Select categoryName, round(sum(Sales),2) from categories
join products using (categoryID)
join `order details` using (productID)
group by CategoryName;


-- 11. RFM analyze 
-- Recency (R) – How recently a customer has made a purchase
SELECT 
    CustomerID, 
    MAX(orderDate) AS last_order_date, 
    DATEDIFF('1998-05-07', MAX(orderDate)) AS recency_days
FROM orders
GROUP BY CustomerID
order by recency_days;


-- Frequency (F) – How often a customer makes purchases
SELECT 
    customerID, Count(distinct OrderID) as order_count
FROM orders
GROUP BY customerID
Order by order_count;


-- Monetary (M) – How much a customer has spent
SELECT 
    o.customerID, 
    SUM(od.quantity * od.UnitPrice) AS total_spent
FROM orders o
JOIN `order details` od ON o.orderID = od.orderID
GROUP BY o.customerID
ORDER BY total_spent;


-- Combining RFM scores
SELECT 
    o.customerID, 
    DATEDIFF('1998-05-07', MAX(o.orderDate)) AS recency_days,
    COUNT(o.orderID) AS order_count,
    SUM(od.quantity * od.UnitPrice) AS total_spent
FROM orders o
JOIN `order details` od ON o.orderID = od.orderID
GROUP BY o.customerID ORDER BY o.customerID;

-- Segmenting Customers with RFM Scores
With RFMBase as (
SELECT customerID, recency_days, order_count, total_spent,
       NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY order_count DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY total_spent DESC) AS monetary_score
FROM (
    SELECT 
        o.customerID, 
        DATEDIFF('1998-05-07', MAX(o.orderDate)) AS recency_days,
        COUNT(o.orderID) AS order_count,
        SUM(od.quantity * od.Unitprice) AS total_spent
    FROM orders o
   JOIN `order details`od ON o.orderID  = od.orderID
    GROUP BY o.customerID ORDER BY o.customerID
) rfm_data )
SELECT frequency_score, Count(order_count), MAX(order_count), MIN(order_count)
from RFMBase
GROUP by frequency_score
Order by frequency_score;

-- creating new rfm table
CREATE TABLE RFM_Scores (
    CustomerID VARCHAR(10) PRIMARY KEY,
    CompanyName VARCHAR(255),
    Recency INT,
    Frequency INT,
    Monetary DECIMAL(10,2)
);
INSERT INTO RFM_Scores (CustomerID, CompanyName, Recency, Frequency, Monetary)
SELECT 
    c.CustomerID,
    c.CompanyName,
    
    -- Recency: Days since last order
DATEDIFF('1998-05-07', MAX(o.OrderDate)) AS Recency,

    -- Frequency: Total number of orders placed by the customer
    COUNT(o.OrderID) AS Frequency,
    
    -- Monetary: Total amount spent by the customer
    ROUND(SUM(od.UnitPrice * od.Quantity), 2) AS Monetary

FROM customers c
JOIN orders o ON c.CustomerID = o.CustomerID
JOIN `order details` od ON o.OrderID = od.OrderID

GROUP BY c.CustomerID, c.CompanyName;

SELECT * FROM RFM_Scores ORDER BY Monetary DESC;

ALTER TABLE RFM_Scores ADD COLUMN RFM_Score VARCHAR(10);
UPDATE RFM_Scores
SET RFM_Score = 
    CONCAT(
        CASE WHEN Recency <= 7 THEN 5
             WHEN Recency <= 16 THEN 4
             WHEN Recency <= 30 THEN 3
             WHEN Recency <= 64 THEN 2
             ELSE 1 END,
        
        CASE WHEN Frequency <= 10 THEN 5
             WHEN Frequency <= 15 THEN 4 
             WHEN Frequency <= 23 THEN 3 
             WHEN Frequency <= 34 THEN 2 
             WHEN Frequency <= 116 THEN 1 END,
        
        CASE WHEN Monetary <= 2423.3500 THEN 1
             WHEN Monetary <= 5297.8000 THEN 2 
             WHEN Monetary <= 11666.9000 THEN 3
             WHEN Monetary <= 21282.0200 THEN 4
             WHEN Monetary <= 117483.3900 THEN 5 END
    );
ALTER TABLE RFM_Scores ADD COLUMN Loyalty_Status VARCHAR(30);UPDATE RFM_Scores
SET Loyalty_Status = 
    CASE 
        WHEN RFM_Score LIKE '55%' THEN 'Elite Customers'
        WHEN RFM_Score LIKE '5%' OR RFM_Score LIKE '4%' THEN 'Loyal Customers'
        WHEN RFM_Score LIKE '3%' OR RFM_Score LIKE '34%' THEN 'Emerging Customers'
        WHEN RFM_Score LIKE '2%' OR RFM_Score LIKE '23%' THEN 'Casual Shoppers'
        WHEN RFM_Score LIKE '1%' OR RFM_Score LIKE '12%' THEN 'At-Risk Customers'
        ELSE 'Inactive Customers'
    END;