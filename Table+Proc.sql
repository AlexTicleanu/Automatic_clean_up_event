
DELIMITER //

#CREATE A TABLE FOR THE EVENT TO LOG
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop','successful','error') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL, 
	`count_p_performance` int(11) DEFAULT NULL, 
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);



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
       
END
//
