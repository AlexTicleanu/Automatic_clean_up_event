DELIMITER GO

#CREATE A TABLE FOR THE EVENT TO LOG

CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','stop') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL, 
	`count_p_performance` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);

#CREATE THE EVENT
CREATE EVENT automatic_clean_up
    ON SCHEDULE 
	EVERY 1 DAY
   ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Clears out table each 10 seconds.'
	DO BEGIN

SET foreign_key_checks = 0;


#INSERT IN ABOVE TABLE
SET @fod_before = (SELECT COUNT(id) from forecast_order_decisions);
SET @aspp_before = (SELECT COUNT(id) from automatic_supply_decisions_product_performance);

INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
VALUES ('automatic_clean_up','start',@fod_before,@aspp_before,(SELECT TIMESTAMP()));

#SET THE REFERENCE VARIABLE							       
SET @ref = (SELECT fod.id FROM forecast_order_decisions fod WHERE fod.created <= curdate()-3 ORDER BY fod.id DESC LIMIT 1);
 
#DELETE PRODUCT PERFORMANCE FOR DECISIONS
DELETE dpp FROM automatic_supply_decisions_product_performance dpp
JOIN (
    SELECT fod.id
    FROM forecast_order_decisions fod
    INNER JOIN automatic_supply_decisions_product_performance dpp on fod.id = dpp.`forecast_order_decision_id`
    WHERE fod.id <= @ref
    AND fod.status = 'deleted' 
    ORDER BY fod.id
) sel ON dpp.forecast_order_decision_id = sel.id;

#DELETE DECISIONS
DELETE FROM forecast_order_decisions
WHERE 
status = 'deleted'
AND id <= @ref
ORDER BY id ASC;


#INSERT INTRO event_log AGAIN FOR VALUES AFTER EVENT IS DONE
SET@fod_after = (SELECT COUNT(id) from forecast_order_decisions);
SET@aspp_after = (SELECT COUNT(id) from automatic_supply_decisions_product_performance);

INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)
VALUES ('automatic_clean_up','stop',@fod_after,@aspp_after,(SELECT TIMESTAMP()));																		    
      
SET foreign_key_checks = 1;
END; 
GO  
