# Related_tables_clean_up_event

**Related tables Clean-up event** is an MYSQL Scheduled Event that deletes data lines from a table older than 5 days and data corresponding to them from another table using stored procedures created to delete batches of 10000 rows. 

All parts of the Scheduled Event are presented below in the same order as created in the Create Querry. 

**EVENT_LOG TABLE**

For a better tracking we use a new table (event_log) in which every run will have 3 rows containing:
    - an autoincrement id
    - event name
    - status(start- moment and counts for the exact moment when event starts; middle- moment and counts for the event after deleting product performance; stop - moment and counts for the exact moment when event ends; error - for the error raised by the safety measure)
    - data_from_table1 count 
    - data_from_table2 count 
    - a timestamp for each case 

#Create Query for event_log table

```sql
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop','error') NOT NULL,
	`count_table1` int(11) DEFAULT NULL, 
	`count_table2` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);
//
```

 
 
 ***Stored Procedure used***
 
Stored procedure is a declarative statement stored in MYSQL database. 
When creating a stored procedure the 'create code' should be executed on the specific database the stored procedure is used, in our case your_db. 
Stored procedure can be found in mysql database 'proc' table and called on demand using statement `call _name of the procedure_(_parameters_);`

**Table2 Stored Procedure**

```sql
DROP PROCEDURE IF EXISTS schedule_delete_table2;
CREATE PROCEDURE schedule_delete_table2(IN REF INT)
BEGIN

SET @dt = (SELECT COUNT(table2.id) FROM table2 
		INNER JOIN table1 table1 on table2.table1_relation_column = table1.id
		WHERE date(table1.created) <= date(curdate()-5)
		AND table1.status = 'deleted');
SET @INO = 0; 

	WHILE @dt - @INO > 0 
			DO 
			DELETE table2 FROM table2 
			JOIN 
    		(SELECT table1.id
    		FROM table1
    		INNER JOIN table2  on table1.id = table2.`table1_relation_column`
    		WHERE table1.id <= REF
    		AND table1.status = 'deleted'
			LIMIT 10000)
			sel ON table2.table1_relation_column = sel.id;
			SET @INO = @INO + 10000;
			
	END WHILE;
	
	INSERT INTO event_log(`event_name`,`state`,`count_table1`,`count_table2`,`start/end`)
	VALUES ('clean_up','middle',NULL,(SELECT COUNT(id) from table2),(SELECT NOW()));

END
//
```

In this case the stored procedure is created with an INT parameter called `REF`. After the `Begin` keyword , a variable called `@dt` is set having the count of data from table2 with a correspondent in table1 that satisfy the conditions: status deleted and created date smaller than 5 days ago. 

Deleting in batches inside a stored procedure is possible using a loop, in our case a while loop ,having the difference variables presented above `@dt - @INO` not equal to 0 (in that moment all data from table2 are deleted and the while must end). 

The main query inside the while loop is deleting all the table2 data with an correspondent in table1 that satisfy the conditions: table1 id must be smaller than the parameter `REF` and the table1 data status must be in status deleted. 

After a run is completed , variable @INO is getting set again by the initial value + the limit of the query for the loop to end where there is no more lines to delete. 
Due to performance issues a limit `LIMIT 10000` is required on the querry since after every loop the changes are commited on the database. 

When the process is getting out of the loop, an insert into log table will be triggered having the table2 count and the timestamp of the moment when this procedure ends.  



**table1 Stored Procedure**

```sql
DROP PROCEDURE IF EXISTS schedule_delete_table1;
CREATE PROCEDURE schedule_delete_table1(IN REF INT)
BEGIN 

SET @ct = (select MIN(id) from table1 where `status` = 'deleted'); 
	WHILE (@ct+1) < REF   
		DO 
		DELETE FROM table1
		WHERE 
		status = 'deleted'
		AND id < REF
		ORDER BY id ASC 
		LIMIT 10000;
		SET @ct = (select MIN(id) from table1 where `status` = 'deleted');
	END WHILE;
	INSERT INTO event_log(`event_name`,`state`,`count_table1`,`count_table2``,`start/end`) 
	values ('clean_up','stop',(SELECT COUNT(id) from table1),(SELECT COUNT(id) from table2),(SELECT NOW()));
