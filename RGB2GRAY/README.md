open in Raw or Blame view


--axi_master        axi_slave                           axi_master          axi_slave   
------------|       |----------------------------------------------|       |-----------
--  tvalid--|--->---|--tvalid--->---|STD_FIFO_SGNL  |--->--tvalid--|--->---|--tvalid---    
--  tdata---|--->---|--tdata---->---|data_pipeline  |--->--tdata---|--->---|--tdata----
--  tstrb---|--->---|--tstrb---->---|STD_FIFO       |--->--tstrb---|--->---|--tstrb----
--  tlast---|--->---|--tlast---->---|STD_FIFO_SGNL  |--->--tlast---|--->---|--tlast----
--          |       |                                              |       |           
--  tready--|---<---|--tready---<---|clocked process|---<--tready--|---<---|--tready---
--          |       |                                              |       |           
--  tuser---|--->---|--tuser---->---|STD_FIFO       |--->--tuser---|--->---|--tuser----
------------|       |-----------------------------------   --------|       |-----------
