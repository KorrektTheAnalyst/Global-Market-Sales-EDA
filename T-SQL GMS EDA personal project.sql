
--Data cleaning with Excel, EDA with SQL, visualization with Tableou/Power BI personal project--
--Data source: kaggle.com. Dataset: Global Market Sales Data--

--Creating database for data import--

DROP DATABASE IF EXISTS GlobalMarketSalesDataPrel;

CREATE DATABASE GlobalMarketSalesDataPrel;

--Creating database for EDA--

DROP DATABASE IF EXISTS GlobalMarketSalesDataEDA;

CREATE DATABASE GlobalMarketSalesDataEDA;

--Creating tables, defining data integrity--

USE GlobalMarketSalesDataEDA;

DROP TABLE IF EXISTS dbo.OrdersDimen;
CREATE TABLE dbo.OrdersDimen
     (
 OrderID INT NOT NULL,
 OrderDate SMALLDATETIME NOT NULL,
 OrderPriority VARCHAR(30) ,
 Ordid INT,
 CONSTRAINT PK_OrdersDimen
 PRIMARY KEY(Ordid)
     )
;

DROP TABLE IF EXISTS dbo.ProdDimen;
CREATE TABLE dbo.ProdDimen
    (
 ProductCategory VARCHAR(30) NULL,
 ProductSubCategory VARCHAR(30) NULL,
 Prodid INT NOT NULL,
 CONSTRAINT PK_ProdDimen
 PRIMARY KEY(Prodid)
    )
;

DROP TABLE IF EXISTS dbo.ShippingDimen;
CREATE TABLE dbo.ShippingDimen
    (
 OrderID INT NOT NULL,
 ShipMode VARCHAR(30) NULL,
 ShipDate SMALLDATETIME NOT NULL,
 Shipid INT NOT NULL,
 CONSTRAINT PK_ShippingDimen
 PRIMARY KEY (Shipid),
    )
;

DROP TABLE IF EXISTS dbo.MarketFact;
CREATE TABLE dbo.MarketFact
    (
 Ordid INT NOT NULL,
 Prodid INT NOT NULL,
 Shipid INT NOT NULL,
 Custid INT NOT NULL,
 Sales MONEY NOT NULL,
 Discount FLOAT,
 OrderQuantity FLOAT,
 Profit FLOAT,
 ShippingCost FLOAT,
 ProductBaseMargin FLOAT,
 CONSTRAINT FK_MarketFact
 FOREIGN KEY(Ordid) REFERENCES dbo.OrdersDimen (Ordid),
 FOREIGN KEY(Prodid) REFERENCES dbo.ProdDimen (Prodid),
 FOREIGN KEY(Shipid) REFERENCES dbo.ShippingDimen (Shipid)
 )
;

--Inserting data--

	BEGIN TRANSACTION

INSERT INTO GlobalMarketSalesDataEDA.dbo.OrdersDimen (OrderID, OrderDate, OrderPriority, Ordid)
	SELECT OrderID, OrderDate, OrderPriority, Ordid
	FROM GlobalMarketSalesDataPrel.dbo.OrdersDimen
;

INSERT INTO GlobalMarketSalesDataEDA.dbo.ProdDimen (ProductCategory, ProductSubCategory, Prodid)
	SELECT ProductCategory, ProductSubCategory, ProdId
	FROM GlobalMarketSalesDataPrel.dbo.ProdDimen
;

INSERT INTO GlobalMarketSalesDataEDA.dbo.ShippingDimen (OrderID, ShipMode, ShipDate, Shipid)
	SELECT OrderID, ShipMode, ShipDate, Shipid
	FROM GlobalMarketSalesDataPrel.dbo.ShippingDimen
;

