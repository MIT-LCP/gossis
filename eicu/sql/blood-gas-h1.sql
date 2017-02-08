-- this query gets the lowest pao2/fio2 ratio

DROP TABLE IF EXISTS gosiss_bg_h1 CASCADE;
CREATE TABLE gosiss_bg_h1 as
with vw1 as
(
  select
      patientunitstayid
    , labresultoffset
    , min(case when labname = 'paO2' then labresult else null end) as PaO2_min
    , max(case when labname = 'paO2' then labresult else null end) as PaO2_max
    , min(case when labname = 'paCO2' then labresult else null end) as PaCO2_min
    , max(case when labname = 'paCO2' then labresult else null end) as PaCO2_max
    , min(case when labname = 'pH' then labresult else null end) as pH_min
    , max(case when labname = 'pH' then labresult else null end) as pH_max
    , max(case when labname = 'paO2' then labresult else null end) as PaO2
    , max(case when labname = 'FiO2' then labresult else null end) as FiO2
  from lab
  where labname in
  (
    'paO2'
  , 'paCO2'
  , 'FiO2'
  , 'pH'
  )
  and labresultoffset >= (-24*60) and labresultoffset <= (1*60)
  group by patientunitstayid, labresultoffset
)
select
    patientunitstayid
  -- patients should breathe at least 20% oxygen since that's how the atmosphere works
  , min(case when FiO2 < 20 then null when coalesce(FiO2, PaO2) is null then null else PaO2/FiO2*100 end) as PaO2FiO2Ratio_min
  , min(PaO2_min) as PaO2_min
  , max(PaO2_max) as PaO2_max
  , min(PaCO2_min) as PaCO2_min
  , max(PaCO2_max) as PaCO2_max
  , min(pH_min) as pH_min
  , max(pH_max) as pH_max
from vw1
group by patientunitstayid;
