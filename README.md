# Automatic_supply_clean_up_event

**Automatic Supply Clean-up event** is an MYSQL Scheduled Event that deletes forecast order decisions older than 5 days and product performance corresponding to them using stored procedures created to delete batches of 10000 rows. 

All parts of the Scheduled Event are presented below in the same order as created in the Create Querry. 

**EVENT_LOG TABLE**

For a better tracking we use a new table (event_log) in which every run will have 3 rows containing:
    - an autoincrement id
    - event name
    - status(start- moment and counts for the exact moment when event starts; middle- moment and counts for the event after deleting product performance; stop - moment and counts for the exact moment when event ends; error - for the error raised by the safety measure)
    - forecast order id count 
    - automatic supply decisions product performance 
    - a timestamp for each case 

#Create Query for event_log table

```sql
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop','error') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL, 
	`count_p_performance` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);
//
```

 
 
 ***Stored Procedure used***
 
Stored procedure is a declarative statement stored in MYSQL database. 
When creating a stored procedure the 'create code' should be executed on the specific database the stored procedure is used, in our case emag_scm_dante. 
Stored procedure can be found in mysql database 'proc' table and called on demand using statement `call _name of the procedure_(_parameters_);`

**Decisions Product Performance Stored Procedure**

```sql
DROP PROCEDURE IF EXISTS schedule_delete_dpp;
CREATE PROCEDURE schedule_delete_dpp(IN REF INT)
BEGIN

SET @dt = (SELECT COUNT(dpp.id) FROM automatic_supply_decisions_product_performance dpp
		INNER JOIN forecast_order_decisions fod on dpp.forecast_order_decision_id = fod.id
		WHERE date(fod.created) <= date(curdate()-5)
		AND fod.status = 'deleted');
SET @INO = 0; 

	WHILE @dt - @INO > 0 
			DO 
			DELETE dpp FROM automatic_supply_decisions_product_performance dpp
			JOIN 
    		(SELECT fod.id
    		FROM forecast_order_decisions fod
    		INNER JOIN automatic_supply_decisions_product_performance dpp on fod.id = dpp.`forecast_order_decision_id`
    		WHERE fod.id <= REF
    		AND fod.status = 'deleted'
			LIMIT 10000)
			sel ON dpp.forecast_order_decision_id = sel.id;
			SET @INO = @INO + 10000;
			
	END WHILE;
	
	INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
	VALUES ('automatic_clean_up','middle',NULL,(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));

END
//
```

In this case the stored procedure is created with an INT parameter called `REF`. After the `Begin` keyword , a variable called `@dt` is set having the count of decisions product performance with a correspondent in forecast order decision that satisfy the conditions: status deleted and created date smaller than 5 days ago. 

Deleting in batches inside a stored procedure is possible using a loop, in our case a while loop ,having the difference variables presented above `@dt - @INO` not equal to 0 (in that moment all decision product performances are deleted and the while must end). 

The main query inside the while loop is deleting all the product performance with an correspondent in forecast order decision that satisfy the conditions: forecast order decision id must be smaller than the parameter `REF` and the forecast order status must be in status deleted. 

After a run is completed , variable @INO is getting set again by the initial value + the limit of the query for the loop to end where there is no more lines to delete. 
Due to performance issues a limit `LIMIT 10000` is required on the querry since after every loop the changes are commited on the database. 

When the process is getting out of the loop, an insert into log table will be triggered having  the product performance count and the timestamp of the moment when this procedure ends.  



**Forecast Order Decisions Stored Procedure**

```sql
DROP PROCEDURE IF EXISTS schedule_delete_fod;
CREATE PROCEDURE schedule_delete_fod(IN REF INT)
BEGIN 

SET @ct = (select MIN(id) from forecast_order_decisions where `status` = 'deleted'); 
	WHILE (@ct+1) < REF   
		DO 
		DELETE FROM forecast_order_decisions
		WHERE 
		status = 'deleted'
		AND id < REF
		ORDER BY id ASC 
		LIMIT 10000;
		SET @ct = (select MIN(id) from forecast_order_decisions where `status` = 'deleted');
	END WHILE;
	INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`) 
	values ('automatic_clean_up','stop',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));
