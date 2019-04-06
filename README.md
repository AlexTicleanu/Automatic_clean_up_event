# Automatic_supply_clean_up_event

**Automatic Supply Clean-up event** is an MYSQL Scheduled Event that delete forecast order decisions older than 5 days and product performance corresponding to them using stored procedures created to delete batches of 10000 rows. 

All parts of the Scheduled Event are presented below in the same order as created in the Create Querry. 

**EVENT_LOG TABLE**
For a better tracking we use a new table (event_log) in which every run will have 3 rows containing:
    - an autoincrement id
    - event name
    - status(start- moment and counts for the exact moment when event starts; middle- moment and counts for the event after deleting product performance; stop - moment and counts for the exact moment when event ends )
    - forecast order id count 
    - automatic supply decisions product performance 
    - a timestamp for each case 
    
**Product Performance Stored Procedure**