INSERT INTO GlobalMarketSalesDataEDA.dbo.MarketFact(Ordid, Prodid, Shipid, Custid, Sales, Discount, OrderQuantity, Profit, ShippingCost, ProductBaseMargin)
	SELECT Ordid, Prodid, Shipid, Custid, Sales, Discount, OrderQuantity, Profit, ShippingCost, ProductBaseMargin
	FROM GlobalMarketSalesDataPrel.dbo.MarketFact
;
	COMMIT TRANSACTION

--Starting EDA--

--1.1. Global numbers--

SELECT
(SELECT MIN(OrderDate) FROM dbo.OrdersDimen) AS Mindate,
(SELECT MAX(OrderDate) FROM dbo.OrdersDimen) AS Maxdate,
(SELECT COUNT(*) FROM dbo.OrdersDimen) AS CountOfOrders,
(SELECT MAX(Ordid) FROM dbo.OrdersDimen) AS MaxOrdid,
(SELECT COUNT(*) FROM dbo.ProdDimen) AS CountOfProduct,
(SELECT MAX(Prodid) FROM dbo.ProdDimen) AS MaxProdid,
(SELECT COUNT(*) FROM dbo.ShippingDimen) AS CountOfShipping,
(SELECT MAX(Shipid) FROM dbo.ShippingDimen) AS MaxShipid,
(SELECT COUNT(DISTINCT(Custid)) FROM dbo.MarketFact) AS CountOfCustid,
(SELECT SUM(Sales) FROM dbo.MarketFact) AS TotalSales,
(SELECT SUM(Profit) FROM dbo.MarketFact) AS TotalProfit,
(SELECT SUM(ShippingCost) FROM dbo.MarketFact) AS TotalShippingCost,
(SELECT AVG(ProductBaseMargin) FROM dbo.MarketFact) AS AverageMargin
;

--2.1. Single-table queries--

--2.1.1. Finding duplicates of OrderID in dbo.OrdersDimen--

SELECT OrderID, COUNT(*) AS CountOrders FROM dbo.OrdersDimen
GROUP BY OrderID
HAVING COUNT(*) > 1
ORDER BY CountOrders DESC
;

--2.1.2. Finding duplicates of OrderID in dbo.OrdersDimen using Window Function--

SELECT *, ROW_NUMBER() OVER (PARTITION BY OrderID ORDER BY OrderID) AS RowNum
FROM dbo.OrdersDimen
ORDER BY RowNum DESC, OrderID ASC
;

--2.1.3. Finding TOP 3 Ordid with MAX Order Quantity from dbo.MarketFact--
--2.1.3.1. Using OFFSET FETCH--

SELECT Ordid, MAX(OrderQuantity) AS MaxOrderQuantity
FROM dbo.MarketFact
GROUP BY Ordid
ORDER BY MaxOrderQuantity DESC
OFFSET 0 ROWS FETCH FIRST 3 ROWS ONLY
;

--2.1.3.2. Using TOP --

SELECT TOP(3) Ordid, MAX(OrderQuantity) AS MaxOrderQuantity
FROM dbo.MarketFact
GROUP BY Ordid
ORDER BY MaxOrderQuantity DESC
;

--2.1.3.3. Using TOP WITH TIES--

SELECT TOP(3) WITH TIES Ordid, MAX(OrderQuantity) AS MaxOrderQuantity
FROM dbo.MarketFact
GROUP BY Ordid
ORDER BY MaxOrderQuantity DESC
;

--3. Joins --

--3.1. Finding difference in days between dates of orders and dates of shipping--

SELECT OD.OrderID, OD.OrderDate, SD.ShipDate, DATEDIFF(DAY, OrderDate, ShipDate) AS DIFDAYS
FROM dbo.OrdersDimen AS OD JOIN dbo.ShippingDimen AS SD ON OD.OrderID = SD.OrderID
ORDER BY DIFDAYS DESC
;

--3.2. Exploring Shipping Cost--

