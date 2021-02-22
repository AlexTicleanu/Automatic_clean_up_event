
DELIMITER //

#CREATE A TABLE FOR THE EVENT TO LOG
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop','error') NOT NULL,
	`count_decisions` int(11) DEFAULT NULL,
	`count_p_performance` int(11) DEFAULT NULL,
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);
//
DELIMITER ; 


DELIMITER //
create procedure dppfod_safe_net()
BEGIN

    IF (SELECT id from forecast_order_decisions LIMIT 1) IS NULL

    THEN

            INSERT INTO event_log (`event_name`,`state`)

        VALUES ('ERROR:EVENT DELETED ALL FOD','error');

    END IF;

END
//
DELIMITER ;


DELIMITER //
create procedure schedule_delete_dpp(IN REF int)
BEGIN

SET @dt = (SELECT COUNT(dpp.id) FROM automatic_supply_decisions_product_performance dpp

        INNER JOIN forecast_order_decisions fod on dpp.forecast_order_decision_id = fod.id

        WHERE date(fod.created) <= date(DATE_SUB(NOW(),INTERVAL 35 DAY))

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
DELIMITER ;



DELIMITER //
create procedure schedule_delete_fod(IN REF int)
BEGIN

SET @ct = (select MIN(id) from forecast_order_decisions where `status` = 'deleted');

    WHILE (@ct+1) < REF

        DO

        DELETE FROM forecast_order_decisions

        WHERE

        status = 'deleted'

        AND id < REF

        ORDER BY id ASC

        LIMIT 10000;

        SET @ct = (select MIN(id) from forecast_order_decisions where `status` = 'deleted');

    END WHILE;

    INSERT INTO event_log(`event_name`,`state`,`count_decisions`,`count_p_performance`,`start/end`)

    values ('automatic_clean_up','stop',(SELECT COUNT(id) from forecast_order_decisions),(SELECT COUNT(id) from automatic_supply_decisions_product_performance),(SELECT NOW()));

END
//
DELIMITER ;

DELIMITER //
create procedure backup_tables_as(IN REF int)
BEGIN

DROP TABLE IF EXISTS forecast_order_decisions_copy ;
CREATE TABLE IF NOT EXISTS forecast_order_decisions_copy LIKE forecast_order_decisions ;
INSERT INTO forecast_order_decisions_copy SELECT * FROM `forecast_order_decisions`;
DROP TABLE IF EXISTS automatic_supply_decisions_product_performance_copy;
CREATE TABLE IF NOT EXISTS automatic_supply_decisions_product_performance_copy LIKE automatic_supply_decisions_product_performance;
INSERT INTO automatic_supply_decisions_product_performance_copy  SELECT * FROM `automatic_supply_decisions_product_performance`;

END //
DELIMITER ;

