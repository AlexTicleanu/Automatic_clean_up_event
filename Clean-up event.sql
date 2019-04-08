DELIMITER //

#CREATE A TABLE FOR THE EVENT TO LOG
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL, 
	`count_p_performance` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);

#CREATE PROCEDURE FOD
CREATE PROCEDURE schedule_delete_fod(IN REF INT)
BEGIN 

SET @ct = (select MIN(id) from forecast_order_decisions); 
	WHILE (@ct+1) < REF   
		DO 
		DELETE FROM forecast_order_decisions
		WHERE 
		status = 'deleted'
		AND id < REF
		ORDER BY id ASC 
		LIMIT 10000;
		SET @ct = (select MIN(id) from forecast_order_decisions);
	END WHILE;
	INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`) 
	values ('automatic_clean_up','stop',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));
END// 

#CREATE PROCEDURE DPP


DELIMITER //
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




#CREATE THE EVENT
CREATE EVENT automatic_clean_up
    ON SCHEDULE 
	EVERY 1 DAY
   ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Clears out table.'
	DO BEGIN

SET foreign_key_checks = 0;


#INSERT IN ABOVE TABLE
INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
VALUES ('automatic_clean_up','start',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));

#SET THE REFERENCE VARIABLE
SET @ref=(SELECT MAX(fod.id)+1 FROM forecast_order_decisions fod WHERE date(fod.created) <= date(CURDATE()-5));

 
#DELETE PRODUCT PERFORMANCE FOR DECISIONS

CALL schedule_delete_dpp(@ref);

#DELETE DECISIONS
						 
CALL schedule_delete_fod(@ref);

      
SET foreign_key_checks = 1;
END; 
//
DELIMITER ;
