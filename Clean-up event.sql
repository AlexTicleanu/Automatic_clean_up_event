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
INSERT INTO forecast_order_decisions_copy SELECT * FROM `forecast_order_decisions`;

DROP TABLE IF EXISTS automatic_supply_decisions_product_performance_copy; 
CREATE TABLE IF NOT EXISTS automatic_supply_decisions_product_performance_copy LIKE automatic_supply_decisions_product_performance;
INSERT INTO automatic_supply_decisions_product_performance_copy  SELECT * FROM `automatic_supply_decisions_product_performance`;


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
