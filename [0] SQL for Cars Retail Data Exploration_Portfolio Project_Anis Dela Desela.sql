########################################
##### CARS RETAIL DATA EXPLORATION #####
########################################

USE CARS_RETAIL;
#######################################################################################################
# 1
-- The store owner is interested in knowing the Nth most expensive product ordered by each customer.
-- Create Procedure for the Expensive Product
DELIMITER //
CREATE PROCEDURE EXPENSIVE_PRODUCT(
IN RANK_PRODUCT_PARAM INT
)

BEGIN
-- Gather the customer data needed
	WITH CUSTOMER_DATA AS(
		SELECT C.CUSTOMERNUMBER, C.CUSTOMERNAME,
				O.ORDERNUMBER
		FROM CUSTOMERS AS C
		JOIN ORDERS AS O ON C.CUSTOMERNUMBER = O.CUSTOMERNUMBER)
        
-- Gather the product details that include the product price
	, PRODUCT_DATA AS(
		SELECT OD.ORDERNUMBER,
				OD.PRODUCTCODE,
				OD.PRICEEACH,
				P.PRODUCTNAME
		FROM ORDERDETAILS AS OD
		JOIN PRODUCTS AS P 
		ON P.PRODUCTCODE = OD.PRODUCTCODE)
        
-- Combine the product and customer data
	, RAW_DATA AS(
		SELECT C.CUSTOMERNUMBER, C.CUSTOMERNAME, C.ORDERNUMBER,
				P.PRODUCTCODE, P.PRODUCTNAME, P.PRICEEACH,
				ROW_NUMBER() OVER(PARTITION BY C.CUSTOMERNUMBER, C.CUSTOMERNAME ORDER BY P.PRICEEACH DESC) AS RANK_PRODUCT
		FROM CUSTOMER_DATA AS C
		JOIN PRODUCT_DATA AS P
		ON C.ORDERNUMBER = P.ORDERNUMBER)

	SELECT CUSTOMERNAME, PRODUCTNAME, PRICEEACH, RANK_PRODUCT
	FROM RAW_DATA
    WHERE RANK_PRODUCT=RANK_PRODUCT_PARAM;
END //
DELIMITER ;

-- Show the procedure status
SHOW PROCEDURE STATUS;

-- To acces the procedure, use 'CALL'
CALL EXPENSIVE_PRODUCT('2');

#####################################################################################################
#2
-- The store owner wants to see the customers who placed the first and last orders in each country.
-- Get the first and last date of order for each country
WITH FIRST_LAST_CUST AS(
SELECT C.CUSTOMERNUMBER, C.CUSTOMERNAME,
		C.COUNTRY,
        O.ORDERDATE,
        MAX(O.ORDERDATE) OVER(PARTITION BY COUNTRY) AS MAXDATE,
        MIN(O.ORDERDATE) OVER(PARTITION BY COUNTRY) AS MINDATE
FROM CUSTOMERS AS C
JOIN ORDERS AS O
ON C.CUSTOMERNUMBER = O.CUSTOMERNUMBER
ORDER BY COUNTRY)

-- Gather the first customer for each country
, FIRST_ORDER_CUST AS(
SELECT * FROM FIRST_LAST_CUST
WHERE ORDERDATE = MINDATE)

-- Gather the last customer for each country
, LAST_ORDER_CUST AS(
SELECT * FROM FIRST_LAST_CUST
WHERE ORDERDATE = MAXDATE)

-- Combine the first and latest customer for each country
SELECT F.CUSTOMERNAME AS FIRST_CUST,
		L.CUSTOMERNAME AS LAST_CUST,
        F.COUNTRY,
        L.MAXDATE,
        F.MINDATE
FROM LAST_ORDER_CUST AS L
JOIN FIRST_ORDER_CUST AS F
ON F.COUNTRY = L.COUNTRY;

#####################################################################################################
#3
-- The store owner wants to see the monthly and yearly sales and transaction trends.
-- TOTAL ORDER RAW
CREATE VIEW RAW_ORDER_SALES AS
WITH RAW_ORDER AS(
SELECT ORDERDATE,
		ORDERNUMBER
FROM ORDERS
ORDER BY ORDERDATE)

