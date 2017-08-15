-- This script extracts highest/lowest vital signs, as appropriate, for the first 24 hours of a patient's stay.
DROP TABLE IF EXISTS gossis_vital_d1 CASCADE;
CREATE TABLE gossis_vital_d1 as
select
  pat.patientunitstayid
  , vp.heartrate_min
  , vp.heartrate_max
  , vp.resprate_min
  , vp.resprate_max
  , vp.spo2_min
  , vp.spo2_max
  , vp.temp_min
  , vp.temp_max
  , vp.sysbp_invasive_min
  , vp.sysbp_invasive_max
  , vp.diasbp_invasive_min
  , vp.diasbp_invasive_max
  , vp.mbp_invasive_min
  , vp.mbp_invasive_max
  , vap.mbp_noninvasive_min
  , vap.mbp_noninvasive_max
  , vap.sysbp_noninvasive_min
  , vap.sysbp_noninvasive_max
  , vap.diasbp_noninvasive_min
  , vap.diasbp_noninvasive_max
from patient pat
left join
(
  select
    patientunitstayid
    , min(case when heartrate > 0 and heartrate < 300 then heartrate else null end) as heartrate_min
    , max(case when heartrate > 0 and heartrate < 300 then heartrate else null end) as heartrate_max
    , min(case when respiration > 0 and respiration < 70 then respiration else null end) as resprate_min
    , max(case when respiration > 0 and respiration < 70 then respiration else null end) as resprate_max
    , min(case when sao2 > 0 and sao2 <= 100 then sao2 else null end) as spo2_min
    , max(case when sao2 > 0 and sao2 <= 100 then sao2 else null end) as spo2_max
    , min(case when temperature > 70 and temperature < 120 then (temperature-32)/1.8
               when temperature > 10 and temperature < 50 then temperature else null end) as temp_min
    , max(case when temperature > 70 and temperature < 120 then (temperature-32)/1.8
               when temperature > 10 and temperature < 50 then temperature else null end) as temp_max
    , min(case when systemicsystolic > 0 and systemicsystolic < 400 then systemicsystolic else null end) as sysbp_invasive_min
    , max(case when systemicsystolic > 0 and systemicsystolic < 400 then systemicsystolic else null end) as sysbp_invasive_max
    , min(case when systemicdiastolic > 0 and systemicdiastolic < 300 then systemicdiastolic else null end) as diasbp_invasive_min
    , max(case when systemicdiastolic > 0 and systemicdiastolic < 300 then systemicdiastolic else null end) as diasbp_invasive_max
    , min(case when systemicmean > 0 and systemicmean < 300 then systemicmean else null end) as mbp_invasive_min
    , max(case when systemicmean > 0 and systemicmean < 300 then systemicmean else null end) as mbp_invasive_max
  from vitalperiodic
  -- during the first day of their ICU stay
  where observationoffset >= (-60*1) and observationoffset <= (60*24)
  group by patientunitstayid
) vp
  on pat.patientunitstayid = vp.patientunitstayid
left join
(
  select
    patientunitstayid
    , min(case when noninvasivemean > 0 and noninvasivemean < 300 then noninvasivemean else null end) as mbp_noninvasive_min
    , max(case when noninvasivemean > 0 and noninvasivemean < 300 then noninvasivemean else null end) as mbp_noninvasive_max
    , min(case when noninvasivesystolic > 0 and noninvasivesystolic < 400 then noninvasivesystolic else null end) as sysbp_noninvasive_min
    , max(case when noninvasivesystolic > 0 and noninvasivesystolic < 400 then noninvasivesystolic else null end) as sysbp_noninvasive_max
    , min(case when noninvasivediastolic > 0 and noninvasivediastolic < 300 then noninvasivediastolic else null end) as diasbp_noninvasive_min
    , max(case when noninvasivediastolic > 0 and noninvasivediastolic < 300 then noninvasivediastolic else null end) as diasbp_noninvasive_max
  from vitalaperiodic
  -- during the first day of their ICU stay
  where observationoffset >= (-60*1) and observationoffset <= (60*24)
  group by patientunitstayid
) vap
  on pat.patientunitstayid = vap.patientunitstayid;
