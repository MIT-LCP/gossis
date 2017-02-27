-- This query gets the demographics of the patients per stay

DROP MATERIALIZED VIEW IF EXISTS demographics CASCADE;
CREATE materialized VIEW demographics AS
SELECT
  demo.subject_id, demo.hadm_id, demo.icustay_id

  , max(CASE WHEN label = 'WEIGHT' THEN valuenum ELSE null END) as WEIGHT
  , max(CASE WHEN label = 'HEIGHT' THEN valuenum ELSE null END) as HEIGHT
  , max(CASE WHEN label = 'PREGNANT' THEN valuenum ELSE null END) as PREGNANT
  , max(CASE WHEN label = 'SMOKING' THEN valuenum ELSE null END) as SMOKING

FROM
( -- begin query that extracts the data
  SELECT ie.subject_id, ie.hadm_id, ie.icustay_id
  -- here we assign labels to ITEMIDs
  -- this also fuses together multiple ITEMIDs containing the same data
  , CASE
        WHEN itemid = 3580 THEN 'WEIGHT' --very low decimal
	WHEN itemid = 763 THEN 'WEIGHT'  --reasonable value
	WHEN itemid = 3693 THEN 'WEIGHT' --low decimal
	WHEN itemid = 224639 THEN ' WEIGHT' --reasonable value
        WHEN itemid = 1394 THEN 'HEIGHT'
	WHEN itemid = 226707 THEN 'HEIGHT'
        WHEN itemid = 225082 THEN 'PREGNANT'
        WHEN itemid = 227687 THEN 'SMOKING' 
        WHEN itemid = 225108 THEN 'SMOKING'
      ELSE null
    END AS label
  , -- the values with sanity checks for non-flags to not be 0 nor negative, and flags to not be negative
    CASE
      WHEN itemid = 3580 and valuenum <=    0 THEN null -- kg 'WEIGHT'
      WHEN itemid = 763 and valuenum <= 0 THEN null -- kg 'WEIGHT'
      WHEN itemid = 3693 and valuenum <= 0 THEN null -- kg 'WEIGHT'
      WHEN itemid = 224639 and valuenum <= 0 THEN null -- kg 'WEIGHT'
      WHEN itemid = 1394 and valuenum <= 0 THEN null -- in 'HEIGHT'
      WHEN itemid = 226707 and valuenum <= 0 THEN null -- in 'HEIGHT'
      WHEN itemid = 225082 and valuenum < 0 THEN null -- flag 'PREGNANT'
      WHEN itemid = 227687 and valuenum < 0 THEN null -- flag 'SMOKING'
      WHEN itemid = 225108 and valuenum < 0 THEN null -- flag 'SMOKING'
      WHEN itemid = 225108 and valuenum = 1 THEN 2    -- flag 'SMOKING' if use = 1 then 2,  
						      -- if history = 1 and use = 0 then 1, if either = 0 then 0
    ELSE ce.valuenum
    END AS valuenum

  FROM icustays ie

  LEFT JOIN chartevents ce
    ON ce.subject_id = ie.subject_id AND ce.hadm_id = ie.hadm_id
    AND ce.ITEMID in
    (
      -- comment is: LABEL | UNITS | DBSOURCE 
      3580, -- PRESENT WEIGHT (KG) | KG | CAREVUE
      763, -- DAILY WEIGHT | KG | CAREVUE
      3693, -- WEIGHT KG | KG | CAREVUE
      224639, -- DAILY WEIGHT | KG | METAVISION
      1394, -- HEIGHT INCHES | IN | CAREVUE
      226707, -- HEIGHT | IN | METAVISION
      225082, -- PREGNANT | FLAG | METAVISION
      227687, -- TOBACCO USE HISTORY | FLAG | METAVISION
      225108 -- TOBACCO USE | FLAG | METAVISION
    )
    AND valuenum IS NOT null
) demo
GROUP BY demo.subject_id, demo.hadm_id, demo.icustay_id
ORDER BY demo.subject_id, demo.hadm_id, demo.icustay_id;

commit;
