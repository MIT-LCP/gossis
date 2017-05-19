-- Create a table of exclusions for eICU patients in the GOSISS project

DROP TABLE IF EXISTS gosiss_cohort CASCADE;
CREATE TABLE gosiss_cohort as
with has_lab as
(
  select pt.hospitalid, pt.hospitaldischargeyear
    , count(labresultoffset) as numobs
  from patient pt
  inner join lab
    on pt.patientunitstayid = lab.patientunitstayid
  group by pt.hospitalid, pt.hospitaldischargeyear
)
, has_vit as
(
  select pt.hospitalid, pt.hospitaldischargeyear
    , count(observationoffset) as numobs
  from patient pt
  inner join vitalperiodic vp
    on pt.patientunitstayid = vp.patientunitstayid
  group by pt.hospitalid, pt.hospitaldischargeyear
)
, has_med as
(
  select pt.hospitalid, pt.hospitaldischargeyear
    , count(drugorderoffset) as numobs
  from patient pt
  inner join medication med
    on pt.patientunitstayid = med.patientunitstayid
  group by pt.hospitalid, pt.hospitaldischargeyear
)
select pt.PATIENTUNITSTAYID

-- TODO: compare these readmission flags
, apv.readmit as readmission_apache
-- there may be some other ways of defining readmit
, case when fs.type in ('1','2','3','4','5','6') then 0
else 1 end as readmission_jesse
, case
when apv.patientunitstayid is null then null
when ROW_NUMBER() over (PARTITION BY apv.patientunitstayid ORDER BY pt.hospitaldischargeoffset DESC)
  > 1 then 1
else 0 end as readmission_status
, case when aiva.apachescore > 1 and aiva.predictedhospitalmortality = -1 then 1 else 0 end readmission_apache_pred

-- EXCLUSION FLAGS --
, case when pt.age = '> 89' then 0
      when pt.age = '' then 0
      when cast(pt.age as numeric) < 16 then 1
    else 0 end as exclusion_Over16
-- missing hospital death outcome
, case
    when coalesce(pt.hospitaldischargestatus,'') = '' then 1
  else 0 end as exclusion_missingoutcome
-- APACHE score only exists for first hospital stay
, case when aiva.apachescore > 1 then 0 else 1 end as exclusion_np_apache_score
, case when aiva.predictedhospitalmortality > 0 then 0 else 1 end as exclusion_no_apache_pred
, case when has_vit.numobs > 0 then 0 else 1 end as exclusion_VitalObservations
, case when has_lab.numobs > 0 then 0 else 1 end as exclusion_LabObservations
, case when has_med.numobs > 0 then 0 else 1 end as exclusion_MedObservations

-- excluded column aggregates all the above
, case
     when (pt.age = '> 89' or pt.age = '' or cast(pt.age as numeric) >= 16)
      and coalesce(pt.hospitaldischargestatus,'') != ''
      and aiva.apachescore > 1
      and aiva.predictedhospitalmortality > 0
      and has_vit.numobs > 0
      and has_lab.numobs > 0
      and has_med.numobs > 0
    then 0
  else 1 end as excluded
from patient pt

-- check for apache values
left join (select patientunitstayid, max(apachescore) as apachescore, min(cast(predictedhospitalmortality as numeric)) as predictedhospitalmortality from APACHEPATIENTRESULT where apacheversion = 'IVa' group by patientunitstayid) aiva
  on pt.patientunitstayid = aiva.patientunitstayid

-- check for the hospital having any vitals
left join has_vit
  on pt.hospitalid = has_vit.hospitalid
  and pt.hospitaldischargeyear = has_vit.hospitaldischargeyear

-- check for the hospital having any labs
left join has_lab
  on pt.hospitalid = has_lab.hospitalid
  and pt.hospitaldischargeyear = has_lab.hospitaldischargeyear

-- check for the hospital having any meds
left join has_med
  on pt.hospitalid = has_med.hospitalid
  and pt.hospitaldischargeyear = has_med.hospitaldischargeyear

-- filter to first stay
left join apachepredvar apv
  on pt.patientunitstayid = apv.patientunitstayid

-- filter to first stay
left join public.tpubfirststay fs
  on pt.patientunitstayid = fs.patientunitstayid

order by pt.patientunitstayid;
