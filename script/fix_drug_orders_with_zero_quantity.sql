USE openmrs_mpc;

DROP TABLE IF EXISTS `temp_orders_list`;

CREATE TABLE `temp_orders_list` (
  `drug_order_id` int(11) NOT NULL DEFAULT '0',
  `drug` int(11) NOT NULL DEFAULT '0',
  `quantity` int NOT NULL DEFAULT '0',
  KEY (`drug_order_id`),
  KEY (`drug`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_orders_list (drug_order_id, drug, quantity)
SELECT do.order_id, do.drug_inventory_id, SUM(ob.value_numeric)
-- select do.*, ob.value_drug, ob.value_numeric, ob.order_id
    FROM drug_order do 
        INNER JOIN orders o ON o.order_id = do.order_id AND o.voided = 0
        INNER JOIN obs ob ON do.order_id = ob.order_id AND ob.value_drug = do.drug_inventory_id AND ob.voided = 0
    WHERE quantity IS NULL AND ob.value_numeric <> 0
GROUP BY ob.order_id, ob.value_drug;

update drug_order
set quantity = (select quantity from temp_orders_list where drug_order_id = order_id and drug = drug_inventory_id) 
where order_id in (select drug_order_id from temp_orders_list);

-- move value_text to value_datetime



-- inner join temp_orders_list tol on tol.drug_order_id = do.order_id and tol.drug = do.drug_inventory_id;