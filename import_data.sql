create schema online_retails_sale;
use online_retails_sale;
drop table if exists sales ;
create table sales (
	invoice_no varchar(25),
    invoice_date date,
    invoice_time datetime,
    stock_code varchar(255),
    product_description varchar(1000),
    quantity int,
    unit_price decimal(20,4),
    total_sale decimal(20,4),
    customer_id varchar(25),
    country varchar(255)
);

LOAD DATA local INFILE '/home/mah/Code/online_retail_data/or.csv'
INTO TABLE sales
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS  -- Skip header if present
(
	@invoice_no,
    @invoice_date,
    @invoice_time,
    @stock_code,
    @product_description,
    @quantity,
    @unit_price,
    @total_sale,
    @customer_id,
    @country
)
SET
	invoice_no=@invoice_no,
    invoice_date=STR_TO_DATE(@invoice_date, '%d-%m-%Y'),
    invoice_time=concat(invoice_date, ' ', STR_TO_DATE(@invoice_time, '%h:%i:%s %p')),
    stock_code=@stock_code,
    product_description=@product_description,
    quantity=@quantity,
    unit_price=@unit_price,
    total_sale=@total_sale,
    customer_id=@customer_id,
    country=replace(@country, '\r', '')
;

-- do some data cleaning
UPDATE sales 
SET 
    customer_id = NULL
WHERE
    customer_id = '';

UPDATE sales 
SET 
    product_description = NULL
WHERE
    product_description = '';

drop table if exists invoices;
CREATE TABLE invoices AS SELECT customer_id,
    invoice_no,
    invoice_date,
    invoice_time,
    SUM(total_sale) AS c_total_sale,
    COUNT(*) AS c_stock_quantity,
    SUM(quantity) AS c_total_quantity,
    country,
    YEAR(invoice_date) AS c_year,
    MONTH(invoice_date) AS c_month 
FROM
    sales
GROUP BY invoice_no
ORDER BY invoice_date DESC;

commit;