-- TOTAL PENJUALAN RAW
, RAW_SALES AS(
SELECT OD.ORDERNUMBER, 
		OD.QUANTITYORDERED, 
        O.ORDERDATE
FROM ORDERDETAILS AS OD
JOIN ORDERS AS O
ON OD.ORDERNUMBER = O.ORDERNUMBER
ORDER BY ORDERDATE)

-- TOTAL TRANSAKSI DAN ORDER
SELECT O.ORDERNUMBER,
		O.ORDERDATE,
        S.QUANTITYORDERED
FROM RAW_SALES AS S
JOIN RAW_ORDER AS O
ON S.ORDERNUMBER = O.ORDERNUMBER
ORDER BY O.ORDERDATE;
SELECT * FROM RAW_ORDER_SALES;

-- GET MONTHLY ORDER & SALES
SELECT DATE_FORMAT(ORDERDATE, '%M %Y') AS MONTH_YEAR_ORDER,
		COUNT(DISTINCT ORDERNUMBER) AS TOTAL_ORDER,
        SUM(QUANTITYORDERED) AS TOTAL_SALES
FROM RAW_ORDER_SALES
GROUP BY DATE_FORMAT(ORDERDATE, '%M %Y')
ORDER BY MIN(ORDERDATE);

-- GET YEARLY ORDER & SALES
SELECT DATE_FORMAT(ORDERDATE, '%Y') AS YEAR_ORDER,
		COUNT(DISTINCT ORDERNUMBER) AS TOTAL_ORDER,
        SUM(QUANTITYORDERED) AS TOTAL_SALES
FROM RAW_ORDER_SALES
GROUP BY DATE_FORMAT(ORDERDATE, '%Y')
ORDER BY MIN(ORDERDATE);

#####################################################################################################
#4
/*
From the transactions that have been made in the store, 
the store owner is interested in knowing how many total customer payments are above or below the average total payments.*/
-- Count total payments each customer
WITH COUNT_PAYMENT AS(
SELECT P.CUSTOMERNUMBER,
		C.CUSTOMERNAME,
		COUNT(DISTINCT P.CHECKNUMBER) AS NUMBER_PAYMENT
FROM PAYMENTS AS P
JOIN CUSTOMERS AS C
ON P.CUSTOMERNUMBER = C.CUSTOMERNUMBER
GROUP BY CUSTOMERNUMBER)

-- Get the average number of all payments
, AVERAGE_PAYMENTS AS(
SELECT CUSTOMERNUMBER,
		CUSTOMERNAME,
		NUMBER_PAYMENT,
		AVG(NUMBER_PAYMENT) OVER() AS AVG_PAYMENT,
        CASE
			WHEN AVG(NUMBER_PAYMENT)>NUMBER_PAYMENT THEN 'Below Average'
            ELSE 'Above Average'
		END AS PAYMENT_STATUS
FROM COUNT_PAYMENT
GROUP BY CUSTOMERNUMBER)

SELECT *
FROM AVERAGE_PAYMENTS;


#####################################################################################################
#5
/*
The store owner plans to create a customer loyalty program by providing special facilities to customers who fall into the Loyal Customer category. Before implementing it, he requests to categorize customers based on their order frequency.
- If a customer has ordered once, they are categorized as a One-time customer.
- If a customer has ordered twice, they are categorized as a Repeated customer.
- If a customer has ordered three times, they are categorized as a Frequent customer.
- If a customer has ordered at least four times, they are categorized as a Loyal customer.*/

SELECT DISTINCT(O.CUSTOMERNUMBER),
		C.CUSTOMERNAME,
        COUNT(O.ORDERDATE) AS TOTAL_ORDER,
        CASE
			WHEN COUNT(O.ORDERDATE) = 1 THEN 'One-Time Customer'
            WHEN COUNT(O.ORDERDATE) = 2 THEN 'Repeated Customer'
            WHEN COUNT(O.ORDERDATE) = 3 THEN 'Frequent Customer'
            WHEN COUNT(O.ORDERDATE) >= 4 THEN 'Loyal Customer'
            ELSE 'Not Customer'
		END AS CUSTOMER_TYPE