END//
```

In this case the stored procedure is created with an INT parameter called REF. After the `Begin` keyword , a variable called `@ct` is set having the minimum forecast order decision id stored in it. 

Deleting in batches inside a stored procedure is possible using a loop, in our case a while loop ,having the variable presented above `@ct` (+1 due to the fact that `REF` is maximum id satisfying the conditions +1) and the parameter `REF` with a comparison operator between them as a condition.  
    
After condition in loop is not satisfied anymore, an insert into log table will be triggered having the forecast order decisions count, the product performance count and the timestamp of the moment when the event ends. 
    
    
 **Delete safety measure**

```sql
DROP PROCEDURE IF EXISTS dppfod_safe_net;
CREATE PROCEDURE dppfod_safe_net()
BEGIN
	IF (SELECT IF (EXISTS (SELECT id from automatic_supply_decisions_product_performance LIMIT 1), 1 , 0) = 1 )
		 THEN 
		 	INSERT INTO event_log (`event_name`,`state`) 
			VALUES ('process successfully done','successful'); 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL DPP','error');
	END IF; 

	IF (SELECT IF (EXISTS (SELECT id from forecast_order_decisions LIMIT 1), 1 , 0) > 0)
		 THEN 
		 	INSERT INTO event_log (`event_name`,`state`) 
			VALUES ('process successfully done','successful'); 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL FOD','error');
	END IF; 
       
END//    
```    
 The dppfod_safe_net procedure is used to insert a line with a specific message in 'event_log' table which specifies if one of the table remain empty after the event is occurring. 
 
 **Create event automatic_clean_up**
 
 ```sql
 
DELIMITER //

#CREATE THE EVENT
CREATE EVENT automatic_clean_up
    ON SCHEDULE 
	EVERY 1 DAY
   ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Clears out table.'
	DO BEGIN

SET foreign_key_checks = 0;

DROP TABLE IF EXISTS forecast_order_decisions_copy ; 
CREATE TABLE IF NOT EXISTS forecast_order_decisions_copy LIKE forecast_order_decisions ;
INSERT INTO forecast_order_decisions_copy (`id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified`) SELECT `id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified` FROM `forecast_order_decisions`;

DROP TABLE IF EXISTS automatic_supply_decisions_product_performance_copy; 
CREATE TABLE IF NOT EXISTS automatic_supply_decisions_product_performance_copy LIKE automatic_supply_decisions_product_performance;
INSERT INTO automatic_supply_decisions_product_performance_copy (`id`, `forecast_order_decision_id`, `country_id`, `product_performance_id`) SELECT `id`, `forecast_order_decision_id`, `country_id`, `product_performance_id` FROM `automatic_supply_decisions_product_performance`;


#INSERT IN ABOVE TABLE
INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
VALUES ('automatic_clean_up','start',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));

#SET THE REFERENCE VARIABLE
SET @ref=(SELECT MAX(fod.id)+1 FROM forecast_order_decisions fod WHERE date(fod.created) <= date(CURDATE()-5));

 
#DELETE PRODUCT PERFORMANCE FOR DECISIONS

CALL schedule_delete_dpp(@ref);

#DELETE DECISIONS
						 
CALL schedule_delete_fod(@ref);

CALL dppfod_safe_net();

SET foreign_key_checks = 1;

END; 
//
DELIMITER ;
 ```
 
 The Scheduled event is created by a small sequence of code containing the `Create event` statement followed by the desired name , in our case 'automatic_clean_up' , the `On Schedule` statement followed by the choosen schedule , the `ON COMPLETION` statement followed by `PRESERVE`/`DROP` according to requirements , `ENABLE` or `DIABLE` being the initial state in which the event will be created. 
Before writing the body of the event (one or multiple queries) a `DO BEGIN` statement is required ,ended by a `END` statement. 
Due to foreign key constraints the `SET foreign_key_checks = 0` statement is required before starting the main query inside the event and `SET foreign_key_checks = 1;` at the end of the event. 
 Before starting any of the procedures or inserting in the event_log table,for both forecast_order_decisions and automatic_supply_decisions_product_performance table it will be created a back-up and dropped the previous back-up from the day before.   
The insert in event_log will initiate the first count for forecast order decision and product performance for later observing.
 The next part in the event body is setting up the variable for later use in calling the stored procedures presented above. The `@ref` variable is set by the maximum id +1 from forecast order decisions that satisfies the requirement which the created date is smaller than 5 days ago.
 Now, both stored procedure can work with the same parameter so, calling the stored procedures having the `@ref` parameter will delete batch by batch all forecast order decisions and product performance correspondent from both tables. 
 Along with them the 'safety measure' procedure will be called and used in the specific case when one of the tables is empty.
 





