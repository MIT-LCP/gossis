DROP TABLE IF EXISTS gosiss CASCADE;
CREATE TABLE gosiss as
select
  -- patient identifiers
    ie.dbsource as data_source
  , 'mimic_' || cast(ie.icustay_id as varchar(40)) as encounter_id
  , 'mimic_' || cast(ie.subject_id as varchar(40)) as patient_id

  -- hierarchical factors - hospital
  , cast('USA' as varchar(10)) as country
  , cast(-1 as smallint) as hospital_id
  , cast(1 as smallint) as teaching_hospital
  , cast(NULL as smallint) as hospital_bed_size
  , cast(null as varchar(10)) as hospital_type

  -- hierarchical factors - ICU
  , ie.first_wardid as icu_id
  , ie.first_careunit as icu_type
  , demo.first_service as icu_stay_type

  -- demographics
  , ROUND( (CAST(ie.intime AS DATE) - CAST(pt.dob AS DATE))  / 365.242, 4) AS age
  , pt.gender
  , demo.weight as weight
  , demo.height*2.54 as height  --converted from inches to cm (for compatibility with other db's)
  , case when coalesce(demo.weight,demo.height) is not null
      and demo.height > 0
        then demo.weight / (demo.height*2.54*0.01 * demo.height*2.54*0.01)
      end as bmi
  , case
      when adm.ethnicity in
      (
         'WHITE' --  40996
        , 'WHITE - RUSSIAN' --    164
        , 'WHITE - OTHER EUROPEAN' --     81
        , 'WHITE - BRAZILIAN' --     59
        , 'WHITE - EASTERN EUROPEAN' --     25
      ) then 'Caucasian'
      when adm.ethnicity in
      (
          'BLACK/AFRICAN AMERICAN' --   5440
        , 'BLACK/CAPE VERDEAN' --    200
        , 'BLACK/HAITIAN' --    101
        , 'BLACK/AFRICAN' --     44
        , 'CARIBBEAN ISLAND' --      9
      ) then 'African American'
      when adm.ethnicity in
      (
          'HISPANIC OR LATINO' --   1696
        , 'HISPANIC/LATINO - PUERTO RICAN' --    232
        , 'HISPANIC/LATINO - DOMINICAN' --     78
        -- portugese can be classified as hispanic according to US census bureau
        , 'PORTUGUESE' --     61
        , 'HISPANIC/LATINO - GUATEMALAN' --     40
        , 'HISPANIC/LATINO - CUBAN' --     24
        , 'HISPANIC/LATINO - SALVADORAN' --     19
        , 'HISPANIC/LATINO - CENTRAL AMERICAN (OTHER)' --     13
        , 'HISPANIC/LATINO - MEXICAN' --     13
        , 'HISPANIC/LATINO - COLOMBIAN' --      9
        , 'SOUTH AMERICAN' --      8
        , 'HISPANIC/LATINO - HONDURAN' --      4
      ) then 'Hispanic'
      when adm.ethnicity in
      (
          'ASIAN' --   1509
        , 'ASIAN - CHINESE' --    277
        , 'ASIAN - ASIAN INDIAN' --     85
        , 'ASIAN - VIETNAMESE' --     53
        , 'ASIAN - FILIPINO' --     25
        , 'ASIAN - CAMBODIAN' --     17
        , 'ASIAN - OTHER' --     17
        , 'ASIAN - KOREAN' --     13
        , 'ASIAN - JAPANESE' --      7
        , 'ASIAN - THAI' --      4
      ) then 'Asian'
      when adm.ethnicity in
      (
          'AMERICAN INDIAN/ALASKA NATIVE FEDERALLY RECOGNIZED TRIBE' --      3
        , 'AMERICAN INDIAN/ALASKA NATIVE' --     51
      ) then 'Native American'
    else 'Other/Unknown'
  end as ethnicity
  -- ethnicities which we set to other:
  -- , 'UNKNOWN/NOT SPECIFIED' --   4523
  -- , 'OTHER' --   1512
  -- , 'UNABLE TO OBTAIN' --    814
  -- , 'PATIENT DECLINED TO ANSWER' --    559
  -- , 'MULTI RACE ETHNICITY' --    130
  -- , 'MIDDLE EASTERN' --     43
  -- , 'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' --     18

  , cast(demo.PREGNANT as smallint) as pregnant
  , demo.SMOKING as smoking_status

  -- hospital course
  , case
     when adm.admission_location = 'EMERGENCY ROOM ADMIT' then 'Emergency Department'
     when adm.admission_location = 'TRANSFER FROM HOSP/EXTRAM' then 'Other Hospital'
     when adm.admission_location = 'TRANSFER FROM OTHER HEALT' then 'Other Hospital'
     when adm.admission_location = 'CLINIC REFERRAL/PREMATURE' then 'Direct Admit'
     when adm.admission_location = '** INFO NOT AVAILABLE **' then 'Other'
     when adm.admission_location = 'TRANSFER FROM SKILLED NUR' then 'Direct Admit'
     when adm.admission_location = 'TRSF WITHIN THIS FACILITY' then 'Acute Care/Floor'
     when adm.admission_location = 'HMO REFERRAL/SICK' then 'Direct Admit'
     when adm.admission_location = 'PHYS REFERRAL/NORMAL DELI' then 'Direct Admit'
    else null end
  as hospital_admit_source

  , case
   when adm.discharge_location = 'REHAB/DISTINCT PART HOSP' then 'Rehabilitation'
   when adm.discharge_location = 'HOME WITH HOME IV PROVIDR' then 'Home'
   when adm.discharge_location = 'SNF' then 'Skilled Nursing Facility'
   when adm.discharge_location = 'HOSPICE-MEDICAL FACILITY' then 'Nursing Home'
   when adm.discharge_location = 'HOME HEALTH CARE' then 'Home'
   when adm.discharge_location = 'SHORT TERM HOSPITAL' then 'Other Hospital'
   when adm.discharge_location = 'LONG TERM CARE HOSPITAL' then 'Other Hospital'
   when adm.discharge_location = 'DISC-TRAN TO FEDERAL HC' then 'Other Hospital'
   when adm.discharge_location = 'LEFT AGAINST MEDICAL ADVI' then 'Other'
   when adm.discharge_location = 'OTHER FACILITY' then 'Other External'
   when adm.discharge_location = 'SNF-MEDICAID ONLY CERTIF' then 'Skilled Nursing Facility'
   when adm.discharge_location = 'HOME' then 'Home'
   when adm.discharge_location = 'DEAD/EXPIRED' then 'Death'
   when adm.discharge_location = 'HOSPICE-HOME' then 'Nursing Home'
   when adm.discharge_location = 'DISCH-TRAN TO PSYCH HOSP' then 'Other Hospital'
   when adm.discharge_location = 'DISC-TRAN CANCER/CHLDRN H' then 'Other Hospital'
   when adm.discharge_location = 'ICF' then 'Other External'
   else null end as hospital_disch_location

  , ROUND( (CAST(adm.dischtime AS DATE) - CAST(adm.admittime AS DATE)) , 4) as hospital_los_days
  , adm.hospital_expire_flag as hospital_death


  , cast(NULL as varchar(10)) as icu_admit_source
  , cast(NULL as varchar(10)) as icu_disch_location
  , ROUND(EXTRACT(EPOCH from ie.intime - adm.admittime)::numeric/60.0/60.0/24.0) , 4) as pre_icu_los_days
  , ie.los as icu_los_days
  , case when adm.deathtime <= ie.outtime then 1 else 0 end as ICU_death

  , case when adm.admission_type = 'ELECTIVE' then 1 else 0 end as elective_surgery
  , demo.readmission as readmission_status

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
  , v_d1.PASys_Min as d1_pasys_invasive_min
  , v_d1.PASys_Max as d1_pasys_invasive_max
  , v_d1.PADias_Min as d1_padias_invasive_min
  , v_d1.PADias_Max as d1_padias_invasive_max
  , v_d1.PAMean_Min as d1_pamean_invasive_min
  , v_d1.PAMean_Max as d1_pamean_invasive_max

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
  , v_h1.PASys_Min as h1_pasys_invasive_min
  , v_h1.PASys_Max as h1_pasys_invasive_max
  , v_h1.PADias_Min as h1_padias_invasive_min
  , v_h1.PADias_Max as h1_padias_invasive_max
  , v_h1.PAMean_Min as h1_pamean_invasive_min
  , v_h1.PAMean_Max as h1_pamean_invasive_max


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
  , bg_d1.PAO2_min as d1_arterial_po2_min
  , bg_d1.PAO2_max as d1_arterial_po2_max
  , bg_d1.PACO2_min as d1_arterial_pco2_min
  , bg_d1.PACO2_max as d1_arterial_pco2_max
  , bg_d1.PaO2FiO2_min as d1_PaO2FiO2Ratio_min
  , bg_d1.PaO2FiO2_max as d1_PaO2FiO2Ratio_max

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
  , bg_h1.PAO2_min as h1_arterial_po2_min
  , bg_h1.PAO2_max as h1_arterial_po2_max
  , bg_h1.PACO2_min as h1_arterial_pco2_min
  , bg_h1.PACO2_max as h1_arterial_pco2_max
  , bg_h1.PaO2FiO2_min as h1_PaO2FiO2Ratio_min
  , bg_h1.PaO2FiO2_max as h1_PaO2FiO2Ratio_max

  -- APS III components
  , apsiii.albumin as albumin_apache
  , apsiii.bilirubin as bilirubin_apache
  , apsiii.creatinine as creatinine_apache
  , apsiii.glucose as glucose_apache
  , apsiii.hematocrit as hematocrit_apache
  , apsiii.heart_rate as heart_rate_apache
  , apsiii.meanbp as map_apache
  , apsiii.sodium as sodium_apache
  , bg_d1.aps3_oxy_fio2 as fio2_apache
  , bg_d1.aps3_oxy_paco2 as paco2_apache
  , bg_d1.aps3_oxy_pao2 as pao2_apache
  -- , bg_d1.aps3_oxy_aado2
  -- , bg_d1.oxygenation_score

  , bg_d1.aps3_acidbase_ph as ph_apache
  , bg_d1.aps3_acidbase_paco2 as paco2_for_ph_apache
  -- , bg_d1.acidbase_score
  , apsiii.resprate as resprate_apache
  , apsiii.temp as temp_apache
  , apsiii.bun as bun_apache
  , apsiii.urineoutput as urineoutput_apache
  , apsiii.wbc as wbc_apache

  , apsiii.gcseyes as gcs_eyes_apache
  , apsiii.gcsmotor as gcs_motor_apache
  -- 0 represents assuming pt is normal, so re-map it to 5
  , case
      when apsiii.gcsverbal = 0 then 5
    else apsiii.gcsverbal end
    as gcs_verbal_apache
  , apsiii.gcsunable as gcs_unable_apache

  , apsiii.vent as ventilated_apache
  , apsiii.arf as dialysis_apache
  -- , ??? as intubated_apache

  -- Scoring systems
  , apsiii.apsiii
  , cast(NULL as smallint) as apache_3j_score
  , cast(NULL as double precision) as apache_4a_icu_death_prob
  , cast(NULL as double precision) as apache_4a_hospital_death_prob

from icustays ie
-- get prior admissions - QUESTION: is ANZICS prev admission only in hospital??
-- left join patient pt_prior
--   on LAG(ie.icustay_id) OVER (partition by pt.uniquepid order by )
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
inner join patients pt
  on ie.subject_id = pt.subject_id
left join gosiss_demographics demo
  on ie.icustay_id = demo.icustay_id
left join gosiss_labs_d1 lab_d1
  on ie.icustay_id = lab_d1.icustay_id
left join gosiss_labs_h1 lab_h1
  on ie.icustay_id = lab_h1.icustay_id
left join gosiss_bg_d1 bg_d1
  on ie.icustay_id = bg_d1.icustay_id
left join gosiss_bg_h1 bg_h1
  on ie.icustay_id = bg_h1.icustay_id
left join gossis_vitals_d1 v_d1
  on ie.icustay_id = v_d1.icustay_id
left join gossis_vitals_h1 v_h1
  on ie.icustay_id = v_h1.icustay_id
left join gosiss_apsiii apsiii
  on ie.icustay_id = apsiii.icustay_id
-- Apply exclusion criteria
where ie.icustay_id in
(
select icustay_id
from gosiss_cohort co
where co.excluded = 0
);
