DROP TABLE IF EXISTS gossis_bg_d1 CASCADE;
CREATE TABLE gossis_bg_d1 as
select
    bg.patientunitstayid
  , min(PaO2/fio2) as PaO2FiO2Ratio_min
  , max(PaO2/fio2) as PaO2FiO2Ratio_max
  , min(PaO2) as PaO2_min
  , max(PaO2) as PaO2_max
  , min(PaCO2) as PaCO2_min
  , max(PaCO2) as PaCO2_max
  , min(pH) as pH_min
  , max(pH) as pH_max
from gossis_bg bg
where labresultoffset >= (-1*60) and labresultoffset <= (24*60)
group by bg.patientunitstayid;
