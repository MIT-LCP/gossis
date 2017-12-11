DROP TABLE IF EXISTS gossis_lab CASCADE;
CREATE TABLE gossis_lab as
-- remove duplicate labs if they exist at the same time
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
    'albumin'
    , 'total bilirubin'
    , 'BUN'
    , 'calcium'
    , 'creatinine'
    , 'bedside glucose', 'glucose'
    , 'bicarbonate' -- HCO3
    -- TODO: what about 'Total CO2'
    , 'Hct'
    , 'Hgb'
    , 'PT - INR'
    , 'lactate'
    , 'platelets x 1000'
    , 'potassium'
    , 'sodium'
    , 'WBC x 1000'
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
  -- only valid lab values
  WHERE
       (lab.labname = 'albumin' and lab.labresult >= 0.5 and lab.labresult <= 6.5)
    OR (lab.labname = 'total bilirubin' and lab.labresult >= 0.2 and lab.labresult <= 70.175)
    OR (lab.labname = 'BUN' and lab.labresult >= 1 and lab.labresult <= 280)
    OR (lab.labname = 'calcium' and lab.labresult > 0 and lab.labresult <= 9999)
    OR (lab.labname = 'creatinine' and lab.labresult >= 0.1 and lab.labresult <= 28.28)
    OR (lab.labname in ('bedside glucose', 'glucose') and lab.labresult >= 1.8018 and lab.labresult <= 1621.6)
    OR (lab.labname = 'bicarbonate' and lab.labresult >= 0 and lab.labresult <= 9999)
    -- will convert hct unit to fraction later
    OR (lab.labname = 'Hct' and lab.labresult >= 5 and lab.labresult <= 75)
    OR (lab.labname = 'Hgb' and lab.labresult >  0 and lab.labresult <= 9999)
    OR (lab.labname = 'PT - INR' and lab.labresult >  0 and lab.labresult <= 9999)
    OR (lab.labname = 'lactate' and lab.labresult >  0 and lab.labresult <= 9999)
    OR (lab.labname = 'platelets x 1000' and lab.labresult >  0 and lab.labresult <= 9999)
    OR (lab.labname = 'potassium' and lab.labresult >= 0.05 and lab.labresult <= 12)
    OR (lab.labname = 'sodium' and lab.labresult >= 90 and lab.labresult <= 215)
    OR (lab.labname = 'WBC x 1000' and lab.labresult >= 0 and lab.labresult <= 300)
)
select
    patientunitstayid
  , labresultoffset
  -- the aggregate (max()) only ever applies to 1 value due to the where clause
  , MAX(case when labname = 'albumin' then labresult else null end) as albumin
  , MAX(case when labname = 'total bilirubin' then labresult else null end) as bilirubin
  , MAX(case when labname = 'BUN' then labresult else null end) as BUN
  , MAX(case when labname = 'calcium' then labresult else null end) as calcium
  , MAX(case when labname = 'creatinine' then labresult else null end) as creatinine
  , MAX(case when labname in ('bedside glucose', 'glucose') then labresult else null end) as glucose
  , MAX(case when labname = 'bicarbonate' then labresult else null end) as hco3 -- bicarbonate
  , MAX(case when labname = 'Hct' then labresult else null end) as hematocrit
  , MAX(case when labname = 'Hgb' then labresult else null end) as hemoglobin
  , MAX(case when labname = 'PT - INR' then labresult else null end) as INR
  , MAX(case when labname = 'lactate' then labresult else null end) as lactate
  , MAX(case when labname = 'platelets x 1000' then labresult else null end) as platelets
  , MAX(case when labname = 'potassium' then labresult else null end) as potassium
  , MAX(case when labname = 'sodium' then labresult else null end) as sodium
  , MAX(case when labname = 'WBC x 1000' then labresult else null end) as wbc
from vw1
where rn = 1
group by patientunitstayid, labresultoffset
order by patientunitstayid, labresultoffset;
