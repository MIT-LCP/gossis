-- This query pivots lab values taken in the first hour of a patient's stay

-- Have already confirmed that the unit of measurement is always the same: null or the correct unit

DROP TABLE IF EXISTS gossis_labs_h1 CASCADE;
CREATE TABLE gossis_labs_h1 AS
SELECT
    icustay_id
  , min(ANIONGAP) as ANIONGAP_min
  , max(ANIONGAP) as ANIONGAP_max
  , min(ALBUMIN) as ALBUMIN_min
  , max(ALBUMIN) as ALBUMIN_max
  , min(BANDS) as BANDS_min
  , max(BANDS) as BANDS_max
  , min(BILIRUBIN) as BILIRUBIN_min
  , max(BILIRUBIN) as BILIRUBIN_max
  , min(CALCIUM) as CALCIUM_min
  , max(CALCIUM) as CALCIUM_max
  , min(CREATININE) as CREATININE_min
  , max(CREATININE) as CREATININE_max
  , min(CHLORIDE) as CHLORIDE_min
  , max(CHLORIDE) as CHLORIDE_max
  , min(GLUCOSE) as GLUCOSE_min
  , max(GLUCOSE) as GLUCOSE_max
  , min(HCO3) as HCO3_min
  , max(HCO3) as HCO3_max
  , min(HEMATOCRIT) as HEMATOCRIT_min
  , max(HEMATOCRIT) as HEMATOCRIT_max
  , min(HEMOGLOBIN) as HEMOGLOBIN_min
  , max(HEMOGLOBIN) as HEMOGLOBIN_max
  , min(LACTATE) as LACTATE_min
  , max(LACTATE) as LACTATE_max
  , min(PLATELET) as PLATELET_min
  , max(PLATELET) as PLATELET_max
  , min(POTASSIUM) as POTASSIUM_min
  , max(POTASSIUM) as POTASSIUM_max
  , min(PTT) as PTT_min
  , max(PTT) as PTT_max
  , min(INR) as INR_min
  , max(INR) as INR_max
  , min(PT) as PT_min
  , max(PT) as PT_max
  , min(SODIUM) as SODIUM_min
  , max(SODIUM) as SODIUM_max
  , min(BUN) as BUN_min
  , max(BUN) as BUN_max
  , min(WBC) as WBC_min
  , max(WBC) as WBC_max
FROM gossis_labs
WHERE laboffset >= (-1*60) and laboffset <= (1*60)
GROUP BY icustay_id
ORDER BY icustay_id;
