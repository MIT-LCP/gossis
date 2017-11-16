DROP TABLE IF EXISTS gossis CASCADE;
CREATE TABLE gossis as
with htwt as
(
select pt.patientunitstayid
  , case when pt.admissionweight < 25 then null
         else pt.admissionweight end as weight
  , case when pt.admissionheight < 0.5 then null
       when pt.admissionheight < 3.0 then pt.admissionheight*100
       when pt.admissionheight < 50 then null
       when pt.admissionheight > 300 then null
      else pt.admissionheight end as height
from patient pt
)
select
  -- patient identifiers
  pt.patientunitstayid
  , 'eicu_' || cast(pt.patientunitstayid as varchar(40)) as encounter_id
  , 'eicu_' || pt.uniquepid as patient_id

  -- hierarchical factors - hospital
  , cast('USA' as varchar(10)) as country
  , pt.hospitalid as hospital_id
  , hp.teachingstatus as teaching_hospital
  , hp.numbedscategory as hospital_bed_size
  , cast(null as varchar(10)) as hospital_type

  -- hierarchical factors - ICU
  , pt.wardid as icu_id
  , pt.unittype as icu_type
  , pt.unitstaytype as icu_stay_type

  -- demographics
  , apv.age
  , case
      when pt.gender = 'Female' then 'F'
      when pt.gender = 'Male' then 'M'
    else null end as gender
  , htwt.weight
  , htwt.height
  , case when coalesce(htwt.weight,htwt.height) is not null
      -- 0.0001 converts height from centimetres to metres
      then htwt.weight / (htwt.height*htwt.height*0.0001)
    end as bmi
  , pt.ethnicity
  , cast(NULL as smallint) as pregnant
  , cast(NULL as smallint) as smoking_status

  -- hospital course
  , pt.hospitaladmitsource as hospital_admit_source
  , pt.hospitaldischargelocation as hospital_disch_location
  , (pt.hospitaldischargeoffset/60.0/24.0) as hospital_los_days
  , case when pt.hospitaldischargestatus = 'Alive' then 0
         when pt.hospitaldischargestatus = 'Expired' then 1
      else null end as hospital_death


  , pt.unitadmitsource as icu_admit_source
  --, pt.unittype as icu_stay_type
  , pt.unitdischargelocation as icu_disch_location
  , -(pt.hospitaladmitoffset/60.0/24.0) as pre_icu_los_days
  , (pt.unitdischargeoffset/60.0/24.0) as icu_los_days
  , case when pt.unitdischargestatus = 'Expired' then 1
      when pt.unitdischargestatus = 'Alive' then 0
      else null end
    as ICU_death

  , case when coalesce(apv.electivesurgery,0)=1 then 1 else 0 end as elective_surgery
  -- , apv.readmit as readmission_status
  , case
      when ROW_NUMBER() over (PARTITION BY pt.patientunitstayid ORDER BY pt.hospitaldischargeoffset DESC)
        > 1 then 1
    else 0 end as readmission_status

  -- TODO: Define treatments

  -- TODO: Define comorbidities

  -- Physiology - FIRST DAY
  -- prioritize nurse charting, but use vitals tables if we don't have charted
  , coalesce(vnc_d1.heartrate_min, v_d1.heartrate_min) as d1_heartrate_min
  , coalesce(vnc_d1.heartrate_max, v_d1.heartrate_max) as d1_heartrate_max
  , coalesce(vnc_d1.resprate_min, v_d1.resprate_min) as d1_resprate_min
  , coalesce(vnc_d1.resprate_max, v_d1.resprate_max) as d1_resprate_max
  , coalesce(vnc_d1.spo2_min, v_d1.spo2_min) as d1_spo2_min
  , coalesce(vnc_d1.spo2_max, v_d1.spo2_max) as d1_spo2_max
  , coalesce(vnc_d1.temp_min, v_d1.temp_min) as d1_temp_min
  , coalesce(vnc_d1.temp_max, v_d1.temp_max) as d1_temp_max
  , coalesce(vnc_d1.sysbp_invasive_min, v_d1.sysbp_invasive_min) as d1_sysbp_invasive_min
  , coalesce(vnc_d1.sysbp_invasive_max, v_d1.sysbp_invasive_max) as d1_sysbp_invasive_max
  , coalesce(vnc_d1.diasbp_invasive_min, v_d1.diasbp_invasive_min) as d1_diasbp_invasive_min
  , coalesce(vnc_d1.diasbp_invasive_max, v_d1.diasbp_invasive_max) as d1_diasbp_invasive_max
  , coalesce(vnc_d1.mbp_invasive_min, v_d1.mbp_invasive_min) as d1_mbp_invasive_min
  , coalesce(vnc_d1.mbp_invasive_max, v_d1.mbp_invasive_max) as d1_mbp_invasive_max
  , coalesce(vnc_d1.sysbp_noninvasive_min, v_d1.sysbp_noninvasive_min) as d1_sysbp_noninvasive_min
  , coalesce(vnc_d1.sysbp_noninvasive_max, v_d1.sysbp_noninvasive_max) as d1_sysbp_noninvasive_max
  , coalesce(vnc_d1.diasbp_noninvasive_min, v_d1.diasbp_noninvasive_min) as d1_diasbp_noninvasive_min
  , coalesce(vnc_d1.diasbp_noninvasive_max, v_d1.diasbp_noninvasive_max) as d1_diasbp_noninvasive_max
  , coalesce(vnc_d1.mbp_noninvasive_min, v_d1.mbp_noninvasive_min) as d1_mbp_noninvasive_min
  , coalesce(vnc_d1.mbp_noninvasive_max, v_d1.mbp_noninvasive_max) as d1_mbp_noninvasive_max

  , coalesce(vnc_d1.sysbp_noninvasive_min , vnc_d1.sysbp_invasive_min,
             v_d1.sysbp_noninvasive_min   , v_d1.sysbp_invasive_min)  as d1_sysbp_min
  , coalesce(vnc_d1.sysbp_noninvasive_max , vnc_d1.sysbp_invasive_max,
             v_d1.sysbp_noninvasive_max   , v_d1.sysbp_invasive_max)  as d1_sysbp_max
  , coalesce(vnc_d1.diasbp_noninvasive_min, vnc_d1.diasbp_invasive_min,
             v_d1.diasbp_noninvasive_min  , v_d1.diasbp_invasive_min) as d1_diasbp_min
  , coalesce(vnc_d1.diasbp_noninvasive_max, vnc_d1.diasbp_invasive_max,
             v_d1.diasbp_noninvasive_max  , v_d1.diasbp_invasive_max) as d1_diasbp_max
  , coalesce(vnc_d1.mbp_noninvasive_min   , vnc_d1.mbp_invasive_min,
             v_d1.mbp_noninvasive_min     , v_d1.mbp_invasive_min)    as d1_mbp_min
  , coalesce(vnc_d1.mbp_noninvasive_max   , vnc_d1.mbp_invasive_max,
             v_d1.mbp_noninvasive_max     , v_d1.mbp_invasive_max)    as d1_mbp_max

  -- Physiology - FIRST HOUR
  , coalesce(vnc_h1.heartrate_min, v_h1.heartrate_min) as h1_heartrate_min
  , coalesce(vnc_h1.heartrate_max, v_h1.heartrate_max) as h1_heartrate_max
  , coalesce(vnc_h1.resprate_min, v_h1.resprate_min) as h1_resprate_min
  , coalesce(vnc_h1.resprate_max, v_h1.resprate_max) as h1_resprate_max
  , coalesce(vnc_h1.spo2_min, v_h1.spo2_min) as h1_spo2_min
  , coalesce(vnc_h1.spo2_max, v_h1.spo2_max) as h1_spo2_max
  , coalesce(vnc_h1.temp_min, v_h1.temp_min) as h1_temp_min
  , coalesce(vnc_h1.temp_max, v_h1.temp_max) as h1_temp_max
  , coalesce(vnc_h1.sysbp_invasive_min, v_h1.sysbp_invasive_min) as h1_sysbp_invasive_min
  , coalesce(vnc_h1.sysbp_invasive_max, v_h1.sysbp_invasive_max) as h1_sysbp_invasive_max
  , coalesce(vnc_h1.diasbp_invasive_min, v_h1.diasbp_invasive_min) as h1_diasbp_invasive_min
  , coalesce(vnc_h1.diasbp_invasive_max, v_h1.diasbp_invasive_max) as h1_diasbp_invasive_max
  , coalesce(vnc_h1.mbp_invasive_min, v_h1.mbp_invasive_min) as h1_mbp_invasive_min
  , coalesce(vnc_h1.mbp_invasive_max, v_h1.mbp_invasive_max) as h1_mbp_invasive_max
  , coalesce(vnc_h1.sysbp_noninvasive_min, v_h1.sysbp_noninvasive_min) as h1_sysbp_noninvasive_min
  , coalesce(vnc_h1.sysbp_noninvasive_max, v_h1.sysbp_noninvasive_max) as h1_sysbp_noninvasive_max
  , coalesce(vnc_h1.diasbp_noninvasive_min, v_h1.diasbp_noninvasive_min) as h1_diasbp_noninvasive_min
  , coalesce(vnc_h1.diasbp_noninvasive_max, v_h1.diasbp_noninvasive_max) as h1_diasbp_noninvasive_max
  , coalesce(vnc_h1.mbp_noninvasive_min, v_h1.mbp_noninvasive_min) as h1_mbp_noninvasive_min
  , coalesce(vnc_h1.mbp_noninvasive_max, v_h1.mbp_noninvasive_max) as h1_mbp_noninvasive_max

  , coalesce(vnc_h1.sysbp_noninvasive_min , vnc_h1.sysbp_invasive_min,
             v_h1.sysbp_noninvasive_min   , v_h1.sysbp_invasive_min)  as h1_sysbp_min
  , coalesce(vnc_h1.sysbp_noninvasive_max , vnc_h1.sysbp_invasive_max,
             v_h1.sysbp_noninvasive_max   , v_h1.sysbp_invasive_max)  as h1_sysbp_max
  , coalesce(vnc_h1.diasbp_noninvasive_min, vnc_h1.diasbp_invasive_min,
             v_h1.diasbp_noninvasive_min  , v_h1.diasbp_invasive_min) as h1_diasbp_min
  , coalesce(vnc_h1.diasbp_noninvasive_max, vnc_h1.diasbp_invasive_max,
             v_h1.diasbp_noninvasive_max  , v_h1.diasbp_invasive_max) as h1_diasbp_max
  , coalesce(vnc_h1.mbp_noninvasive_min   , vnc_h1.mbp_invasive_min,
             v_h1.mbp_noninvasive_min     , v_h1.mbp_invasive_min)    as h1_mbp_min
  , coalesce(vnc_h1.mbp_noninvasive_max   , vnc_h1.mbp_invasive_max,
             v_h1.mbp_noninvasive_max     , v_h1.mbp_invasive_max)    as h1_mbp_max

  -- Labs - FIRST DAY
  , lab_d1.albumin_min as d1_albumin_min
  , lab_d1.albumin_max as d1_albumin_max
  , lab_d1.bilirubin_min as d1_bilirubin_min
  , lab_d1.bilirubin_max as d1_bilirubin_max
  , lab_d1.bun_min as d1_bun_min
  , lab_d1.bun_max as d1_bun_max
  , lab_d1.calcium_min as d1_calcium_min
  , lab_d1.calcium_max as d1_calcium_max
  , lab_d1.creatinine_min as d1_creatinine_min
  , lab_d1.creatinine_max as d1_creatinine_max
  , lab_d1.glucose_min as d1_glucose_min
  , lab_d1.glucose_max as d1_glucose_max
  , lab_d1.hco3_min as d1_hco3_min
  , lab_d1.hco3_max as d1_hco3_max
  , lab_d1.hematocrit_min as d1_hematocrit_min
  , lab_d1.hematocrit_max as d1_hematocrit_max
  , lab_d1.hemaglobin_min as d1_hemaglobin_min
  , lab_d1.hemaglobin_max as d1_hemaglobin_max
  , lab_d1.inr_min as d1_inr_min
  , lab_d1.inr_max as d1_inr_max
  , lab_d1.lactate_min as d1_lactate_min
  , lab_d1.lactate_max as d1_lactate_max
  , lab_d1.platelets_min as d1_platelets_min
  , lab_d1.platelets_max as d1_platelets_max
  , lab_d1.potassium_min as d1_potassium_min
  , lab_d1.potassium_max as d1_potassium_max
  , lab_d1.sodium_min as d1_sodium_min
  , lab_d1.sodium_max as d1_sodium_max
  , lab_d1.wbc_min as d1_wbc_min
  , lab_d1.wbc_max as d1_wbc_max

  -- blood gases, first day
  , bg_d1.ph_min as d1_arterial_ph_min
  , bg_d1.ph_max as d1_arterial_ph_max
  , bg_d1.pao2_min as d1_arterial_po2_min
  , bg_d1.pao2_max as d1_arterial_po2_max
  , bg_d1.paco2_min as d1_arterial_pco2_min
  , bg_d1.paco2_max as d1_arterial_pco2_max
  , bg_d1.pao2fio2ratio_min as d1_pao2fio2ratio_min
  , bg_d1.pao2fio2ratio_max as d1_pao2fio2ratio_max

  -- Labs - FIRST HOUR
  , lab_h1.albumin_min as h1_albumin_min
  , lab_h1.albumin_max as h1_albumin_max
  , lab_h1.bilirubin_min as h1_bilirubin_min
  , lab_h1.bilirubin_max as h1_bilirubin_max
  , lab_h1.bun_min as h1_bun_min
  , lab_h1.bun_max as h1_bun_max
  , lab_h1.calcium_min as h1_calcium_min
  , lab_h1.calcium_max as h1_calcium_max
  , lab_h1.creatinine_min as h1_creatinine_min
  , lab_h1.creatinine_max as h1_creatinine_max
  , lab_h1.glucose_min as h1_glucose_min
  , lab_h1.glucose_max as h1_glucose_max
  , lab_h1.hco3_min as h1_hco3_min
  , lab_h1.hco3_max as h1_hco3_max
  , lab_h1.hematocrit_min as h1_hematocrit_min
  , lab_h1.hematocrit_max as h1_hematocrit_max
  , lab_h1.hemaglobin_min as h1_hemaglobin_min
  , lab_h1.hemaglobin_max as h1_hemaglobin_max
  , lab_d1.inr_min as h1_inr_min
  , lab_d1.inr_max as h1_inr_max
  , lab_h1.lactate_min as h1_lactate_min
  , lab_h1.lactate_max as h1_lactate_max
  , lab_h1.platelets_min as h1_platelets_min
  , lab_h1.platelets_max as h1_platelets_max
  , lab_h1.potassium_min as h1_potassium_min
  , lab_h1.potassium_max as h1_potassium_max
  , lab_h1.sodium_min as h1_sodium_min
  , lab_h1.sodium_max as h1_sodium_max
  , lab_h1.wbc_min as h1_wbc_min
  , lab_h1.wbc_max as h1_wbc_max

  -- blood gases, first hour
  , bg_h1.ph_min as h1_arterial_ph_min
  , bg_h1.ph_max as h1_arterial_ph_max
  , bg_h1.pao2_min as h1_arterial_po2_min
  , bg_h1.pao2_max as h1_arterial_po2_max
  , bg_h1.paco2_min as h1_arterial_pco2_min
  , bg_h1.paco2_max as h1_arterial_pco2_max
  , bg_h1.pao2fio2ratio_min as h1_pao2fio2ratio_min
  , bg_h1.pao2fio2ratio_max as h1_pao2fio2ratio_max

  -- APS III components
  , case when aav.albumin = -1 then NULL else aav.albumin end as albumin_apache
  , case when aav.bilirubin = -1 then NULL else aav.bilirubin end as bilirubin_apache
  , case when aav.creatinine = -1 then NULL else aav.creatinine end as creatinine_apache
  , case when aav.glucose = -1 then NULL else aav.glucose end as glucose_apache
  , case when aav.hematocrit = -1 then NULL else aav.hematocrit end as hematocrit_apache
  , case when aav.heartrate = -1 then NULL else aav.heartrate end as heart_rate_apache
  , case when aav.meanbp = -1 then NULL else aav.meanbp end as map_apache
  , case when aav.sodium = -1 then NULL else aav.sodium end as sodium_apache
  , case when aav.fio2 = -1 then NULL else aav.fio2/100.0 end as fio2_apache
  , case when aav.pco2 = -1 then NULL else aav.pco2 end as paco2_apache
  , case when aav.pao2 = -1 then NULL else aav.pao2 end as pao2_apache
  , case when aav.ph = -1 then NULL else aav.ph end as ph_apache
  -- note that eICU uses the same PaCO2 for oxygenation and pH scoring
  , case when aav.pco2 = -1 then NULL else aav.pco2 end as paco2_for_ph_apache
  , case when aav.respiratoryrate = -1 then NULL else aav.respiratoryrate end as resprate_apache
  , case when aav.temperature = -1 then NULL else aav.temperature end as temp_apache
  , case when aav.bun = -1 then NULL else aav.bun end as bun_apache
  , case when aav.urine = -1 then NULL else aav.urine end as urineoutput_apache
  , case when aav.wbc = -1 then NULL else aav.wbc end as wbc_apache
  , case when aav.eyes = -1 then NULL else aav.eyes end as gcs_eyes_apache
  , case when aav.motor = -1 then NULL else aav.motor end as gcs_motor_apache
  , case when aav.verbal = -1 then NULL else aav.verbal end as gcs_verbal_apache
  , case when aav.meds = -1 then NULL else aav.meds end as gcs_unable_apache

  , case when aav.dialysis = -1 then NULL else aav.dialysis end as arf_apache
  , case when aav.intubated = -1 then NULL else aav.intubated end as intubated_apache
  , case when aav.vent = -1 then NULL else aav.vent end as ventilated_apache

  -- Other measurements - FIRST DAY
  -- , urine_output

  -- Diagnosis
  -- this is the short phrase, 427 possible diagnoses
  , apv.admitdiagnosis

  -- Scoring systems
  , apr.acutephysiologyscore as apsiii
  , apr.apachescore as apache_3j_score
  , cast(apr.predictedicumortality as double precision) as apache_4a_icu_death_prob
  , cast(apr.predictedhospitalmortality as double precision) as apache_4a_hospital_death_prob

