-- this query gets the lowest pao2/fio2 ratio

DROP TABLE IF EXISTS gossis_bg_h1 CASCADE;
CREATE TABLE gossis_bg_h1 as
with vw1 as
(
  select
      patientunitstayid
    , labresultoffset
    , min(case when labname = 'paO2' then labresult else null end) as PaO2_min
    , max(case when labname = 'paO2' then labresult else null end) as PaO2_max
    , min(case when labname = 'paCO2' then labresult else null end) as PaCO2_min
    , max(case when labname = 'paCO2' then labresult else null end) as PaCO2_max
    , min(case when labname = 'pH' and labresult < 8 and labresult > 4 then labresult else null end) as pH_min
    , max(case when labname = 'pH' and labresult < 8 and labresult > 4 then labresult else null end) as pH_max
  from lab
  where labname in
  (
    'paO2'
  , 'paCO2'
  , 'pH'
  )
  and labresultoffset >= (-1*60) and labresultoffset <= (1*60)
  group by patientunitstayid, labresultoffset
)
-- try and isolate only the final fio2 value
-- a count confirms there:
--    are 365 rows with distinct FiO2s grouping by patient/laboffset
--    are 18 rows with distinct FiO2s if labresultrevisedoffset is included in group
-- a lot of these can be filtered by removing bad FiO2 (e.g. value < 20)
-- bad FiO2 values are commonly oxygen flow in litres
, vw2 as
(
  select
    patientunitstayid
    , labresultoffset
    , case when labresult > 20 then labresult/100.0
          else labresult end as FiO2
    -- use row number to get the *last* value after revision
    , ROW_NUMBER() over (PARTITION BY patientunitstayid ORDER BY labresultrevisedoffset DESC) as rn
  from lab
  where labname = 'FiO2'
  -- less than 20% oxygen is not physiological
  and labresult > 0.2
  -- some rules to exclude bad measurements
  and (labresult <= 1 or labresult > 20)
  and labresult <= 100
  and labresult is not null
  and labresultoffset >= (-1*60) and labresultoffset <= (1*60)
)
select
    vw1.patientunitstayid
  , min(
      case
      when FiO2 is null or coalesce(FiO2, PaO2_min) is null then null
      else PaO2_min/FiO2 end
    ) as PaO2FiO2Ratio_min
  , max(
      case
      when FiO2 is null or coalesce(FiO2, PaO2_max) is null then null
      else PaO2_max/FiO2 end
    ) as PaO2FiO2Ratio_max
  , min(PaO2_min) as PaO2_min
  , max(PaO2_max) as PaO2_max
  , min(PaCO2_min) as PaCO2_min
  , max(PaCO2_max) as PaCO2_max
  , min(pH_min) as pH_min
  , max(pH_max) as pH_max
from vw1
left join vw2
  on vw1.patientunitstayid = vw2.patientunitstayid
  and vw1.labresultoffset = vw2.labresultoffset
  and vw2.rn = 1
group by vw1.patientunitstayid;
