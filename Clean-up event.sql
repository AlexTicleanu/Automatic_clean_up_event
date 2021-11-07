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

CALL backup_tables_tb1_tb2();

#INSERT IN ABOVE TABLE
INSERT INTO event_log(`event_name`,`state`,`count_table1`,`count_table2`,`start/end`)
VALUES ('automatic_clean_up','start',(SELECT COUNT(id) from table1),(SELECT COUNT(id) from table2),(SELECT NOW()));
#SET THE REFERENCE VARIABLE
SET @ref=(SELECT MAX(table1.id)+1 FROM table1 WHERE date(table1.created) <= date(DATE_SUB(NOW(),INTERVAL 35 DAY)));

#DELETE table2_data FOR table1_data
CALL schedule_delete_table2(@ref);

#DELETE table1_data
CALL schedule_delete_table1(@ref);
CALL table2table1_safe_net();
SET foreign_key_checks = 1;
END;
//
DELIMITER ;
