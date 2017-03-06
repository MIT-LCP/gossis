DROP TABLE IF EXISTS gosiss CASCADE;
CREATE TABLE gosiss as
select
  -- patient identifiers
    'mimic_' || cast(ie.icustay_id as varchar(40)) as encounterId
  , 'mimic_' || cast(ie.subject_id as varchar(40)) as patientId

  -- hierarchical factors - hospital
  , cast('USA' as varchar(10)) as country
  , cast(-1 as smallint) as hospitalid
  , cast(1 as smallint) as teaching_hospital
  , cast(NULL as smallint) as hospital_bed_size
  , cast(null as varchar(10)) as hospital_type

  -- hierarchical factors - ICU
  , ie.first_wardid as icuId
  , ie.first_careunit as icu_type
  , cast(NULL as varchar(10)) as icu_stay_type

  -- demographics
  , ROUND( (CAST(ie.intime AS DATE) - CAST(pt.dob AS DATE))  / 365.242, 4) AS age
  , pt.gender
  , demo.weight as weight
  , demo.height*2.54 as height  --converted from inches to cm (for compatibility with other db's)
  , case when coalesce(demo.weight,demo.height) is not null
      and demo.height > 0
        then demo.weight / (demo.height*2.54*0.01 * demo.height*2.54*0.01)
      end as bmi
  , adm.ethnicity
  , cast(demo.PREGNANT as smallint) as pregnant
  , cast(demo.SMOKING as smallint) as smoking_status

  -- hospital course
  , adm.admission_location as hospital_admit_source
  , adm.discharge_location as hospital_disch_location
  , ROUND( (CAST(adm.dischtime AS DATE) - CAST(adm.admittime AS DATE)) , 4) as hospital_los_days
  , adm.hospital_expire_flag as hospital_death


  , cast(NULL as varchar(10)) as icu_admit_source
  , adm.admission_type as icu_admit_type
  , cast(last_careunit as varchar(10)) as icu_disch_location
  , ROUND( (CAST(ie.intime AS DATE) - CAST(adm.admittime AS DATE)) , 4) as pre_icu_los_days
  , ie.los as icu_los_days
  , case when adm.deathtime <= ie.outtime then 1 else 0 end as ICU_death

  , case when adm.admission_type = 'ELECTIVE' then 1 else 0 end as elective_surgery
  , cast(NULL as smallint) as readmission_status


  -- TODO: define events
  , cast(null as smallint) as GIBleed_1h
  , cast(null as smallint) as SNCMass_1h
  , cast(null as smallint) as Aminas_1h
  , cast(null as smallint) as Arrhythmia_1h
  , cast(null as smallint) as AKI_1h
  , cast(null as smallint) as Arritmia_D1
  , cast(null as smallint) as CPA_D1
  , cast(null as smallint) as AKI_D1
  , cast(null as smallint) as GIBleed_D1
  , cast(null as smallint) as SNCMass_D1
  , cast(null as smallint) as Neutrpenia_D1

  -- TODO: Define treatments

  -- TODO: Define comorbidities

  -- Physiology - FIRST DAY
  , v_d1.HeartRate_Min as d1_heartrate_min
  , v_d1.HeartRate_Max as d1_heartrate_max
  , v_d1.RespRate_Min as d1_resprate_min
  , v_d1.RespRate_Max as d1_resprate_max
  , v_d1.SpO2_Min as d1_spo2_min
  , v_d1.SpO2_Max as d1_spo2_max
  , v_d1.TempC_Min as d1_temp_min
  , v_d1.TempC_Max as d1_temp_max
  , v_d1.SysBPInv_Min as d1_sysbp_invasive_min
  , v_d1.SysBPInv_Max as d1_sysbp_invasive_max
  , v_d1.DiasBPInv_Min as d1_diasbp_invasive_min
  , v_d1.DiasBPInv_Max as d1_diasbp_invasive_max
  , v_d1.MBPInv_Min as d1_mbp_invasive_min
  , v_d1.MBPInv_Max as d1_mbp_invasive_max
  , v_d1.SysBPNI_Min as d1_sysbp_noninvasive_min
  , v_d1.SysBPNI_Max as d1_sysbp_noninvasive_max
  , v_d1.DiasBPNI_Min as d1_diasbp_noninvasive_min
  , v_d1.DiasBPNI_Max as d1_diasbp_noninvasive_max
  , v_d1.MBPNI_Min as d1_mbp_noninvasive_min
  , v_d1.MBPNI_Max as d1_mbp_noninvasive_max
  , v_d1.SysBP_Min as d1_sysbp_min
  , v_d1.SysBP_Max as d1_sysbp_max
  , v_d1.DiasBP_Min as d1_diasbp_min
  , v_d1.DiasBP_Max as d1_diasbp_max
  , v_d1.MeanBP_Min as d1_mbp_min
  , v_d1.MeanBP_Max as d1_mbp_max

  -- Physiology - FIRST HOUR
  , v_h1.HeartRate_Min as h1_heartrate_min
  , v_h1.HeartRate_Max as h1_heartrate_max
  , v_h1.RespRate_Min as h1_resprate_min
  , v_h1.RespRate_Max as h1_resprate_max
  , v_h1.SpO2_Min as h1_spo2_min
  , v_h1.SpO2_Max as h1_spo2_max
  , v_h1.TempC_Min as h1_temp_min
  , v_h1.TempC_Max as h1_temp_max
  , v_h1.SysBPInv_Min as h1_sysbp_invasive_min
  , v_h1.SysBPInv_Max as h1_sysbp_invasive_max
  , v_h1.DiasBPInv_Min as h1_diasbp_invasive_min
  , v_h1.DiasBPInv_Max as h1_diasbp_invasive_max
  , v_h1.MBPInv_Min as h1_mbp_invasive_min
  , v_h1.MBPInv_Max as h1_mbp_invasive_max
  , v_h1.SysBPNI_Min as h1_sysbp_noninvasive_min
  , v_h1.SysBPNI_Max as h1_sysbp_noninvasive_max
  , v_h1.DiasBPNI_Min as h1_diasbp_noninvasive_min
  , v_h1.DiasBPNI_Max as h1_diasbp_noninvasive_max
  , v_h1.MBPNI_Min as h1_mbp_noninvasive_min
  , v_h1.MBPNI_Max as h1_mbp_noninvasive_max
  , v_h1.SysBP_Min as h1_sysbp_min
  , v_h1.SysBP_Max as h1_sysbp_max
  , v_h1.DiasBP_Min as h1_diasbp_min
  , v_h1.DiasBP_Max as h1_diasbp_max
  , v_h1.MeanBP_Min as h1_mbp_min
  , v_h1.MeanBP_Max as h1_mbp_max


  -- Labs - FIRST DAY
  , lab_d1.ALBUMIN_min as d1_albumin_min
  , lab_d1.ALBUMIN_max as d1_albumin_max
  , lab_d1.BILIRUBIN_min as d1_bilirubin_min
  , lab_d1.BILIRUBIN_max as d1_bilirubin_max
  , lab_d1.BUN_min as d1_bun_min
  , lab_d1.BUN_max as d1_bun_max
  , lab_d1.CALCIUM_min as d1_calcium_min
  , lab_d1.CALCIUM_max as d1_calcium_max
  , lab_d1.CREATININE_min as d1_creatinine_min
  , lab_d1.CREATININE_max as d1_creatinine_max
  , lab_d1.GLUCOSE_min as d1_glucose_min
  , lab_d1.GLUCOSE_max as d1_glucose_max
  , lab_d1.INR_min as d1_inr_min
  , lab_d1.INR_max as d1_inr_max
  , lab_d1.HCO3_min as d1_hco3_min
  , lab_d1.HCO3_max as d1_hco3_max
  , lab_d1.HEMATOCRIT_min as d1_hematocrit_min
  , lab_d1.HEMATOCRIT_max as d1_hematocrit_max
  , lab_d1.HEMOGLOBIN_min as d1_hemaglobin_min
  , lab_d1.HEMOGLOBIN_max as d1_hemaglobin_max
  , lab_d1.LACTATE_min as d1_lactate_min
  , lab_d1.LACTATE_max as d1_lactate_max
  , lab_d1.PLATELET_min as d1_platelets_min
  , lab_d1.PLATELET_max as d1_platelets_max
  , lab_d1.POTASSIUM_min as d1_potassium_min
  , lab_d1.POTASSIUM_max as d1_potassium_max
  , lab_d1.SODIUM_min as d1_sodium_min
  , lab_d1.SODIUM_max as d1_sodium_max
  , lab_d1.WBC_min as d1_wbc_min
  , lab_d1.WBC_max as d1_wbc_max

  -- blood gases, first day
  , bg_d1.PH_min as d1_arterial_ph_min
  , bg_d1.PH_max as d1_arterial_ph_max
  , bg_d1.PO2_min as d1_arterial_po2_min
  , bg_d1.PO2_max as d1_arterial_po2_max
  , bg_d1.PCO2_min as d1_arterial_pco2_min
  , bg_d1.PCO2_max as d1_arterial_pco2_max
  , bg_d1.PaO2FiO2_min as d1_PaO2FiO2Ratio_min

  -- Labs - FIRST HOUR
  , lab_h1.ALBUMIN_min as h1_albumin_min
  , lab_h1.ALBUMIN_max as h1_albumin_max
  , lab_h1.BILIRUBIN_min as h1_bilirubin_min
  , lab_h1.BILIRUBIN_max as h1_bilirubin_max
  , lab_h1.BUN_min as h1_bun_min
  , lab_h1.BUN_max as h1_bun_max
  , lab_h1.CALCIUM_min as h1_calcium_min
  , lab_h1.CALCIUM_max as h1_calcium_max
  , lab_h1.CREATININE_min as h1_creatinine_min
  , lab_h1.CREATININE_max as h1_creatinine_max
  , lab_h1.GLUCOSE_min as h1_glucose_min
  , lab_h1.GLUCOSE_max as h1_glucose_max
  , lab_h1.INR_min as h1_inr_min
  , lab_h1.INR_max as h1_inr_max
  , lab_h1.HCO3_min as h1_hco3_min
  , lab_h1.HCO3_max as h1_hco3_max
  , lab_h1.HEMATOCRIT_min as h1_hematocrit_min
  , lab_h1.HEMATOCRIT_max as h1_hematocrit_max
  , lab_h1.HEMOGLOBIN_min as h1_hemaglobin_min
  , lab_h1.HEMOGLOBIN_max as h1_hemaglobin_max
  , lab_h1.LACTATE_min as h1_lactate_min
  , lab_h1.LACTATE_max as h1_lactate_max
  , lab_h1.PLATELET_min as h1_platelets_min
  , lab_h1.PLATELET_max as h1_platelets_max
  , lab_h1.POTASSIUM_min as h1_potassium_min
  , lab_h1.POTASSIUM_max as h1_potassium_max
  , lab_h1.SODIUM_min as h1_sodium_min
  , lab_h1.SODIUM_max as h1_sodium_max
  , lab_h1.WBC_min as h1_wbc_min
  , lab_h1.WBC_max as h1_wbc_max

  -- blood gases, first hour
  , bg_h1.PH_min as h1_arterial_ph_min
  , bg_h1.PH_max as h1_arterial_ph_max
  , bg_h1.PO2_min as h1_arterial_po2_min
  , bg_h1.PO2_max as h1_arterial_po2_max
  , bg_h1.PCO2_min as h1_arterial_pco2_min
  , bg_h1.PCO2_max as h1_arterial_pco2_max
  , bg_h1.PaO2FiO2_min as h1_PaO2FiO2Ratio_min

  -- APS III components
  , apsiii.albumin_score as albumin_apache
  , apsiii.bilirubin_score as bilirubin_apache
  , apsiii.creatinine_score as creatinine_apache
  --, apsiii.fio2 as fio2_apache
  , cast(NULL as double precision) as fio2_apache
  , apsiii.glucose_score as glucose_apache
  -- , apsiii.hco3_score as bicarbonate_apache
  , apsiii.hematocrit_score as hematocrit_apache
  , apsiii.hr_score as heart_rate_apache
  -- , apsiii. as potassium_apache
  , apsiii.meanbp_score as map_apache
  , apsiii.sodium_score as sodium_apache
--  , apsiii.pco2 as paco2_apache
--  , apsiii.pao2 as pao2_apache
 -- , apsiii.ph as ph_apache
  , apsiii.resprate_score as resprate_apache
  , apsiii.temp_score as temp_apache
  , apsiii.bun_score as bun_apache
  , apsiii.uo_score as urineoutput_apache
  , apsiii.wbc_score as wbc_apache
  --, apsiii.eyes as gcs_eyes_apache
  --, apsiii.motor as gcs_motor_apache
  --, apsiii.verbal as gcs_verbal_apache
  --, apsiii.meds as gcs_unable_apache
  -- , apsiii.dialysis as dialysis_apache
  -- , apsiii.intubated as intubated_apache
  -- , apsiii.vent as vent_apache

  -- Other measurements - FIRST DAY
  -- , urine_output

  -- Scoring systems
  , cast(NULL as smallint) as apache_iva_score
  , cast(NULL as double precision) as apache_iva_icu_death_prob
  , cast(NULL as double precision) as apache_iva_hospital_death_prob

from icustays ie
-- get prior admissions - QUESTION: is ANZICS prev admission only in hospital??
-- left join patient pt_prior
--   on LAG(ie.icustay_id) OVER (partition by pt.uniquepid order by )
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
inner join patients pt
  on ie.subject_id = pt.subject_id
left join demographics demo
  on ie.icustay_id = demo.icustay_id
left join gossis_labsfirstday lab_d1
  on ie.icustay_id = lab_d1.icustay_id
left join gossis_labsfirsthour lab_h1
  on ie.icustay_id = lab_h1.icustay_id
left join gossis_bg_firstday bg_d1
  on ie.icustay_id = bg_d1.icustay_id
left join gossis_bg_firsthour bg_h1
  on ie.icustay_id = bg_h1.icustay_id
left join gossis_vitalsfirstday v_d1
  on ie.icustay_id = v_d1.icustay_id
left join gossis_vitalsfirsthour v_h1
  on ie.icustay_id = v_h1.icustay_id
left join apsiii
  on ie.icustay_id = apsiii.icustay_id;