FROM ORDERS AS O
JOIN CUSTOMERS AS C
ON O.CUSTOMERNUMBER = C.CUSTOMERNUMBER
GROUP BY CUSTOMERNUMBER
ORDER BY CUSTOMERNUMBER;

#####################################################################################################
#6
/*
The store owner is interested in understanding product purchase trends in each country. 
He requests to find out the most ordered product category in each country.*/
-- Gather Country, Customer Number, and the Order Number
WITH CUST_COUNTRY AS(
SELECT O.CUSTOMERNUMBER, O.ORDERNUMBER, C.COUNTRY
FROM CUSTOMERS AS C 
JOIN ORDERS AS O ON C.CUSTOMERNUMBER = O.CUSTOMERNUMBER)

-- Gather the Product Category
, PRODUCT_CATEGORY AS(
SELECT OD.ORDERNUMBER, OD.PRODUCTCODE, P.PRODUCTNAME, P.PRODUCTLINE
FROM ORDERDETAILS AS OD 
JOIN PRODUCTS AS P ON OD.PRODUCTCODE = P.PRODUCTCODE)

-- Combine the product category with the customer country CTE table
, CATEGORY_COUNTRY AS(
SELECT C.ORDERNUMBER, C.CUSTOMERNUMBER, C.COUNTRY,
		P.PRODUCTCODE, P.PRODUCTNAME, P.PRODUCTLINE
FROM CUST_COUNTRY AS C
JOIN PRODUCT_CATEGORY AS P
ON C.ORDERNUMBER = P.ORDERNUMBER)

-- Create rank based on most ordered product
, RANK_PRODUCT AS(
SELECT COUNTRY, 
		PRODUCTCODE, PRODUCTNAME, PRODUCTLINE,
        COUNT(DISTINCT(ORDERNUMBER)) AS TOTAL_ORDER,
        ROW_NUMBER() OVER(PARTITION BY COUNTRY ORDER BY COUNT(DISTINCT ORDERNUMBER) DESC) as PRODUCT_RANK
FROM CATEGORY_COUNTRY
GROUP BY COUNTRY, PRODUCTCODE
ORDER BY COUNTRY, PRODUCT_RANK)

SELECT * FROM RANK_PRODUCT
WHERE PRODUCT_RANK <= 5;

#####################################################################################################
#7
-- The store owner wants to know the average time it takes for customers to place a repeat order.
-- Calculate diffdate with the previous order for each customer
WITH DIFF_DATE AS(
SELECT O.CUSTOMERNUMBER, O.ORDERDATE,
		C.CUSTOMERNAME,
		DATEDIFF(O.ORDERDATE, LAG(O.ORDERDATE) OVER(PARTITION BY O.CUSTOMERNUMBER ORDER BY O.ORDERDATE)) AS DIFFERENCE_DATE
FROM ORDERS AS O
JOIN CUSTOMERS AS C
ON O.CUSTOMERNUMBER = C.CUSTOMERNUMBER
ORDER BY CUSTOMERNUMBER, ORDERDATE)

-- Calculate the average diffdate
SELECT DISTINCT(CUSTOMERNUMBER),
		CUSTOMERNAME,
        ROUND(AVG(DIFFERENCE_DATE) OVER(PARTITION BY CUSTOMERNUMBER),2) AS AVG_REPEAT_ORDER
FROM DIFF_DATE
WHERE DIFFERENCE_DATE IS NOT NULL
ORDER BY AVG_REPEAT_ORDER;

#####################################################################################################
#8
/*
The store owner wants to see the dates and transaction amounts of the payments 
made by customers when they placed their first orders.*/

-- Calculate the first payment
WITH FIRST_PAYMENT_DATE AS(
SELECT DISTINCT(CUSTOMERNUMBER), 
		MIN(PAYMENTDATE) OVER(PARTITION BY CUSTOMERNUMBER) AS FIRST_PAYMENT
FROM PAYMENTS)

SELECT DISTINCT F.CUSTOMERNUMBER, 
		F.FIRST_PAYMENT,
		P.AMOUNT
FROM FIRST_PAYMENT_DATE AS F
JOIN PAYMENTS AS P
ON F.CUSTOMERNUMBER = P.CUSTOMERNUMBER
AND F.FIRST_PAYMENT = P.PAYMENTDATE;
