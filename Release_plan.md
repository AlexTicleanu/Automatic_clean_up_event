
***RELEASE PLAN***
 
  1. Make sure both forecast_order_decisions and automatic_supply_decisions_product_performance has a decent number of lines ( ~ 17 milions rows is maximum tested for each table). 
  2. Run querries found in Table+Proc.sql, all from a single run if it is possible. For individual create copy the drop/create statements and add a 'DELIMITER //' above all create code (on line 1). /br
        ```DO NOT FORGET TO RUN THE QUERRIES ON emag_scm_dante database.``` 
  3. Search for the existence of each Item created in step 2: 'event_log' in emag_scm_dante database , and all stored procedures in mysql database --> 'proc' table -- > be sure that you find all 3 having on the first column(db) value 'emag_scm_dante'. 
