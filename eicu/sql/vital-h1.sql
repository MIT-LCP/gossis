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

    when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then 1 -- HeartRate
    -- below case statements just shown for illustration of getting any BP meas
    -- including them would supercede the non-invasive/invasive case statements
    -- when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then 2 -- SysBP
    -- when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then 3 -- DiasBP
    -- when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then 4 -- MeanBP
    when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then 5 -- RespRate
    when itemid in (223761,678) and valuenum > 70 and valuenum < 120  then 6 -- TempF, converted to degC in valuenum call
    when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then 6 -- TempC
    when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then 7 -- SpO2
    when itemid in (807,811,1529,3745,3744,225664,220621,226537) and valuenum > 0 then 8 -- Glucose
    when itemid in (51,6701,220050) and valuenum > 0 and valuenum < 400 then 9 -- SysBPInv
    when itemid in (8368,8555,220051) and valuenum > 0 and valuenum < 300 then 10 -- DiasBPInv
    when itemid in (442,455,220179) and valuenum > 0 and valuenum < 400 then 11 -- SysBPNI
    when itemid in (8440,8441,220180) and valuenum > 0 and valuenum < 300 then 12 -- DiasBPNI
    when itemid in (52,6702,220052,225312) and valuenum > 0 and valuenum < 400 then 13 -- MBPInv
    when itemid in (456,443,220181) and valuenum > 0 and valuenum < 400 then 14 -- MBPNI
    when itemid in (492,220059) and valuenum > 0 and valuenum < 80 then 15 -- PAPs
    when itemid in (8448,220060) and valuenum > 0 and valuenum < 80 then 16 -- PAPd
    when itemid in (491,220061) and valuenum > 0 and valuenum < 80 then 17 -- PAP mean

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
  where observationoffset >= (-60*1) and observationoffset <= (60*1)
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
  where observationoffset >= (-60*1) and observationoffset <= (60*1)
  group by patientunitstayid
) vap
  on pat.patientunitstayid = vap.patientunitstayid;
