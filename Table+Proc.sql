
DELIMITER //

#CREATE A TABLE FOR THE EVENT TO LOG
CREATE TABLE IF NOT EXISTS event_log(
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`event_name` VARCHAR(128) NOT NULL,
	`state` ENUM('start','middle','stop','error') NOT NULL,
	`table1_count` int(11) DEFAULT NULL,
	`table2_count` int(11) DEFAULT NULL,
	`start/end` TIMESTAMP NULL DEFAULT NULL,
	PRIMARY KEY (`id`)
);
//
DELIMITER ; 


DELIMITER //
create procedure table2table1_safe_net()
BEGIN

    IF (SELECT id from table1 LIMIT 1) IS NULL

    THEN

            INSERT INTO event_log (`event_name`,`state`)

        VALUES ('ERROR:EVENT DELETED ALL table1','error');

    END IF;

END
//
DELIMITER ;


DELIMITER //
create procedure schedule_delete_table2(IN REF int)
BEGIN

SET @dt = (SELECT COUNT(table2.id) FROM table2 

        INNER JOIN table1  on table2.table1_data_relation_column = table1.id

        WHERE date(table1.created) <= date(DATE_SUB(NOW(),INTERVAL 35 DAY))

        AND table1.status = 'deleted');

SET @INO = 0;

    WHILE @dt - @INO > 0

            DO

            DELETE table2 FROM table2 

            JOIN

            (SELECT table1.id

            FROM table1 table1

            INNER JOIN table2  on table1.id = table2.`table1_data_relation_column`

            WHERE table1.id <= REF

            AND table1.status = 'deleted'

            LIMIT 10000)

            sel ON table2.table1_data_relation_column = sel.id;

            SET @INO = @INO + 10000;



    END WHILE;



    INSERT INTO event_log(`event_name`,`state`,`table1_count`,`table2_count`,`start/end`)

    VALUES ('clean_up','middle',NULL,(SELECT COUNT(id) from table2),(SELECT NOW()));

END
//
DELIMITER ;



DELIMITER //
create procedure schedule_delete_table1(IN REF int)
BEGIN

SET @ct = (select MIN(id) from table1 where `status` = 'deleted');

    WHILE (@ct+1) < REF

        DO

        DELETE FROM table1

        WHERE

        status = 'deleted'

        AND id < REF

        ORDER BY id ASC

        LIMIT 10000;

        SET @ct = (select MIN(id) from table1 where `status` = 'deleted');

    END WHILE;

    INSERT INTO event_log(`event_name`,`state`,`table1_count`,`table2_count`,`start/end`)

    values ('clean_up','stop',(SELECT COUNT(id) from table1),(SELECT COUNT(id) from table2),(SELECT NOW()));

END
//
DELIMITER ;

DELIMITER //
create procedure backup_tables_tb1_tb2()
BEGIN

DROP TABLE IF EXISTS table1_copy ;
CREATE TABLE IF NOT EXISTS table1_copy LIKE table1 ;
INSERT INTO table1_copy SELECT * FROM `table1`;
DROP TABLE IF EXISTS table2_copy;
CREATE TABLE IF NOT EXISTS table2_copy LIKE table2;
INSERT INTO table2_copy  SELECT * FROM `table2`;

END //
DELIMITER ;

