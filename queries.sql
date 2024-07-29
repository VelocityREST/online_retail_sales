use online_retails_sale;

-- Creating couple reports and views
-- number and value of sales and cancelled orders, per year and month
drop view if exists v_orders_cancelled_orders;
CREATE VIEW v_orders_cancelled_orders AS
    SELECT 
        a.*, b.cancelled_orders_num, b.total_refunded
    FROM
        (SELECT 
            c_year,
                c_month,
                COUNT(invoice_no) AS orders_num,
                ROUND(SUM(c_total_sale), 2) AS total_sales
        FROM
            invoices
        WHERE
            invoice_no NOT LIKE 'C%'
        GROUP BY c_year , c_month) AS a
            LEFT JOIN
        (SELECT 
            c_year,
                c_month,
                COUNT(invoice_no) AS cancelled_orders_num,
                ROUND(SUM(c_total_sale), 2) AS total_refunded
        FROM
            invoices
        WHERE
            invoice_no LIKE 'C%'
        GROUP BY c_year , c_month) AS b ON a.c_year = b.c_year
            AND a.c_month = b.c_month;

SELECT * FROM v_orders_cancelled_orders;

-- sales per country and percentage of sales to total 
drop view if exists v_sales_per_country;
CREATE VIEW v_sales_per_country AS
    SELECT 
        country,
        COUNT(DISTINCT (invoice_no)) num_of_sales,
        SUM(total_sale) AS total_sales,
        ROUND((SUM(total_sale) / (SELECT 
                        SUM(total_sale)
                    FROM
                        sales) * 100),
                2) AS perc_sales
    FROM
        sales
    GROUP BY country
    ORDER BY total_sales DESC;

SELECT * FROM v_sales_per_country;

-- a list customers based on their value
drop view if exists v_customers_value;
CREATE VIEW v_customers_value AS
    SELECT 
        customer_id,
        COUNT(invoice_no) AS num_of_orders,
        SUM(c_total_sale) AS sum_orders_per_customer,
        country
    FROM
        invoices
    WHERE
        customer_id IS NOT NULL
    GROUP BY customer_id
    ORDER BY sum_orders_per_customer DESC;
    
SELECT * FROM v_customers_value;

-- Reversed orders report: Orders that got cancelled
drop view if exists v_reversed_orders;
CREATE VIEW v_reversed_orders AS
    SELECT 
        s.customer_id,
        s.invoice_no AS original_invoice_no,
        iq.return_invoice_no,
        s.invoice_date AS original_invoice_date,
        iq.return_invoice_date,
        s.c_total_sale AS original_total_sale,
        s.c_stock_quantity AS original_stock_quantity,
        iq.return_stock_quantity,
        s.c_total_quantity AS original_total_quantity,
        iq.return_total_quantity,
        s.country
    FROM
        invoices AS s
            LEFT JOIN
        (SELECT 
            invoice_no AS return_invoice_no,
                invoice_date AS return_invoice_date,
                customer_id AS return_customer_id,
                c_total_sale AS return_order_value,
                c_stock_quantity AS return_stock_quantity,
                c_total_quantity AS return_total_quantity
        FROM
            invoices
        WHERE
            invoice_no REGEXP '^(?![0-9])[A-Za-z][A-Za-z0-9]*'
                AND customer_id != ''
        ORDER BY return_order_value ASC) AS iq ON s.customer_id = iq.return_customer_id
            AND s.c_total_sale = ABS(return_order_value)
    WHERE
        (s.customer_id , s.c_total_sale) IN (SELECT 
                customer_id, ABS(c_total_sale) AS c_total_sale
            FROM
                invoices
            WHERE
                invoice_no REGEXP '^(?![0-9])[A-Za-z][A-Za-z0-9]*'
                    AND customer_id != '');
                    
SELECT * FROM v_reversed_orders;

-- stock that has no description order by most sales and quantity
drop view if exists v_no_description_stock;
CREATE VIEW v_no_description_stock AS
    SELECT 
        stock_code,
        SUM(total_sale) AS sales,
        SUM(quantity) AS quantity,
        product_description
    FROM
        sales
    WHERE
        product_description IS NULL
    GROUP BY stock_code
    ORDER BY sales , quantity DESC;

SELECT * FROM v_no_description_stock;


-- Creating a couple of useful procedures 
-- order details
drop procedure if exists order_details;
delimiter $$
create procedure p_order_details(in p_invoice_no int)
begin
	select * from sales
    where invoice_no = p_invoice_no;
end $$
delimiter ;

call p_order_details(536394);

-- Procedure to return orders per customer, with an option parameter for date
DROP PROCEDURE IF EXISTS customer_sales;
delimiter $$
create procedure customer_sales(in p_customer_id varchar(25), in p_invoice_date date)
begin
	if p_invoice_date is null then
		select * from sales
		where customer_id = p_customer_id
        order by invoice_date DESC;
	else
		select * from sales
		where customer_id = p_customer_id
        and invoice_date=p_invoice_date
        order by invoice_date DESC;
	end if;
end$$
delimiter ;

call customer_sales('17850', '2010-12-01');
call customer_sales('17850', null);

-- top 50 products per country
Drop procedure if exists p_top_50_products_per_country;
delimiter $$
create procedure p_top_50_products_per_country(in p_country varchar(255))
begin
	SELECT 
		stock_code,
		product_description,
		SUM(quantity) AS total_quantity_sold,
		unit_price,
		SUM(total_sale) AS total_product_sales,
		COUNT(invoice_no) AS num_of_orders,
		country
	FROM
		sales
	where country= p_country
	GROUP BY stock_code
	ORDER BY total_quantity_sold DESC
limit 50;
end $$
delimiter ;

call p_top_50_products_per_country('Netherlands');

-- create some useful triggers
-- create a trigger to stops the user from inserting a cancelled order with no negative quantity
delimiter $$
Create trigger cancelled_orders_check
before insert on sales
for each row
begin
	if new.invoice_no like 'C%' and new.quantity > 0 then
    signal sqlstate '45000'
    set message_text = "Cancelled orders can't have a positive quantity, please edit quantity and try again";
    end if;
end $$
delimiter ;
-- test the new trigger
insert into sales (invoice_no, quantity, customer_id)
values ('C536365', 10, 17850);

-- same trigger logic above but for updating
delimiter $$
create trigger t_cancelled_order_update
before update on sales
for each row
begin
	if new.invoice_no like 'C%' and new.quantity > 0 then
    signal sqlstate '45000'
    set message_text = "You can't have a positive quantity with cancelled order, please change that and try again";
    end if;
end $$
delimiter ;
-- test the new trigger
UPDATE sales 
SET 
    invoice_no = 'C536365'
WHERE
    invoice_no = 536365
        AND stock_code = '85123A';


    








--    

