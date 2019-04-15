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

CREATE TABLE `emag_scm_dante`.`forecast_order_decisions_copy` (
	`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'The primary key',
	`forecast_rule_id` INT(11) NULL DEFAULT NULL,
	`product_id` INT(11) UNSIGNED NOT NULL COMMENT 'The product id, primary key',
	`daily_average` DECIMAL(10,4) UNSIGNED NULL DEFAULT NULL COMMENT 'Daily average received from BI',
	`last_acquisition_price` DECIMAL(10,2) UNSIGNED NULL DEFAULT NULL COMMENT 'Last acquisition price from the last NIR in SCM',
	`stock` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'The stock for this product, taken from SAP',
	`stock_target` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'Stock target that is defined in Forecast Rule',
	`stock_min` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'The minimum quantity of the product under which the supplying is triggered',
	`stock_max` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'The maximum quantity above which the supplying must not overcome',
	`pm_ordered_quantity` SMALLINT(11) UNSIGNED NULL DEFAULT NULL COMMENT 'Existing quantity in EIS, for this product, ordered by PM',
	`unconfirmed_quantity` SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Unconfirmed and unexpired quantity',
	`reserved_quantity` SMALLINT(11) UNSIGNED NULL DEFAULT NULL COMMENT 'Reserved quantity in EIS',
	`resulted_quantity` SMALLINT(11) NULL DEFAULT NULL COMMENT 'The quantity needed for ordering to the supplier',
	`initial_resulted_quantity` SMALLINT(11) NULL DEFAULT NULL COMMENT 'The initial quantity resulted after generating the proposal',
	`supplier_id` INT(11) UNSIGNED NULL DEFAULT NULL COMMENT 'The supplier that gets the order',
	`price` DECIMAL(11,2) NULL DEFAULT NULL COMMENT 'Offer price in aplication currency',
	`price_in_supplier_currency` DECIMAL(11,2) NULL DEFAULT NULL COMMENT 'Offer price in supplier currency',
	`currency_id` INT(11) UNSIGNED NULL DEFAULT NULL,
	`supplier_order_line_id` INT(11) UNSIGNED NULL DEFAULT NULL COMMENT 'The line in the invoice of the supplie/* large SQL query (3.1 KiB), snipped at 2,000 characters' */
INSERT INTO `emag_scm_dante`.`forecast_order_decisions_copy` (`id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified`) SELECT `id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified` FROM `forecast_order_decisions`;


CREATE TABLE `emag_scm_dante`.`automatic_supply_proposed_products_copy` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`product_id` INT(10) UNSIGNED NULL DEFAULT NULL,
	`forecast_rule_id` INT(10) UNSIGNED NULL DEFAULT NULL,
	`supplier_id` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'READONLY - Sync from SCM.Nom',
	`warehouse_id` INT(10) UNSIGNED NULL DEFAULT NULL,
	`day` DATE NOT NULL,
	`best_supplier_offer_processed` TINYINT(1) NOT NULL DEFAULT '0',
	`unreceived_quantity_processed` TINYINT(1) NOT NULL DEFAULT '0',
	`dwh_processed` TINYINT(1) NOT NULL DEFAULT '0',
	`stock_info_processed` TINYINT(1) NOT NULL DEFAULT '0',
	`last_acquisition_price_processed` TINYINT(1) NULL DEFAULT '0',
	`decision_processed` TINYINT(1) NOT NULL DEFAULT '0',
	`created` DATETIME NULL DEFAULT NULL,
	`modified` DATETIME NULL DEFAULT NULL,
	PRIMARY KEY (`id`),
	UNIQUE INDEX `uq_product_day_warehouse` (`product_id`, `day`, `warehouse_id`),
	INDEX `IDX_63621BDE2ADD6D8C` (`supplier_id`),
	INDEX `IDX_63621BDE5080ECDE` (`warehouse_id`),
	INDEX `IDX_63621BDE938351EA` (`forecast_rule_id`),
	INDEX `ix_product` (`product_id`),
	INDEX `IDX_processed` (`best_supplier_offer_processed`, `unreceived_quantity_processed`, `dwh_processed`, `stock_info_processed`, `last_acquisition_price_processed`, `decision_processed`),
	FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`),
	FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
	FOREIGN KEY (`forecast_rule_id`) REFERENCES `forecast_rules` (`id`)
)
 COLLATE 'utf8_unicode_ci' ENGINE=InnoDB ROW_FORMAT=Dynamic AUTO_INCREMENT=2875575;
INSERT INTO `emag_scm_dante`.`automatic_supply_proposed_products_copy` (`id`, `product_id`, `forecast_rule_id`, `supplier_id`, `warehouse_id`, `day`, `best_supplier_offer_processed`, `unreceived_quantity_processed`, `dwh_processed`, `stock_info_processed`, `last_acquisition_price_processed`, `decision_processed`, `created`, `modified`) SELECT `id`, `product_id`, `forecast_rule_id`, `supplier_id`, `warehouse_id`, `day`, `best_supplier_offer_processed`, `unreceived_quantity_processed`, `dwh_processed`, `stock_info_processed`, `last_acquisition_price_processed`, `decision_processed`, `created`, `modified` FROM `automatic_supply_proposed_products`;



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

IF (SELECT COUNT(id) from automatic_supply_decisions_product_performance) > 0
		 THEN DROP TABLE automatic_supply_proposed_products_copy; 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL DPP')
END IF; 

IF (SELECT COUNT(id) from forecast_order_decisions) > 0
		 THEN DROP TABLE forecast_order_decisions_copy; 
	ELSE
		INSERT INTO event_log (`event_name`) 
		VALUES ('ERROR:EVENT DELETED ALL FOD')
END IF; 
      
SET foreign_key_checks = 1;
END; 
//
DELIMITER ;
