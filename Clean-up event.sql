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
INSERT INTO forecast_order_decisions_copy (`id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified`) SELECT `id`, `forecast_rule_id`, `product_id`, `daily_average`, `last_acquisition_price`, `stock`, `stock_target`, `stock_min`, `stock_max`, `pm_ordered_quantity`, `unconfirmed_quantity`, `reserved_quantity`, `resulted_quantity`, `initial_resulted_quantity`, `supplier_id`, `price`, `price_in_supplier_currency`, `currency_id`, `supplier_order_line_id`, `message`, `error_id`, `status`, `reject_reason_id`, `user_id`, `stock_target_med_resulted_qty`, `created`, `modified` FROM `forecast_order_decisions`;

DROP TABLE IF EXISTS automatic_supply_decisions_product_performance_copy; 
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

CALL dppfod_safe_net();

SET foreign_key_checks = 1;

END; 
//
DELIMITER ;
