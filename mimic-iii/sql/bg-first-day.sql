-- The aim of this query is to pivot entries related to blood gases and
-- chemistry values which were found in LABEVENTS

-- now generate arterial only blood gas samples
DROP MATERIALIZED VIEW IF EXISTS gossis_bg_firstday CASCADE;
CREATE MATERIALIZED VIEW gossis_bg_firstday AS
with bg as
(
 -- subselect to first day values only
 select bg.*
 from bloodgas bg
 inner join icustays ie
  on bg.icustay_id = ie.icustay_id
  and bg.charttime between ie.intime - interval '1' day and ie.intime + interval '1' day
)
, stg_spo2 as
(
  select SUBJECT_ID, HADM_ID, ICUSTAY_ID, CHARTTIME
    -- max here is just used to group SpO2 by charttime
    , max(case when valuenum <= 0 or valuenum > 100 then null else valuenum end) as SpO2
  from CHARTEVENTS
  -- o2 sat
  where ITEMID in
  (
    646 -- SpO2
  , 220277 -- O2 saturation pulseoxymetry
  )
  group by SUBJECT_ID, HADM_ID, ICUSTAY_ID, CHARTTIME
)
, stg_fio2 as
(
  select SUBJECT_ID, HADM_ID, ICUSTAY_ID, CHARTTIME
    -- pre-process the FiO2s to ensure they are between 21-100%
    , max(
        case
          when itemid = 223835
            then case
              when valuenum > 0.2 and valuenum <= 1
                then valuenum * 100
              -- improperly input data - looks like O2 flow in litres
              when valuenum > 1 and valuenum < 21
                then null
              when valuenum >= 21 and valuenum <= 100
                then valuenum
              else null end -- unphysiological
        when itemid in (3420, 3422)
        -- all these values are well formatted
            then valuenum
        when itemid = 190 and valuenum > 0.20 and valuenum < 1
        -- well formatted but not in %
            then valuenum * 100
      else null end
    ) as fio2_chartevents
  from CHARTEVENTS
  where ITEMID in
  (
    3420 -- FiO2
  , 190 -- FiO2 set
  , 223835 -- Inspired O2 Fraction (FiO2)
  , 3422 -- FiO2 [measured]
  )
  -- exclude rows marked as error
  and error IS DISTINCT FROM 1
  group by SUBJECT_ID, HADM_ID, ICUSTAY_ID, CHARTTIME
)
, stg2 as
(
select bg.*
  , ROW_NUMBER() OVER (partition by bg.icustay_id, bg.charttime order by s1.charttime DESC) as lastRowSpO2
  , s1.spo2
from bg
left join stg_spo2 s1
  -- same patient
  on  bg.icustay_id = s1.icustay_id
  -- spo2 occurred at most 2 hours before this blood gas
  and s1.charttime between bg.charttime - interval '2' hour and bg.charttime
where bg.po2 is not null
)
, stg3 as
(
select bg.*
  , ROW_NUMBER() OVER (partition by bg.icustay_id, bg.charttime order by s2.charttime DESC) as lastRowFiO2
  , s2.fio2_chartevents

  -- create our specimen prediction
  ,  1/(1+exp(-(-0.02544
  +    0.04598 * po2
  + coalesce(-0.15356 * spo2             , -0.15356 *   97.49420 +    0.13429)
  + coalesce( 0.00621 * fio2_chartevents ,  0.00621 *   51.49550 +   -0.24958)
  + coalesce( 0.10559 * hemoglobin       ,  0.10559 *   10.32307 +    0.05954)
  + coalesce( 0.13251 * so2              ,  0.13251 *   93.66539 +   -0.23172)
  + coalesce(-0.01511 * pco2             , -0.01511 *   42.08866 +   -0.01630)
  + coalesce( 0.01480 * fio2             ,  0.01480 *   63.97836 +   -0.31142)
  + coalesce(-0.00200 * aado2            , -0.00200 *  442.21186 +   -0.01328)
  + coalesce(-0.03220 * bicarbonate      , -0.03220 *   22.96894 +   -0.06535)
  + coalesce( 0.05384 * totalco2         ,  0.05384 *   24.72632 +   -0.01405)
  + coalesce( 0.08202 * lactate          ,  0.08202 *    3.06436 +    0.06038)
  + coalesce( 0.10956 * ph               ,  0.10956 *    7.36233 +   -0.00617)
  + coalesce( 0.00848 * o2flow           ,  0.00848 *    7.59362 +   -0.35803)
  ))) as SPECIMEN_PROB
from stg2 bg
left join stg_fio2 s2
  -- same patient
  on  bg.icustay_id = s2.icustay_id
  -- fio2 occurred at most 4 hours before this blood gas
  and s2.charttime between bg.charttime - interval '4' hour and bg.charttime
where bg.lastRowSpO2 = 1 -- only the row with the most recent SpO2 (if no SpO2 found lastRowSpO2 = 1)
)
select subject_id, hadm_id, icustay_id
-- , charttime
-- , SPECIMEN -- raw data indicating sample type, only present 80% of the time

