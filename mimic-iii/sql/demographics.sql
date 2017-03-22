-- This query gets the demographics of the patients per stay

DROP TABLE IF EXISTS gosiss_demographics CASCADE;
CREATE TABLE gosiss_demographics AS
with demo_stg as
(
  SELECT ie.subject_id, ie.hadm_id, ie.icustay_id
  -- here we assign labels to ITEMIDs
  -- this also fuses together multiple ITEMIDs containing the same data
  , CASE
    	WHEN itemid in (762, 763, 226512, 224639) THEN 'WEIGHT'
      WHEN itemid in (920, 1394, 226707) THEN 'HEIGHT'
      WHEN itemid = 225082 THEN 'PREGNANT'
      WHEN itemid = 227687 THEN 'SMOKING'
      WHEN itemid = 225108 THEN 'SMOKING'
    ELSE null
    END AS label
  , -- the values with sanity checks for non-flags to not be 0 nor negative, and flags to not be negative
    CASE
      -- rules for weight
      WHEN itemid in (762, 763, 226512, 224639)
        and (valuenum > 400 or valuenum < 20) THEN null
      -- rules for height
      WHEN itemid in (920, 1394, 226707)
        and (valuenum > 100 or valuenum < 10) THEN null
      WHEN itemid = 225082 and valuenum < 0 THEN null -- flag 'PREGNANT'
      -- smoking usage is coded as 0/1/2
       -- if never, 0
       -- if previous user, then 1
       -- if current user, then 2
      WHEN itemid = 227687 and valuenum < 0 THEN null
      WHEN itemid = 225108 and valuenum < 0 THEN null
      WHEN itemid = 225108 and valuenum = 1 THEN 2
    ELSE ce.valuenum
    END AS valuenum
  FROM icustays ie
  LEFT JOIN chartevents ce
    ON ie.icustay_id = ce.icustay_id
    AND ce.ITEMID in
    (
      -- CAREVUE - weight
      762, -- ADMISSION WEIGHT (KG) | CAREVUE
      763, -- DAILY WEIGHT | KG | CAREVUE

      -- many ITEMIDs are used for neonates, so not included here
      -- 3723 - birth weight
      -- 3580, -- PRESENT WEIGHT (KG) - used for neonates
      -- 3581 and 3582 are copies of 3580 for different units.
      -- 3693, -- Weight KG - but used for neonates

      -- METAVISION - weight
      226512, -- Admission Weight (Kg)
      224639, -- DAILY WEIGHT | KG | METAVISION

      -- CAREVUE - height
      920, -- Admission height (inches)
      1394, -- HEIGHT INCHES

      -- below used for neonates
      -- 3485, -- length calc (cm)
      -- 3486, -- length in inches
      -- 4187, -- length calc inches (but UOM in chartevents is cm) - data looks like inches
      -- 4188, -- length in cm (but UOM in chartevents is inches) - data looks like cm

      226707, -- HEIGHT | IN | METAVISION
      225082, -- PREGNANT | FLAG | METAVISION
      227687, -- TOBACCO USE HISTORY | FLAG | METAVISION
      225108 -- TOBACCO USE | FLAG | METAVISION
    )
    AND valuenum IS NOT null
    AND COALESCE(error,0)!=1
    AND ce.charttime < ie.intime + interval '1' day
)
, demo as
(
  select icustay_id
  , avg(CASE WHEN label = 'WEIGHT' THEN valuenum ELSE null END) as WEIGHT
  , avg(CASE WHEN label = 'HEIGHT' THEN valuenum ELSE null END) as HEIGHT
  , max(CASE WHEN label = 'PREGNANT' THEN valuenum ELSE null END) as PREGNANT
  , max(CASE WHEN label = 'SMOKING' THEN valuenum ELSE null END) as SMOKING
  from demo_stg
  group by icustay_id
)
, serv as
(
  select ie.icustay_id, se.curr_service as first_service
  , ROW_NUMBER() over (PARTITION BY ie.hadm_id ORDER BY se.transfertime DESC) as rn
  from icustays ie
  left join services se
    on ie.hadm_id = se.hadm_id
    and se.transfertime < ie.intime + interval '1' day
)
SELECT
  ie.subject_id, ie.hadm_id, ie.icustay_id
  , demo.WEIGHT
  , demo.HEIGHT
  , demo.PREGNANT
  , demo.SMOKING
  , serv.first_service
  , case when ROW_NUMBER() over (PARTITION BY ie.hadm_id ORDER BY ie.intime) > 1
      then 1
    else 0 end as readmission
FROM icustays ie
LEFT JOIN demo
  on ie.icustay_id = demo.icustay_id
LEFT JOIN serv
  on demo.icustay_id = serv.icustay_id
  and serv.rn = 1;
