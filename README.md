# Automatic_supply_clean_up_event

**Automatic Supply Clean-up event** is an MYSQL Scheduled Event that delete forecast order decisions older than 5 days and product performance corresponding to them using stored procedures created to delete batches of 10000 rows. 

All parts of the Scheduled Event are presented below in the same order as created in the Create Querry. 

**EVENT_LOG TABLE**
For a better tracking we use a new table (event_log) in which every run will have 3 rows containing:
    - an autoincrement id
    - event name
    - status(start- moment and counts for the exact moment when event starts; middle- moment and counts for the event after deleting product performance; stop - moment and counts for the exact moment when event ends )
    - forecast order id count 
    - automatic supply decisions product performance 
    - a timestamp for each case 

#Create Query for event_log table
`CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL, 
	`count_p_performance` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);`

 
 
 ***Stored Procedure used***
Stored procedure is a declarative statement stored in MYSQL database. 
When creating a stored procedure the create code should pe executed on the specific database the stored procedure is used, in our case emag_scm_dante. 
Stored procedure can be find in mysql database 'proc' table and called on demand using statement `call _name of the procedure_(_parameters_);`

**Decisions Product Performance Stored Procedure**
`DELIMITER //
CREATE PROCEDURE schedule_delete_dpp(IN REF INT)
BEGIN

SET @dt = (SELECT COUNT(dpp.id) FROM automatic_supply_decisions_product_performance dpp
		INNER JOIN forecast_order_decisions fod on dpp.forecast_order_decision_id = fod.id
		WHERE date(fod.created) <= curdate()-5
		AND fod.status = 'deleted' 
    	ORDER BY fod.id);

	WHILE @dt != 0
			DO 
			DELETE dpp FROM automatic_supply_decisions_product_performance dpp
			JOIN 
    		(SELECT fod.id
    		FROM forecast_order_decisions fod
    		INNER JOIN automatic_supply_decisions_product_performance dpp on fod.id = dpp.`forecast_order_decision_id`
    		WHERE fod.id <= REF
    		AND fod.status = 'deleted' 
    		ORDER BY fod.id
			LIMIT 10000)
			sel ON dpp.forecast_order_decision_id = sel.id;
			SET @dt = (SELECT COUNT(dpp.id) FROM automatic_supply_decisions_product_performance dpp
				INNER JOIN forecast_order_decisions fod on dpp.forecast_order_decision_id = fod.id
				WHERE date(fod.created) <= curdate()-5
				AND fod.status = 'deleted' 
    			ORDER BY fod.id);
	END WHILE;
	
	INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
	VALUES ('automatic_clean_up','middle',NULL,(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));
END//`




**Forecast Order Decisions Stored Procedure**

`CREATE PROCEDURE schedule_delete_fod(IN REF INT)
BEGIN 

SET @ct = (select MIN(id) from forecast_order_decisions); 
	WHILE @ct != REF   
		DO 
		DELETE FROM forecast_order_decisions
		WHERE 
		status = 'deleted'
		AND id <= REF
		ORDER BY id ASC 
		LIMIT 10000;
		SET @ct = (select MIN(id) from forecast_order_decisions);
	END WHILE;
	INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`) 
	values ('automatic_clean_up','stop',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));
END//`

    In this case the stored procedure is created with an INT parameter called REF. After the `Begin` keyword , a variable called `@ct` is set having the minimum forecast order decision id stored in it. 
    Deleting in batches inside a stored procedure is possible using a loop, in our case a while loop ,having the variable presented above `@ct` and the parameter `REF` with a comparison operator between them as a condition. 
    Due to performance issues a limit `LIMIT 10000` is required on the querry since after every loop the changes are commited on the database. 
    
    After condition in loop is not satisfied anymore, an insert into log table will be triggered having the forecast order decisions count, the product performance count and the timestamp of the moment when all event ends. 
    
 
    
    