SELECT SD.ShipMode, SUM(MF.Sales) AS Sales, SUM(MF.Profit) AS Profit, AVG(MF.Discount) AS AVGDiscount, AVG(MF.ProductBaseMargin) AS AVGMargin,
SUM(MF.ShippingCost) AS ShipCost, SUM(MF.ShippingCost)/SUM(MF.Sales) AS SalesCostRatio,
SUM(MF.ShippingCost)/SUM(MF.Profit) AS ProfitCostRatio
FROM dbo.ShippingDimen AS SD JOIN dbo.MarketFact AS MF ON SD.Shipid = MF.Shipid
GROUP BY SD.ShipMode
ORDER BY ShipCost DESC
;

--3.3. Exploring Products--

--3.3.1. Product Category Sales and Marginality--

SELECT PD.ProductCategory, SUM(MF.Sales) AS Sales, SUM(MF.Profit) AS Profit, SUM(MF.Profit)/SUM(MF.Sales) AS Margin
FROM dbo.ProdDimen AS PD JOIN dbo.MarketFact AS MF ON PD.Prodid = MF.Prodid
GROUP BY PD.ProductCategory
ORDER BY Profit DESC
;

--3.3.2. Finding unprofitable Product Sub Categories--

SELECT PD.ProductSubCategory, SUM(MF.Sales) AS Sales, SUM(MF.Profit) AS Profit, SUM(MF.Profit)/SUM(MF.Sales) AS Margin
FROM dbo.ProdDimen AS PD JOIN dbo.MarketFact AS MF ON PD.Prodid = MF.Prodid
GROUP BY PD.ProductSubCategory
HAVING SUM(MF.Profit) <= 0
ORDER BY Profit DESC
;

--3.3.3. More joins--

--3.3.3.1. Producing table with a sequence of integers--

DROP TABLE IF EXISTS dbo.Digits;
CREATE TABLE dbo.Digits(digit INTEGER NOT NULL PRIMARY KEY);

INSERT INTO dbo.Digits(digit)
VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
;

		--Expanding up to 10000--

DROP TABLE IF EXISTS dbo.Nums;
CREATE TABLE dbo.Nums(N INTEGER NOT NULL PRIMARY KEY);

INSERT INTO dbo.Nums(N)

SELECT D4.digit*1000 + D3.digit*100 + D2.digit*10 + D1.digit + 1 AS N
FROM dbo.Digits AS D1
	CROSS JOIN dbo.Digits AS D2
	CROSS JOIN dbo.Digits AS D3
	CROSS JOIN dbo.Digits AS D4
;

DROP TABLE dbo.Digits;

--3.3.3.2. Finding dates with no orders - using CTE and join--

WITH DateRange AS
(
SELECT 
 DATEADD(day, N - 1, '20090101') AS Dates
FROM dbo.Nums
WHERE N <= DATEDIFF(day, '20090101', '20121230') + 1
)
SELECT Dates, OD.OrderID FROM DateRange AS D LEFT OUTER JOIN dbo.OrdersDimen AS OD ON D.Dates = OD.OrderDate
WHERE OD.OrderID IS NULL
ORDER BY Dates
;

--4. Subqueries--

--4.1. Finding custid with the highest number of orders--

SELECT Custid, Ordid
FROM dbo.MarketFact
WHERE Custid IN
(
SELECT TOP(1) WITH TIES MF.Custid
FROM dbo.MarketFact AS MF
GROUP BY MF.Custid
ORDER BY COUNT(*) DESC
)
;

--4.2. Finding sales and profit of Ordid with "HIGH" priority--

SELECT Ordid, SUM(Sales) AS Sales, SUM(Profit) AS Profit
FROM dbo.MarketFact
WHERE Ordid IN 
(
SELECT Ordid FROM dbo.OrdersDimen WHERE OrderPriority = 'HIGH'
)
GROUP BY Ordid
ORDER BY Profit DESC, Sales DESC
;

--4.3. Calculating a running-total sales for each custid and year - with view and subquery--