-- prediction of specimen for missing data
-- , case
--       when SPECIMEN is not null then SPECIMEN
--       when SPECIMEN_PROB > 0.75 then 'ART'
--     else null end as SPECIMEN_PRED
-- , SPECIMEN_PROB

-- oxygen related parameters
-- , SO2, spo2 -- note spo2 is from chartevents
, max(PO2) as PO2_max
, max(PCO2) as PCO2_max
, min(PO2) as PO2_min
, min(PCO2) as PCO2_min
-- , fio2_chartevents, FIO2
-- , AADO2
-- also calculate AADO2
-- , case
--     when  PO2 is not null
--       and pco2 is not null
--       and coalesce(FIO2, fio2_chartevents) is not null
--      -- multiple by 100 because FiO2 is in a % but should be a fraction
--       then (coalesce(FIO2, fio2_chartevents)/100) * (760 - 47) - (pco2/0.8) - po2
--     else null
--   end as AADO2_calc
, min(case
    when PO2 is not null and coalesce(FIO2, fio2_chartevents) is not null
     -- multiply by 100 because FiO2 is in a % but should be a fraction
      then 100*PO2/(coalesce(FIO2, fio2_chartevents))
    else null
  end) as PaO2FiO2_min
-- acid-base parameters
, max(PH) as PH_max
, min(PH) as PH_min

, min(BASEEXCESS) as BASEEXCESS_min
, max(BASEEXCESS) as BASEEXCESS_max
, min(BICARBONATE) as BICARBONATE_min
, max(BICARBONATE) as BICARBONATE_max
, min(TOTALCO2) as TOTALCO2_min
, max(TOTALCO2) as TOTALCO2_max

-- blood count parameters
, min(HEMATOCRIT) as HEMATOCRIT_min
, max(HEMATOCRIT) as HEMATOCRIT_max
, min(HEMOGLOBIN) as HEMOGLOBIN_min
, max(HEMOGLOBIN) as HEMOGLOBIN_max
, min(CARBOXYHEMOGLOBIN) as CARBOXYHEMOGLOBIN_min
, max(CARBOXYHEMOGLOBIN) as CARBOXYHEMOGLOBIN_max
, min(METHEMOGLOBIN) as METHEMOGLOBIN_min
, max(METHEMOGLOBIN) as METHEMOGLOBIN_max

-- chemistry
, min(CHLORIDE) as CHLORIDE_min
, max(CHLORIDE) as CHLORIDE_max
, min(CALCIUM) as CALCIUM_min
, max(CALCIUM) as CALCIUM_max
, min(TEMPERATURE) as TEMPERATURE_min
, max(TEMPERATURE) as TEMPERATURE_max
, min(POTASSIUM) as POTASSIUM_min
, max(POTASSIUM) as POTASSIUM_max
, min(SODIUM) as SODIUM_min
, max(SODIUM) as SODIUM_max
, min(LACTATE) as LACTATE_min
, max(LACTATE) as LACTATE_max
, min(GLUCOSE) as GLUCOSE_min
, max(GLUCOSE) as GLUCOSE_max

-- ventilation stuff that's sometimes input
-- , INTUBATED
-- , TIDALVOLUME
-- , VENTILATIONRATE
-- , VENTILATOR
-- , PEEP
-- , O2Flow
-- , REQUIREDO2

from stg3
where lastRowFiO2 = 1 -- only the most recent FiO2
-- restrict it to *only* arterial samples
--and (SPECIMEN = 'ART' or SPECIMEN_PROB > 0.75)
group by subject_id, hadm_id, icustay_id --, charttime
order by icustay_id;