from patient pt
-- get prior admissions - QUESTION: is ANZICS prev admission only in hospital??
-- left join patient pt_prior
--   on LAG(pt.patientunitstayid) OVER (partition by pt.uniquepid order by )
left join hospital hp
  on pt.hospitalid = hp.hospitalid
left join apacheapsvar aav
  on pt.patientunitstayid = aav.patientunitstayid
left join apachepredvar apv
  on pt.patientunitstayid = apv.patientunitstayid
left join apachepatientresult apr
  on pt.patientunitstayid = apr.patientunitstayid
  and apr.apacheversion = 'IVa'
left join htwt
  on pt.patientunitstayid = htwt.patientunitstayid
left join gossis_lab_d1 lab_d1
  on pt.patientunitstayid = lab_d1.patientunitstayid
left join gossis_lab_h1 lab_h1
  on pt.patientunitstayid = lab_h1.patientunitstayid
left join gossis_bg_d1 bg_d1
  on pt.patientunitstayid = bg_d1.patientunitstayid
left join gossis_bg_h1 bg_h1
  on pt.patientunitstayid = bg_h1.patientunitstayid
left join gossis_vital_d1 v_d1
  on pt.patientunitstayid = v_d1.patientunitstayid
left join gossis_vital_h1 v_h1
  on pt.patientunitstayid = v_h1.patientunitstayid
left join gossis_vital_nc_d1 vnc_d1
  on pt.patientunitstayid = vnc_d1.patientunitstayid
left join gossis_vital_nc_h1 vnc_h1
  on pt.patientunitstayid = vnc_h1.patientunitstayid
where pt.patientunitstayid in
(
select patientunitstayid
from gossis_cohort co
where co.excluded = 0
)
order by pt.patientunitstayid;