DROP VIEW IF EXISTS YearMarketFact;
GO
CREATE VIEW YearMarketFact
AS
SELECT MF.Custid, YEAR(OD.OrderDate) AS YearSales, SUM(MF.Sales) AS Sales
FROM dbo.MarketFact AS MF JOIN dbo.OrdersDimen AS OD ON MF.Ordid = OD.Ordid
GROUP BY MF.Custid, YEAR(OD.OrderDate)
;
GO

SELECT Custid, YearSales, Sales, 
	(SELECT SUM(YMF2.Sales) FROM dbo.YearMarketFact AS YMF2 
	WHERE YMF2.Custid = YMF1.Custid AND 
	YMF2.YearSales <= YMF1.YearSales) AS RunQty
FROM YearMarketFact AS YMF1
ORDER BY Custid, YearSales
;

--4.4. Finding Custid with orders only in 2009--

SELECT * FROM dbo.YearMarketFact AS Y
WHERE EXISTS
(
SELECT * FROM dbo.YearMarketFact AS M WHERE M.Custid = Y.Custid AND M.YearSales = 2009
)
AND NOT EXISTS
(
SELECT * FROM dbo.YearMarketFact AS M WHERE M.Custid = Y.Custid AND Y.YearSales <> 2009
)
ORDER BY Custid
;

--5. TVFs--

--5.1. Function for finding TOP n Total Quantity Prodid for requested Custid--

DROP FUNCTION IF EXISTS TopCustProd;
GO
CREATE FUNCTION TopCustProd
(@Custid AS INTEGER, @n AS INTEGER)
RETURNS TABLE
AS
RETURN
SELECT TOP (@n) Prodid, Custid, SUM(OrderQuantity) AS TotalQty, SUM(Sales) AS TotalSales, SUM(Profit) AS TotalProfit
FROM dbo.MarketFact
WHERE Custid = @Custid
GROUP BY Prodid, Custid
ORDER BY TotalQty DESC
GO
;

--5.2. Function for finding TOP n most profitable prodid for each ShipMode--

DROP FUNCTION IF EXISTS TopShipmodeProd;
GO
CREATE FUNCTION TopShipmodeProd
(@Shipmode AS VARCHAR(30), @n AS INTEGER)
RETURNS TABLE
AS
RETURN
SELECT TOP(@n) MF.Prodid, SD.ShipMode, SUM(MF.OrderQuantity) AS TotalQty, SUM(MF.Sales) AS TotalSales, SUM(MF.Profit) AS TotalProfit
FROM dbo.MarketFact AS MF RIGHT OUTER JOIN dbo.ShippingDimen AS SD ON MF.Shipid = SD.Shipid
WHERE SD.ShipMode LIKE @Shipmode
GROUP BY Prodid, ShipMode
ORDER BY TotalProfit DESC
GO
;

--5.3. Finding TOP 3 most profitable Prodid for each ShipMode--

SELECT DISTINCT(SD.ShipMode), TSP.Prodid, TSP.TotalProfit FROM dbo.ShippingDimen AS SD 
	CROSS APPLY 
	TopShipmodeProd (SD.ShipMode, 3) AS TSP
ORDER BY SD.ShipMode;


--6. Pivoting--

--6.1 Counting OrderID for each year--

SELECT [2009] AS count2009, [2010] AS count2010, [2011] AS count2011, [2012] AS count2012
FROM (SELECT YEAR(OrderDate) AS Orderyear
FROM dbo.OrdersDimen) AS OD
	PIVOT
(COUNT(Orderyear) FOR orderyear IN ([2009], [2010], [2011], [2012])) AS PY;

 --6.2 Counting Ordid for each Custid and year--

SELECT Custid, [2009] AS count2009, [2010] AS count2010, [2011] AS count2011, [2012] AS count2012
FROM 
(SELECT YEAR(OD.OrderDate) AS orderyear, MF.Custid FROM dbo.OrdersDimen AS OD JOIN dbo.MarketFact AS MF ON OD.Ordid = MF.Ordid) AS X
	PIVOT
