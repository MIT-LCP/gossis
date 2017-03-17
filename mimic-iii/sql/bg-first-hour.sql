-- The aim of this query is to pivot entries related to blood gases and
-- chemistry values which were found in LABEVENTS

DROP TABLE IF EXISTS gosiss_bg_h1 CASCADE;
CREATE TABLE gosiss_bg_h1 AS
with oxy_stg as
(
  select bg.icustay_id, bg.charttime
  -- calculate score for all blood gases
  , po2 as pao2
  , pco2 as paco2
  , fio2
  , aado2
  , case
      when PO2 is null and AaDO2 is null
        then null
      when fio2 >= 0.5 and AaDO2 is not null then
        case
          when AaDO2 <  100 then 0
          when AaDO2 <  250 then 7
          when AaDO2 <  350 then 9
          when AaDO2 <  500 then 11
          when AaDO2 >= 500 then 14
        else 0 end
      -- here we make an implicit assumption that no fio2 obs means fio2 < 0.5
      when PO2 is not null then
        case
          when PO2 < 50 then 15
          when PO2 < 70 then 5
          when PO2 < 80 then 2
        else 0 end
      else null
    end as oxygenation_score
  from gosiss_bg bg
  where specimen_pred = 'ART'
  and (po2 is not null or aado2 is not null)
)
, oxy_score as
(
  select
    icustay_id, charttime
    , pao2, paco2, fio2, aado2
    , oxygenation_score
    , ROW_NUMBER() OVER (PARTITION BY icustay_id ORDER BY oxygenation_score desc)
        as rn
  from oxy_stg
)
-- because ph/pco2 rules are an interaction *within* a blood gas, we calculate them here
-- the worse score is then taken for the final calculation
, acidbase as
(
  select bg.icustay_id
  , ph
  , pco2 as paco2
  , case
      when ph is null or pco2 is null then null
      when ph < 7.20 then
        case
          when pco2 < 50 then 12
          else 4
        end
      when ph < 7.30 then
        case
          when pco2 < 30 then 9
          when pco2 < 40 then 6
          when pco2 < 50 then 3
          else 2
        end
      when ph < 7.35 then
        case
          when pco2 < 30 then 9
          when pco2 < 45 then 0
          else 1
        end
      when ph < 7.45 then
        case
          when pco2 < 30 then 5
          when pco2 < 45 then 0
          else 1
        end
      when ph < 7.50 then
        case
          when pco2 < 30 then 5
          when pco2 < 35 then 0
          when pco2 < 45 then 2
          else 12
        end
      when ph < 7.60 then
        case
          when pco2 < 40 then 3
          else 12
        end
      else -- ph >= 7.60
        case
          when pco2 < 25 then 0
          when pco2 < 40 then 3
          else 12
        end
    end as acidbase_score
  from gosiss_bg bg
  where ph is not null and pco2 is not null
  and specimen_pred = 'ART'
)
, ab_score as
(
  select icustay_id, acidbase_score, ph, paco2
    -- create integer which indexes maximum value of score with 1
  , ROW_NUMBER() over (partition by ICUSTAY_ID ORDER BY ACIDBASE_SCORE DESC)
      as rn
  from acidbase
)
select ie.subject_id, ie.hadm_id, ie.icustay_id
-- aggregation functions here are just cosmetic
-- the join has "rn=1" which ensures only 1 row exists
, min(oxy_score.pao2) as aps3_oxy_pao2
, min(oxy_score.paco2) as aps3_oxy_paco2
, min(oxy_score.fio2) as aps3_oxy_fio2
, min(oxy_score.aado2) as aps3_oxy_aado2
, min(oxy_score.oxygenation_score) as oxygenation_score

, min(ab_score.ph) as aps3_acidbase_ph
, min(ab_score.paco2) as aps3_acidbase_paco2
, min(ab_score.acidbase_score) as acidbase_score

-- oxygenation parameters
, min(bg.po2) as pao2_min
, max(bg.po2) as pao2_max
, min(bg.pco2) as paco2_min
, max(bg.pco2) as paco2_max
, min(bg.pao2fio2) as pao2fio2_min
, max(bg.pao2fio2) as pao2fio2_max
, min(coalesce(bg.aado2, bg.aado2_calc)) as aado2_min
, max(coalesce(bg.aado2, bg.aado2_calc)) as aado2_max

-- acid-base parameters
, min(bg.PH) as PH_min
, max(bg.PH) as PH_max

, min(bg.BASEEXCESS) as BASEEXCESS_min
, max(bg.BASEEXCESS) as BASEEXCESS_max
, min(bg.BICARBONATE) as BICARBONATE_min
, max(bg.BICARBONATE) as BICARBONATE_max
, min(bg.TOTALCO2) as TOTALCO2_min
, max(bg.TOTALCO2) as TOTALCO2_max

-- blood count parameters
, min(bg.HEMATOCRIT) as HEMATOCRIT_min
, max(bg.HEMATOCRIT) as HEMATOCRIT_max
, min(bg.HEMOGLOBIN) as HEMOGLOBIN_min
, max(bg.HEMOGLOBIN) as HEMOGLOBIN_max
, min(bg.CARBOXYHEMOGLOBIN) as CARBOXYHEMOGLOBIN_min
, max(bg.CARBOXYHEMOGLOBIN) as CARBOXYHEMOGLOBIN_max
, min(bg.METHEMOGLOBIN) as METHEMOGLOBIN_min
, max(bg.METHEMOGLOBIN) as METHEMOGLOBIN_max

-- chemistry
, min(bg.CHLORIDE) as CHLORIDE_min
, max(bg.CHLORIDE) as CHLORIDE_max
, min(bg.CALCIUM) as CALCIUM_min
, max(bg.CALCIUM) as CALCIUM_max
, min(bg.TEMPERATURE) as TEMPERATURE_min
, max(bg.TEMPERATURE) as TEMPERATURE_max
, min(bg.POTASSIUM) as POTASSIUM_min
, max(bg.POTASSIUM) as POTASSIUM_max
, min(bg.SODIUM) as SODIUM_min
, max(bg.SODIUM) as SODIUM_max
, min(bg.LACTATE) as LACTATE_min
, max(bg.LACTATE) as LACTATE_max
, min(bg.GLUCOSE) as GLUCOSE_min
, max(bg.GLUCOSE) as GLUCOSE_max

-- ventilation stuff that's sometimes input
-- , INTUBATED
-- , TIDALVOLUME
-- , VENTILATIONRATE
-- , VENTILATOR
-- , PEEP
-- , O2Flow
-- , REQUIREDO2

from icustays ie
left join gosiss_bg bg
  on ie.icustay_id = bg.icustay_id
  -- restrict it to *only* arterial samples
  and bg.specimen_pred = 'ART'
left join ab_score
  on ie.icustay_id = ab_score.icustay_id
  and ab_score.rn = 1
left join oxy_score
  on ie.icustay_id = oxy_score.icustay_id
  and oxy_score.rn = 1
group by ie.subject_id, ie.hadm_id, ie.icustay_id
order by ie.icustay_id;
