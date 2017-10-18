-- this query gets the lowest pao2/fio2 ratio

DROP TABLE IF EXISTS gossis_bg CASCADE;
CREATE TABLE gossis_bg as
-- remove duplicate labs if they exist at the same time
-- e.g. pao2 has ~6000 rows which are recorded at the same time with substantially different values (e.g. 40 vs. 300)
-- certain assumptions could be made to infer the correct one, but we remove them for simplicity

-- a count confirms there:
--    are 365 rows with distinct FiO2s grouping by patient/laboffset
--    are 18 rows with distinct FiO2s if labresultrevisedoffset is included in group
-- a lot of these can be filtered by removing bad FiO2 (e.g. value < 20)
-- bad FiO2 values are commonly oxygen flow in litres
with vw0 as
(
  select
      patientunitstayid
    , labname
    , labresultoffset
    , labresultrevisedoffset
  from lab
  where labname in
  (
    'paO2'
  , 'paCO2'
  , 'pH'
  , 'FiO2'
  )
  group by patientunitstayid, labname, labresultoffset, labresultrevisedoffset
  having count(distinct labresult)<=1
)
-- get the last lab to be revised
, vw1 as
(
  select
      lab.patientunitstayid
    , lab.labname
    , lab.labresultoffset
    , lab.labresultrevisedoffset
    , lab.labresult
    , ROW_NUMBER() OVER
        (
          PARTITION BY lab.patientunitstayid, lab.labname, lab.labresultoffset
          ORDER BY lab.labresultrevisedoffset DESC
        ) as rn
  from lab
  inner join vw0
    ON  lab.patientunitstayid = vw0.patientunitstayid
    AND lab.labname = vw0.labname
    AND lab.labresultoffset = vw0.labresultoffset
    AND lab.labresultrevisedoffset = vw0.labresultrevisedoffset
  WHERE
     (lab.labname = 'paO2' and lab.labresult >= 15 and lab.labresult <= 720)
  OR (lab.labname = 'paCO2' and lab.labresult >= 5 and lab.labresult <= 250)
  OR (lab.labname = 'pH' and lab.labresult >= 6.5 and lab.labresult <= 8.5)
  OR (lab.labname = 'FiO2' and lab.labresult >= 0.2 and lab.labresult <= 1.0)
  -- we will fix fio2 units later
  OR (lab.labname = 'FiO2' and lab.labresult >= 20 and lab.labresult <= 100)
)
select
    patientunitstayid
  , labresultoffset
  -- the aggregate (max()) only ever applies to 1 value due to the where clause
  , MAX(case
        when labname != 'FiO2' then null
        when labresult >= 20 then labresult/100.0
      else labresult end) as fio2
  , MAX(case when labname = 'paO2' then labresult else null end) as pao2
  , MAX(case when labname = 'paCO2' then labresult else null end) as paco2
  , MAX(case when labname = 'pH' then labresult else null end) as pH
from vw1
where rn = 1
group by patientunitstayid, labresultoffset
order by patientunitstayid, labresultoffset;
