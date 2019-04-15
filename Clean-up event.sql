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
DROP PROCEDURE IF EXISTS schedule_delete_fod;
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

DROP PROCEDURE IF EXISTS dppfod_safe_net;
CREATE PROCEDURE dppfod_safe_net()
BEGIN
		IF (SELECT COUNT(id) from automatic_supply_decisions_product_performance) > 0
		 THEN DROP TABLE automatic_supply_decisions_product_performance_copy; 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL DPP');
	END IF; 

	IF (SELECT COUNT(id) from forecast_order_decisions) > 0
		 THEN DROP TABLE forecast_order_decisions_copy; 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL FOD');
	END IF; 
       
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


CREATE TABLE IF NOT EXISTS forecast_order_decisions_copy LIKE forecast_order_decisions ;
INSERT INTO forecast_order_decisions_copy (`id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified`) SELECT `id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified` FROM `forecast_order_decisions`;


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

CALL CALL dppfod_safe_net();

SET foreign_key_checks = 1;
END; 
//
DELIMITER ;
