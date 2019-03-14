DELIMITER GO

CREATE TABLE IF NOT EXISTS event_log(
	'id' int(11) NOT NULL AUTO_INCREMENT,
	'event_name' VARCHAR(128) NOT NULL,
	'count_decisions' int(11) DEFAULT NULL, 
	'count_p_performance' int(11) DEFAULT NULL, 
	'start/end' TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);


CREATE EVENT automatic_clean_up
    ON SCHEDULE 
	EVERY 1 DAY
   ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Clears out table each 10 seconds.'
	DO BEGIN

SET foreign_key_checks = 0;

INSERT INTO event_log(event_name,count_decisions,count_p_performance,start/end)
VALUES (automatic_clean_up,(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT CURDATE()));

SET @ref = (SELECT fod.id FROM emag_scm_dante.forecast_order_decisions fod WHERE fod.created  curdate()-3 ORDER BY fod.id DESC LIMIT 1);
 

DELETE dpp FROM emag_scm_dante.automatic_supply_decisions_product_performance dpp
JOIN (
    SELECT fod.id
    FROM forecast_order_decisions fod
    INNER JOIN automatic_supply_decisions_product_performance dpp on fod.id = dpp.`forecast_order_decision_id`
    WHERE fod.id  @ref
    AND fod.status = 'deleted' 
    ORDER BY fod.id
    LIMIT 100000
) sel ON dpp.forecast_order_decision_id = sel.id;


DELETE FROM forecast_order_decisions
WHERE 
status = 'deleted'
AND id  @ref
ORDER BY id ASC
LIMIT 100000;

INSERT INTO event_log(event_name,count_decisions,count_p_performance,start/end)
VALUES (automatic_clean_up,(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT CURDATE()));																		    
      
SET foreign_key_checks = 1;
END; 
GO  
