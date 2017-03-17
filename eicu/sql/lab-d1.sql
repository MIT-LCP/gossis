-- This script extracts highest/lowest labs, as appropriate, for the first 24 hours of a patient's stay.

DROP TABLE IF EXISTS gosiss_lab_d1 CASCADE;
CREATE TABLE gosiss_lab_d1 as
select patientunitstayid
, min(case when labname = 'albumin' then labresult else null end) as albumin_min
, max(case when labname = 'albumin' then labresult else null end) as albumin_max
, min(case when labname = 'total bilirubin' then labresult else null end) as bilirubin_min
, max(case when labname = 'total bilirubin' then labresult else null end) as bilirubin_max
, min(case when labname = 'BUN' then labresult else null end) as bun_min
, max(case when labname = 'BUN' then labresult else null end) as bun_max
, min(case when labname = 'calcium' then labresult else null end) as calcium_min
, max(case when labname = 'calcium' then labresult else null end) as calcium_max
, min(case when labname = 'creatinine' then labresult else null end) as creatinine_min
, max(case when labname = 'creatinine' then labresult else null end) as creatinine_max
, min(case when labname in ('bedside glucose', 'glucose') then labresult else null end) as glucose_min
, max(case when labname in ('bedside glucose', 'glucose') then labresult else null end) as glucose_max
, min(case when labname = 'bicarbonate' then labresult else null end) as hco3_min
, max(case when labname = 'bicarbonate' then labresult else null end) as hco3_max
, min(case when labname = 'Hct' then labresult else null end) as hematocrit_min
, max(case when labname = 'Hct' then labresult else null end) as hematocrit_max
, min(case when labname = 'Hgb' then labresult else null end) as hemaglobin_min
, max(case when labname = 'Hgb' then labresult else null end) as hemaglobin_max
, min(case when labname = 'PT - INR' then labresult else null end) as INR_min
, max(case when labname = 'PT - INR' then labresult else null end) as INR_max
, min(case when labname = 'lactate' then labresult else null end) as lactate_min
, max(case when labname = 'lactate' then labresult else null end) as lactate_max
, min(case when labname = 'platelets x 1000' then labresult else null end) as platelets_min
, max(case when labname = 'platelets x 1000' then labresult else null end) as platelets_max
, min(case when labname = 'potassium' then labresult else null end) as potassium_min
, max(case when labname = 'potassium' then labresult else null end) as potassium_max
, min(case when labname = 'sodium' then labresult else null end) as sodium_min
, max(case when labname = 'sodium' then labresult else null end) as sodium_max
, min(case when labname = 'WBC x 1000' then labresult else null end) as wbc_min
, max(case when labname = 'WBC x 1000' then labresult else null end) as wbc_max
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
and labresultoffset >= (-24*60) and labresultoffset <= (24*60)
group by patientunitstayid;
