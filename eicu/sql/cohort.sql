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
, case when age = '> 89' then 0
      when age = '' then 0
      when cast(age as numeric) < 16 then 1
    else 0 end as exclusion_Over16
-- only include first icustay
, case when fs.type in ('1','2','3','4','5','6') then 0
    else 1 end as exclusion_readmission
, case when aiva.apachescore > 1 then 0 else 1 end as exclusion_NoAPACHEIV
, case when has_vit.numobs > 0 then 0 else 1 end as exclusion_VitalObservations
, case when has_lab.numobs > 0 then 0 else 1 end as exclusion_LabObservations
, case when has_med.numobs > 0 then 0 else 1 end as exclusion_MedObservations
-- excluded column aggregates all the above
, case
    when fs.type in ('1','2','3','4','5','6')
      and aiva.apachescore > 1
      and has_vit.numobs > 0
      and has_lab.numobs > 0
      and has_med.numobs > 0
    then 0
  else 1 end as excluded
from patient pt
-- check for apache values
left join (select patientunitstayid, max(apachescore) as apachescore from APACHEPATIENTRESULT where apacheversion = 'IVa' group by patientunitstayid) aiva
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
left join public.tpubfirststay fs
  on pt.patientunitstayid = fs.patientunitstayid

order by pt.patientunitstayid;
