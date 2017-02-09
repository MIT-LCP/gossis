DROP TABLE IF EXISTS gossis CASCADE;
CREATE TABLE gosiss as
select
  -- patient identifiers
    'mimic_' || cast(pt.icustay_id as varchar(40)) as encounterId
  , 'mimic_' || cast(pt.subject_id as varchar(40)) as patientId

  -- hierarchical factors - hospital
  , cast('USA' as varchar(10)) as country
  , cast(-1 as smallint) as hospitalid
  , cast(1 as smallint) as teaching_hospital
  , cast(NULL as smallint) as hospital_bed_size
  , cast(null as varchar(10)) as hospital_type

  -- hierarchical factors - ICU
  , cast(NULL as smallint) as icuId
  , ie.first_careunit as icu_type
  , cast(NULL as varchar(10)) as icu_stay_type

  -- demographics
  , ROUND( (CAST(ie.intime AS DATE) - CAST(pt.dob AS DATE))  / 365.242, 4) AS age
  , pt.gender
  , htwt.weight as weight
  , htwt.height as height
  , case when coalesce(htwt.weight,htwt.height) is not null
      and htwt.height > 0
        then htwt.weight / (htwt.height*htwt.height)
      end as bmi
  , adm.ethnicity
  , cast(NULL as smallint) as pregnant
  , cast(NULL as smallint) as smoking_status

  -- hospital course
  , adm.admission_location as hospital_admit_source
  , adm.discharge_location as hospital_disch_location
  , ROUND( (CAST(adm.dischtime AS DATE) - CAST(adm.admittime AS DATE)) , 4) as hospital_los_days
  , adm.hospital_expire_flag as hospital_death


  , cast(NULL as varchar(10)) as icu_admit_source
  , adm.admission_type as icu_admit_type
  , cast(NULL as varchar(10)) as icu_disch_location
  , ROUND( (CAST(ie.intime AS DATE) - CAST(adm.admittime AS DATE)) , 4) as pre_icu_los_days
  , ROUND( (CAST(ie.outtime AS DATE) - CAST(ie.intime AS DATE)) , 4) as icu_los_days
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
  , v_d1.heartrate_min as d1_heartrate_min
  , v_d1.heartrate_max as d1_heartrate_max
  , v_d1.resprate_min as d1_resprate_min
  , v_d1.resprate_max as d1_resprate_max
  , v_d1.spo2_min as d1_spo2_min
  , v_d1.spo2_max as d1_spo2_max
  , v_d1.temp_min as d1_temp_min
  , v_d1.temp_max as d1_temp_max
  , v_d1.sysbp_invasive_min as d1_sysbp_invasive_min
  , v_d1.sysbp_invasive_max as d1_sysbp_invasive_max
  , v_d1.diasbp_invasive_min as d1_diasbp_invasive_min
  , v_d1.diasbp_invasive_max as d1_diasbp_invasive_max
  , v_d1.mbp_invasive_min as d1_mbp_invasive_min
  , v_d1.mbp_invasive_max as d1_mbp_invasive_max
  , v_d1.sysbp_noninvasive_min as d1_sysbp_noninvasive_min
  , v_d1.sysbp_noninvasive_max as d1_sysbp_noninvasive_max
  , v_d1.diasbp_noninvasive_min as d1_diasbp_noninvasive_min
  , v_d1.diasbp_noninvasive_max as d1_diasbp_noninvasive_max
  , v_d1.mbp_noninvasive_min as d1_mbp_noninvasive_min
  , v_d1.mbp_noninvasive_max as d1_mbp_noninvasive_max

  , case when v_d1.sysbp_invasive_min  <= v_d1.sysbp_noninvasive_min   then v_d1.sysbp_invasive_min
          else coalesce(v_d1.sysbp_noninvasive_min , v_d1.sysbp_invasive_min)  end as d1_sysbp_min
  , case when v_d1.sysbp_invasive_max  >= v_d1.sysbp_noninvasive_max   then v_d1.sysbp_invasive_max
          else coalesce(v_d1.sysbp_noninvasive_max , v_d1.sysbp_invasive_max)  end as d1_sysbp_max
  , case when v_d1.diasbp_invasive_min <= v_d1.diasbp_noninvasive_min  then v_d1.diasbp_invasive_min
          else coalesce(v_d1.diasbp_noninvasive_min, v_d1.diasbp_invasive_min) end as d1_diasbp_min
  , case when v_d1.diasbp_invasive_max >= v_d1.diasbp_noninvasive_max  then v_d1.diasbp_invasive_max
          else coalesce(v_d1.diasbp_noninvasive_max, v_d1.diasbp_invasive_max) end as d1_diasbp_max
  , case when v_d1.mbp_invasive_min    <= v_d1.mbp_noninvasive_min     then v_d1.mbp_invasive_min
          else coalesce(v_d1.mbp_noninvasive_min   , v_d1.mbp_invasive_min)    end as d1_mbp_min
  , case when v_d1.mbp_invasive_max    >= v_d1.mbp_noninvasive_max     then v_d1.mbp_invasive_max
          else coalesce(v_d1.mbp_noninvasive_max   , v_d1.mbp_invasive_max)    end as d1_mbp_max

  -- Physiology - FIRST HOUR
  , v_h1.heartrate_min as h1_heartrate_min
  , v_h1.heartrate_max as h1_heartrate_max
  , v_h1.resprate_min as h1_resprate_min
  , v_h1.resprate_max as h1_resprate_max
  , v_h1.spo2_min as h1_spo2_min
  , v_h1.spo2_max as h1_spo2_max
  , v_h1.temp_min as h1_temp_min
  , v_h1.temp_max as h1_temp_max
  , v_h1.sysbp_invasive_min as h1_sysbp_invasive_min
  , v_h1.sysbp_invasive_max as h1_sysbp_invasive_max
  , v_h1.diasbp_invasive_min as h1_diasbp_invasive_min
  , v_h1.diasbp_invasive_max as h1_diasbp_invasive_max
  , v_h1.mbp_invasive_min as h1_mbp_invasive_min
  , v_h1.mbp_invasive_max as h1_mbp_invasive_max
  , v_h1.sysbp_noninvasive_min as h1_sysbp_noninvasive_min
  , v_h1.sysbp_noninvasive_max as h1_sysbp_noninvasive_max
  , v_h1.diasbp_noninvasive_min as h1_diasbp_noninvasive_min
  , v_h1.diasbp_noninvasive_max as h1_diasbp_noninvasive_max
  , v_h1.mbp_noninvasive_min as h1_mbp_noninvasive_min
  , v_h1.mbp_noninvasive_max as h1_mbp_noninvasive_max

  , case when v_h1.sysbp_invasive_min  <= v_h1.sysbp_noninvasive_min   then v_h1.sysbp_invasive_min
          else coalesce(v_h1.sysbp_noninvasive_min , v_h1.sysbp_invasive_min)  end as h1_sysbp_min
  , case when v_h1.sysbp_invasive_max  >= v_h1.sysbp_noninvasive_max   then v_h1.sysbp_invasive_max
          else coalesce(v_h1.sysbp_noninvasive_max , v_h1.sysbp_invasive_max)  end as h1_sysbp_max
  , case when v_h1.diasbp_invasive_min <= v_h1.diasbp_noninvasive_min  then v_h1.diasbp_invasive_min
          else coalesce(v_h1.diasbp_noninvasive_min, v_h1.diasbp_invasive_min) end as h1_diasbp_min
  , case when v_h1.diasbp_invasive_max >= v_h1.diasbp_noninvasive_max  then v_h1.diasbp_invasive_max
          else coalesce(v_h1.diasbp_noninvasive_max, v_h1.diasbp_invasive_max) end as h1_diasbp_max
  , case when v_h1.mbp_invasive_min    <= v_h1.mbp_noninvasive_min     then v_h1.mbp_invasive_min
          else coalesce(v_h1.mbp_noninvasive_min   , v_h1.mbp_invasive_min)    end as h1_mbp_min
  , case when v_h1.mbp_invasive_max    >= v_h1.mbp_noninvasive_max     then v_h1.mbp_invasive_max
          else coalesce(v_h1.mbp_noninvasive_max   , v_h1.mbp_invasive_max)    end as h1_mbp_max

  -- Labs - FIRST DAY
  , lab_d1.albumin_min as d1_albumin_min
  , lab_d1.albumin_max as d1_albumin_max
  , lab_d1.bilirubin_min as d1_bilirubin_min
  , lab_d1.bilirubin_max as d1_bilirubin_max
  , lab_d1.bun_min as d1_bun_min
  , lab_d1.bun_max as d1_bun_max
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
  , bg_d1.PaO2FiO2Ratio_min as d1_PaO2FiO2Ratio_min

  -- Labs - FIRST HOUR
  , lab_h1.albumin_min as h1_albumin_min
  , lab_h1.albumin_max as h1_albumin_max
  , lab_h1.bilirubin_min as h1_bilirubin_min
  , lab_h1.bilirubin_max as h1_bilirubin_max
  , lab_h1.bun_min as h1_bun_min
  , lab_h1.bun_max as h1_bun_max
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
  , bg_h1.PaO2FiO2Ratio_min as h1_PaO2FiO2Ratio_min

  -- APS III components
  , apsiii.albumin as albumin_apache
  , apsiii.bilirubin as bilirubin_apache
  , apsiii.creatinine as creatinine_apache
  , apsiii.fio2 as fio2_apache
  , apsiii.glucose as glucose_apache
  -- , apsiii. as bicarbonate_apache
  , apsiii.hematocrit as hematocrit_apache
  , apsiii.heartrate as heart_rate_apache
  -- , apsiii. as potassium_apache
  , apsiii.meanbp as map_apache
  , apsiii.sodium as sodium_apache
  , apsiii.pco2 as paco2_apache
  , apsiii.pao2 as pao2_apache
  , apsiii.ph as ph_apache
  , apsiii.respiratoryrate as resprate_apache
  , apsiii.temperature as temp_apache
  , apsiii.bun as bun_apache
  , apsiii.urine as urineoutput_apache
  , apsiii.wbc as wbc_apache
  , apsiii.eyes as gcs_eyes_apache
  , apsiii.motor as gcs_motor_apache
  , apsiii.verbal as gcs_verbal_apache
  , apsiii.meds as gcs_unable_apache
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
  ie.hadm_id = adm.hadm_id
inner join patients pt
  on ie.subject_id = pt.subject_id
left join heightweight htwt
  on ie.icustay_id = htwt.icustay_id
left join gosiss_lab_d1 lab_d1
  on ie.icustay_id = lab_d1.icustay_id
left join gosiss_lab_h1 lab_h1
  on ie.icustay_id = lab_h1.icustay_id
left join gosiss_bg_d1 bg_d1
  on ie.icustay_id = bg_d1.icustay_id
left join gosiss_bg_h1 bg_h1
  on ie.icustay_id = bg_h1.icustay_id
left join gosiss_vital_d1 v_d1
  on ie.icustay_id = v_d1.icustay_id
left join gosiss_vital_h1 v_h1
  on ie.icustay_id = v_h1.icustay_id
left join apsiii
  on ie.icustay_id = apsiii.icustay_id;