END//
```

In this case the stored procedure is created with an INT parameter called REF. After the `Begin` keyword , a variable called `@ct` is set having the minimum table1 id stored in it. 

Deleting in batches inside a stored procedure is possible using a loop, in our case a while loop ,having the variable presented above `@ct` (+1 due to the fact that `REF` is maximum id satisfying the conditions +1) and the parameter `REF` with a comparison operator between them as a condition.  
    
After condition in loop is not satisfied anymore, an insert into log table will be triggered having the table1 count, the table2 count and the timestamp of the moment when the event ends. 
    
    
 **Delete safety measure**

```sql
DROP PROCEDURE IF EXISTS table2table1_safe_net;
CREATE PROCEDURE table2table1_safe_net()
BEGIN
	IF (SELECT IF (EXISTS (SELECT id from table2 LIMIT 1), 1 , 0) = 1 )
		 THEN 
		 	INSERT INTO event_log (`event_name`,`state`) 
			VALUES ('process successfully done','successful'); 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL table2','error');
	END IF; 

	IF (SELECT IF (EXISTS (SELECT id from table1 LIMIT 1), 1 , 0) > 0)
		 THEN 
		 	INSERT INTO event_log (`event_name`,`state`) 
			VALUES ('process successfully done','successful'); 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL table1','error');
	END IF; 
       
END//    
```    
 The table2table1_safe_net procedure is used to insert a line with a specific message in 'event_log' table which specifies if one of the table remain empty after the event is occurring. 
 
 **Create event clean_up**
 
 ```sql
 
DELIMITER //

#CREATE THE EVENT
CREATE EVENT clean_up
    ON SCHEDULE 
	EVERY 1 DAY
   ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Clears out table for data deleted and older than 5 days.'
	DO BEGIN

SET foreign_key_checks = 0;

DROP TABLE IF EXISTS table1_copy ; 
CREATE TABLE IF NOT EXISTS table1_copy LIKE table1 ;
INSERT INTO table1_copy  SELECT * FROM `table1`;

DROP TABLE IF EXISTS table2_copy; 
CREATE TABLE IF NOT EXISTS table2_copy LIKE table2;
INSERT INTO table2_copy SELECT * FROM `table2`;


#INSERT IN ABOVE TABLE
INSERT INTO event_log(`event_name`,`state`,`count_table1`,`count_table2`,`start/end`)
VALUES ('clean_up','start',(SELECT COUNT(id) from table1),(SELECT COUNT(id) from table2),(SELECT NOW()));

#SET THE REFERENCE VARIABLE
SET @ref=(SELECT MAX(table1.id)+1 FROM table1 table1 WHERE date(table1.created) <= date(CURDATE()-5));

 
#DELETE PRODUCT PERFORMANCE FOR DECISIONS

CALL schedule_delete_table2(@ref);

#DELETE DECISIONS
						 
CALL schedule_delete_table1(@ref);

CALL table2table1_safe_net();

SET foreign_key_checks = 1;

END; 
//
DELIMITER ;
 ```
 
 The Scheduled event is created by a small sequence of code containing the `Create event` statement followed by the desired name , in our case 'clean_up' , the `On Schedule` statement followed by the choosen schedule , the `ON COMPLETION` statement followed by `PRESERVE`/`DROP` according to requirements , `ENABLE` or `DIABLE` being the initial state in which the event will be created. 
Before writing the body of the event (one or multiple queries) a `DO BEGIN` statement is required ,ended by a `END` statement. 
Due to foreign key constraints the `SET foreign_key_checks = 0` statement is required before starting the main query inside the event and `SET foreign_key_checks = 1;` at the end of the event. 
 Before starting any of the procedures or inserting in the event_log table,for both table1 and table2 table it will be created a back-up and dropped the previous back-up from the day before.   
The insert in event_log will initiate the first count for table1 and table2 for later observing.
 The next part in the event body is setting up the variable for later use in calling the stored procedures presented above. The `@ref` variable is set by the maximum id +1 from table1 that satisfies the requirement which the created date is smaller than 5 days ago.
 Now, both stored procedure can work with the same parameter so, calling the stored procedures having the `@ref` parameter will delete batch by batch all table1 and table2 correspondent from both tables. 
 Along with them the 'safety measure' procedure will be called and used in the specific case when one of the tables is empty.
 





