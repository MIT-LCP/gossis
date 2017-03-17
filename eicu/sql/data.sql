DROP TABLE IF EXISTS gosiss CASCADE;
CREATE TABLE gosiss as
select
  -- patient identifiers
  pt.patientunitstayid
  , 'eicu_' || cast(pt.patientunitstayid as varchar(40)) as encounter_id
  , 'eicu_' || pt.uniquepid as patient_id

  -- hierarchical factors - hospital
  , cast('USA' as varchar(10)) as country
  , pt.hospitalid
  , hp.teachingstatus as teaching_hospital
  , hp.numbedscategory as hospital_bed_size
  , cast(null as varchar(10)) as hospital_type

  -- hierarchical factors - ICU
  , pt.wardid as icu_id
  , pt.unittype as icu_type
  , pt.unitstaytype as icu_stay_type

  -- demographics
  , apv.age
  , pt.gender
  , pt.admissionweight as weight
  , pt.admissionheight as height
  , case when coalesce(pt.admissionweight,pt.admissionheight) is not null
      and pt.admissionheight > 0
        then pt.admissionweight / (pt.admissionheight*pt.admissionheight)
      end as bmi
  , pt.ethnicity
  , cast(NULL as smallint) as pregnant
  , cast(NULL as smallint) as smoking_status

  -- hospital course
  , pt.hospitaladmitsource as hospital_admit_source
  , pt.hospitaldischargelocation as hospital_disch_location
  , (pt.hospitaldischargeoffset/60.0/24.0) as hospital_los_days
  , pt.hospitaldischargestatus as hospital_death


  , pt.unitadmitsource as icu_admit_source
  , pt.unittype as icu_admit_type
  , pt.unitdischargelocation as icu_disch_location
  , -(pt.hospitaladmitoffset/60.0/24.0) as pre_icu_los_days
  , (pt.unitdischargeoffset/60.0/24.0) as icu_los_days
  , case when pt.unitdischargestatus = 'Expired' then 1
      when pt.unitdischargestatus = 'Alive' then 0
      else null end
    as ICU_death

  , apv.electivesurgery as elective_surgery
  -- TODO: double check below is a valid field and READMIT == READMITTED (anzics)
  , apv.readmit as readmission_status

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
  , bg_d1.pao2fio2ratio_min as d1_pao2fio2ratio_min
  , cast(null as numeric(5,2)) as d1_pao2fio2ratio_max

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
  , bg_h1.pao2fio2ratio_min as h1_pao2fio2ratio_min
  , cast(null as numeric(5,2)) as h1_pao2fio2ratio_max

  -- APS III components
  , aav.albumin as albumin_apache
  , aav.bilirubin as bilirubin_apache
  , aav.creatinine as creatinine_apache
  , aav.glucose as glucose_apache
  , aav.hematocrit as hematocrit_apache
  , aav.heartrate as heart_rate_apache
  , aav.meanbp as map_apache
  , aav.sodium as sodium_apache
  , aav.fio2 as fio2_apache
  , aav.pco2 as paco2_apache
  , aav.pao2 as pao2_apache
  , aav.ph as ph_apache
  -- TODO: does eICU have a separate paco2 for acid-base scoring?
  , aav.pco2 as paco2_for_ph_apache
  , aav.respiratoryrate as resprate_apache
  , aav.temperature as temp_apache
  , aav.bun as bun_apache
  , aav.urine as urineoutput_apache
  , aav.wbc as wbc_apache
  , aav.eyes as gcs_eyes_apache
  , aav.motor as gcs_motor_apache
  , aav.verbal as gcs_verbal_apache
  , aav.meds as gcs_unable_apache

  , aav.dialysis as arf_apache
  , aav.intubated as intubated_apache
  , aav.vent as ventilated_apache

  -- Other measurements - FIRST DAY
  -- , urine_output

  -- Scoring systems
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
left join gosiss_lab_d1 lab_d1
  on pt.patientunitstayid = lab_d1.patientunitstayid
left join gosiss_lab_h1 lab_h1
  on pt.patientunitstayid = lab_h1.patientunitstayid
left join gosiss_bg_d1 bg_d1
  on pt.patientunitstayid = bg_d1.patientunitstayid
left join gosiss_bg_h1 bg_h1
  on pt.patientunitstayid = bg_h1.patientunitstayid
left join gosiss_vital_d1 v_d1
  on pt.patientunitstayid = v_d1.patientunitstayid
left join gosiss_vital_h1 v_h1
  on pt.patientunitstayid = v_h1.patientunitstayid;
