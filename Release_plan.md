
***RELEASE PLAN*** -- HeidiSQL recommended
 
  1. Make sure both table1 and table2 has a decent number of lines ( ~ 17 milions rows is maximum tested for each table). 
  2. Run querries found in Table+Proc.sql, all from a single run if it is possible. For individual create copy the drop/create statements and add a 'DELIMITER //' above all create code (on line 1). </br>
        ```DO NOT FORGET TO RUN THE QUERRIES ON your database.``` 
  3. Search for the existence of each Item created in step 2: 'event_log' in db database , and all stored procedures in mysql database --> 'proc' table -- > be sure that you find all 3 having on the first column(db) value 'db'. Stored procedure names: ```table2table1_safe_net``` ```schedule_delete_table1``` ```schedule_delete_table2``` 
  4. Run query found in Clean-up event.sql. </br>
        ```DO NOT FORGET TO RUN THE QUERRIES ON your database.```
  5. Search for the event in 'event' table of the mysql database and be sure the first column(db) has the value 'db'.
  6. Refresh the db database. Observe the presence of an event interface. 
         - Enter `Timing` tab and put the event every one day at the desired interval. 
         - Enter `Settings` page and make sure the 'Drop event after expiration' checkbox IS NOT checked. 
         
