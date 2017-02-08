-- This script extracts highest/lowest vital signs, as appropriate, for the first 24 hours of a patient's stay.
DROP TABLE IF EXISTS gosiss_vital_h1 CASCADE;
CREATE TABLE gosiss_vital_h1 as
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
    , min(heartrate) as heartrate_min
    , max(heartrate) as heartrate_max
    , min(respiration) as resprate_min
    , max(respiration) as resprate_max
    , min(sao2) as spo2_min
    , max(sao2) as spo2_max
    , min(temperature) as temp_min
    , max(temperature) as temp_max
    , min(systemicsystolic) as sysbp_invasive_min
    , max(systemicsystolic) as sysbp_invasive_max
    , min(systemicdiastolic) as diasbp_invasive_min
    , max(systemicdiastolic) as diasbp_invasive_max
    , min(systemicmean) as mbp_invasive_min
    , max(systemicmean) as mbp_invasive_max
  from vitalperiodic
  -- during the first day of their ICU stay
  where observationoffset >= (-60*2) and observationoffset <= (60*1)
  group by patientunitstayid
) vp
  on pat.patientunitstayid = vp.patientunitstayid
left join
(
  select
    patientunitstayid
    , min(noninvasivemean) as mbp_noninvasive_min
    , max(noninvasivemean) as mbp_noninvasive_max
    , min(noninvasivesystolic) as sysbp_noninvasive_min
    , max(noninvasivesystolic) as sysbp_noninvasive_max
    , min(noninvasivediastolic) as diasbp_noninvasive_min
    , max(noninvasivediastolic) as diasbp_noninvasive_max
  from vitalaperiodic
  -- during the first day of their ICU stay
  where observationoffset >= (-60*2) and observationoffset <= (60*1)
  group by patientunitstayid
) vap
  on pat.patientunitstayid = vap.patientunitstayid;
