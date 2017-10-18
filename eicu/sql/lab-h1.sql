-- This script extracts highest/lowest labs, as appropriate, for the first hour of a patient's stay.

DROP TABLE IF EXISTS gossis_lab_h1 CASCADE;
CREATE TABLE gossis_lab_h1 as
select patientunitstayid
, min(albumin) as albumin_min
, max(albumin) as albumin_max
, min(bilirubin) as bilirubin_min
, max(bilirubin) as bilirubin_max
, min(BUN) as bun_min
, max(BUN) as bun_max
, min(calcium) as calcium_min
, max(calcium) as calcium_max
, min(creatinine) as creatinine_min
, max(creatinine) as creatinine_max
, min(glucose) as glucose_min
, max(glucose) as glucose_max
, min(hco3) as hco3_min
, max(hco3) as hco3_max
, min(hematocrit) as hematocrit_min
, max(hematocrit) as hematocrit_max
, min(hemoglobin) as hemaglobin_min
, max(hemoglobin) as hemaglobin_max
, min(INR) as INR_min
, max(INR) as INR_max
, min(lactate) as lactate_min
, max(lactate) as lactate_max
, min(platelets) as platelets_min
, max(platelets) as platelets_max
, min(potassium) as potassium_min
, max(potassium) as potassium_max
, min(sodium) as sodium_min
, max(sodium) as sodium_max
, min(wbc) as wbc_min
, max(wbc) as wbc_max
from gossis_lab
where labresultoffset >= (-1*60) and labresultoffset <= (1*60)
group by patientunitstayid
order by patientunitstayid;
