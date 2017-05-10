-- Create a table for the intubation cohort
-- This view only contains icustay_id which are included in the dataset
-- We require:
--    ventdurations

DROP TABLE IF EXISTS gosiss_cohort CASCADE;
CREATE TABLE gosiss_cohort as
-- get services associated with each hospital admission
with serv as
(
  select ie.hadm_id, curr_service as first_service
    , ROW_NUMBER() over (partition by ie.hadm_id order by transfertime DESC) as rn
  from icustays ie
  inner join services se
    on ie.hadm_id = se.hadm_id
    and se.transfertime < ie.intime + interval '1' day
)
, firsthr as
(
  select
    ie.icustay_id
    , min(ce.charttime) as intime_hr
    , max(ce.charttime) as outtime_hr
  from icustays ie
  inner join chartevents ce
    on ie.icustay_id = ce.icustay_id
    and ce.itemid in (211,220045)
    and ce.valuenum > 0
    and ce.charttime > ie.intime - interval '1' day
    and ce.charttime < ie.outtime + interval '1' day
    AND error IS DISTINCT FROM 1
  group by ie.icustay_id
)
, dnr as
(
  select icustay_id
  , min(case
      when value in
      (
          'Comfort Measures','Comfort measures only'
        , 'Do Not Intubate','DNI (do not intubate)','DNR / DNI'
        , 'Do Not Resuscita','DNR (do not resuscitate)','DNR / DNI'
      ) then charttime
    else null end) as dnrtime
  from chartevents
  where itemid in (128, 223758)
  -- exclude rows marked as error
  AND error IS DISTINCT FROM 1
  group by icustay_id
)
, tt as
(
select ie.subject_id, ie.hadm_id, ie.icustay_id
  , ie.intime
  , ie.outtime
  , fhr.intime_hr
  , fhr.outtime_hr
  , dnr.dnrtime
  , case when dnr.dnrtime is not null
      then extract(EPOCH from (dnr.dnrtime - fhr.intime_hr))/60.0/60.0/24.0
      else null end as dnrtime_days

  , se.first_service
  , round(cast(case when fhr.intime_hr > pat.dob + interval '199' year then 91.6
      else extract(EPOCH from (fhr.intime_hr - pat.dob))/60.0/60.0/24.0/365.242 end
      as numeric),2) as age

  , ROW_NUMBER() over (partition by ie.hadm_id order by fhr.intime_hr) as icustay_num
  , RANK() over (partition by ie.subject_id order by adm.admittime) as rn
  , pat.gender

from icustays ie
-- used later to filter out neonates and children
inner join patients pat
  on ie.subject_id = pat.subject_id
-- used later to filter out neonates and children
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
-- used later to filter out patients under certain services
inner join serv se
    on ie.hadm_id = se.hadm_id and se.rn = 1
-- get first instance of dnr
left join dnr
  on ie.icustay_id = dnr.icustay_id
left join firsthr fhr
  on ie.icustay_id = fhr.icustay_id
-- ORDER BY is important to ensure random() assigns same number to same row
ORDER BY ie.subject_id, ie.hadm_id, ie.icustay_id
)
select
    tt.subject_id, tt.hadm_id, tt.icustay_id
  , intime_hr
  , outtime_hr
  , case when icustay_num > 1 then 1 else 0 end as readmit

  -- used for exclusions --
  , age
  , gender
  , first_service
  , dnrtime_days

  -- exclusion flags --

  -- patient must have had heart rate data at some time during their stay
  , case when intime_hr is null then 1 else 0 end
      as exclusion_nodata

  -- only include first icustay
  , case when icustay_num > 1 then 1 else 0 end as exclusion_readmission
  -- remove non-adults
  , case when age < 16 then 1 else 0 end as exclusion_age
  -- -- not DNR in the first 4 hours
  -- , case
  --     when dnrtime_days < (4/24) then 1
  --   else 0 end
  --   as exclusion_dnr
  -- short stays <= 4 hours removed as done with APACHE
  , case
      when (outtime_hr - intime_hr) <  interval '4' hour then 1
    else 0 end
    as exclusion_shortstay
  , case
        when intime_hr is not null
        and icustay_num = 1
        and age >= 16
        and (outtime_hr - intime_hr) >= interval '4' hour
      then 0
      else 1
    end as excluded
from tt;