(COUNT(orderyear) FOR orderyear IN ([2009], [2010], [2011], [2012])) AS Y
ORDER BY Custid
 ;

 --7. Some Window Functions implementations--

 --7.1 Running total sales for custid with Window Function--

 SELECT Custid, YearSales, Sales,
	SUM(Sales) OVER(PARTITION BY Custid ORDER BY YearSales
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunSales
FROM YearMarketFact
;

--7.2 Ranking custid on Sales with NTILE--

WITH CustSales AS
(
	SELECT Custid, SUM(Sales) AS TtlSales
	FROM YearMarketFact
	GROUP BY Custid
)

SELECT Custid, TtlSales,
	NTILE(10) OVER(ORDER BY TtlSales) AS Ntile
FROM CustSales
ORDER BY Custid
;

--7.3 Exploring Sales vs Custid--

SELECT Custid, YearSales, Sales, 
	SUM(Sales) OVER() AS TtlSales,
	SUM(Sales) OVER(PARTITION BY Custid) AS CustTtlSales,
		100. * Sales / SUM(Sales) OVER() AS PctTtlSales,
		100. * Sales / SUM(Sales) OVER(PARTITION BY Custid) AS PctCustTtlSales
FROM YearMarketFact
ORDER BY Custid, YearSales
;

--7.4 Finding "missing" OrderID (defining "islands")--

SELECT MIN(OrderID) AS StartRange, MAX(OrderID) AS EndRange
FROM 
	(SELECT OrderID,  OrderID - ROW_NUMBER() OVER(ORDER BY OrderID) AS Grp
		FROM dbo.OrdersDimen) AS D
GROUP BY Grp;

--8 Stored procedures--

--8.1 Procedure for counting Ordid for Custid as input--

DROP PROC IF EXISTS GetCustidOrdid;
GO
CREATE PROC GetCustidOrdid
 @Custid AS INT,
 @Numrows AS INT OUTPUT
AS
SET NOCOUNT ON;
SELECT Ordid, Custid 
FROM dbo.MarketFact
WHERE Custid = @Custid
SET @Numrows = @@rowcount;
GO
;

DECLARE @CRows AS INT

EXEC GetCustidOrdID @Custid = 1000, @Numrows = @CRows OUTPUT; 
SELECT @CRows AS Numrows
;

--9. Some additional queries--

--9.1 Grouping Ordid on Sales--

SELECT COUNT(Ordid) AS NumOrdid, FLOOR(Sales/1000) * 1000 AS SGroup
FROM dbo.MarketFact
GROUP BY FLOOR(Sales/1000) * 1000
ORDER BY SGroup DESC
;

--9.2 Defining profitable/unprofitable Ordid with CASE statement--

SELECT Ordid, SUM(Profit) AS Profit,
CASE 
	WHEN SUM(Profit) > 0 THEN 'Profitable'
	WHEN SUM(Profit) = 0 THEN 'Zero profit'
	WHEN SUM(Profit) < 0 THEN 'Unprofitable'
		END AS Profitability
FROM dbo.MarketFact
GROUP BY Ordid
ORDER BY Profitability
;

--9.3 Finding most profitable prodid--

SELECT Prodid, SUM(Profit) AS Profit
FROM dbo.MarketFact
GROUP BY Prodid
ORDER BY Profit DESC
OFFSET 0 ROWS FETCH FIRST 3 ROWS ONLY
;

--9.4 Finding share of each OrderPriority--

SELECT DISTINCT OrderPriority, 
	COUNT(*) OVER () AS NumOrdid, 
	COUNT(*) OVER (PARTITION BY OrderPriority) AS NumOrdPr,
		100. * COUNT(*) OVER (PARTITION BY OrderPriority)/ COUNT(*) OVER () AS PctOrdPr
FROM dbo.OrdersDimen
;

-----------------------------------------------------------------------------------
--End of project--