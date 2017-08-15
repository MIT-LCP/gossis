-- extract vitals from nurse charting table

DROP TABLE IF EXISTS gossis_vital_nc_d1 CASCADE;
CREATE TABLE gossis_vital_nc_d1 as
-- create columns with only numeric data
with nc as
(
select
  patientunitstayid
  , nursingchartoffset
  , case
      when nursingchartcelltypevallabel = 'Heart Rate'
       and nursingchartcelltypevalname = 'Heart Rate'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as heartrate
  , case
      when nursingchartcelltypevallabel = 'Respiratory Rate'
       and nursingchartcelltypevalname = 'Respiratory Rate'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as RespiratoryRate
  , case
      when nursingchartcelltypevallabel = 'O2 Saturation'
       and nursingchartcelltypevalname = 'O2 Saturation'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as o2saturation
  , case
      when nursingchartcelltypevallabel = 'Non-Invasive BP'
       and nursingchartcelltypevalname = 'Non-Invasive BP Systolic'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as nibp_systolic
  , case
      when nursingchartcelltypevallabel = 'Non-Invasive BP'
       and nursingchartcelltypevalname = 'Non-Invasive BP Diastolic'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as nibp_diastolic
  , case
      when nursingchartcelltypevallabel = 'Non-Invasive BP'
       and nursingchartcelltypevalname = 'Non-Invasive BP Mean'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as nibp_mean
  , case
      when nursingchartcelltypevallabel = 'Temperature'
       and nursingchartcelltypevalname = 'Temperature (C)'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as temperature
  -- , case
  --     when nursingchartcelltypevallabel = 'Temperature'
  --      and nursingchartcelltypevalname = 'Temperature Location'
  --         then nursingchartvalue
  --     else null end
  --   as TemperatureLocation
  , case
      when nursingchartcelltypevallabel = 'Invasive BP'
       and nursingchartcelltypevalname = 'Invasive BP Systolic'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as ibp_systolic
  , case
      when nursingchartcelltypevallabel = 'Invasive BP'
       and nursingchartcelltypevalname = 'Invasive BP Diastolic'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as ibp_diastolic
  , case
      when nursingchartcelltypevallabel = 'Invasive BP'
       and nursingchartcelltypevalname = 'Invasive BP Mean'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as ibp_mean
  , case
      when nursingchartcelltypevallabel = 'Glasgow coma score'
       and nursingchartcelltypevalname = 'GCS Total'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      when nursingchartcelltypevallabel = 'Score (Glasgow Coma Scale)'
       and nursingchartcelltypevalname = 'Value'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as gcs

  -- other map fields
  , case
      when nursingchartcelltypevallabel = 'MAP (mmHg)'
       and nursingchartcelltypevalname = 'Value'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      when nursingchartcelltypevallabel = 'Arterial Line MAP (mmHg)'
       and nursingchartcelltypevalname = 'Value'
       and nursingchartvalue ~ '^[-]?[0-9]+[.]?[0-9]*$'
       and nursingchartvalue not in ('-','.')
          then cast(nursingchartvalue as numeric)
      else null end
    as map
  from nursecharting
  -- speed up by only looking at a subset of charted data
  where nursingchartcelltypecat in
  (
    'Vital Signs','Scores','Other Vital Signs and Infusions'
  )
  and nursingchartoffset > -60
  and nursingchartoffset < (60*24)
)
-- apply some preprocessing and apply min/max
, ncproc as
(
  select
    patientunitstayid
  -- lowest
  , min(case when heartrate > 0 and heartrate < 400 then heartrate else null end) as heartrate_min
  , min(case when RespiratoryRate > 0 and RespiratoryRate < 80 then RespiratoryRate else null end) as RespiratoryRate_min
  , min(case when o2saturation > 0 and o2saturation <= 100 then o2saturation else null end) as o2saturation_min
  , min(case when nibp_systolic > 0 and nibp_systolic < 400 then nibp_systolic else null end) as nibp_systolic_min
  , min(case when nibp_diastolic > 0 and nibp_diastolic < 400 then nibp_diastolic else null end) as nibp_diastolic_min
  , min(case when nibp_mean > 0 and nibp_mean < 400 then nibp_mean else null end) as nibp_mean_min
  , min(case when temperature > 20 and temperature < 50 then temperature else null end) as temperature_min
  , min(case when ibp_systolic > 0 and ibp_systolic < 400 then ibp_systolic else null end) as ibp_systolic_min
  , min(case when ibp_diastolic > 0 and ibp_diastolic < 400 then ibp_diastolic else null end) as ibp_diastolic_min
  , min(case when ibp_mean > 0 and ibp_mean < 400 then ibp_mean else null end) as ibp_mean_min
  , min(case when gcs > 2 and gcs < 16 then gcs else null end) as gcs_min
  , min(case when map > 0 and map < 400 then map else null end) as map_min
  -- highest
  , max(case when heartrate > 0 and heartrate < 400 then heartrate else null end) as heartrate_max
  , max(case when RespiratoryRate > 0 and RespiratoryRate < 80 then RespiratoryRate else null end) as RespiratoryRate_max
  , max(case when o2saturation > 0 and o2saturation <= 100 then o2saturation else null end) as o2saturation_max
  , max(case when nibp_systolic > 0 and nibp_systolic < 400 then nibp_systolic else null end) as nibp_systolic_max
  , max(case when nibp_diastolic > 0 and nibp_diastolic < 400 then nibp_diastolic else null end) as nibp_diastolic_max
  , max(case when nibp_mean > 0 and nibp_mean < 400 then nibp_mean else null end) as nibp_mean_max
  , max(case when temperature > 20 and temperature < 50 then temperature else null end) as temperature_max
  , max(case when ibp_systolic > 0 and ibp_systolic < 400 then ibp_systolic else null end) as ibp_systolic_max
  , max(case when ibp_diastolic > 0 and ibp_diastolic < 400 then ibp_diastolic else null end) as ibp_diastolic_max
  , max(case when ibp_mean > 0 and ibp_mean < 400 then ibp_mean else null end) as ibp_mean_max
  , max(case when gcs > 2 and gcs < 16 then gcs else null end) as gcs_max
  , max(case when map > 0 and map < 400 then map else null end) as map_max
  from nc
  group by patientunitstayid
)
select
  patientunitstayid
  , heartrate_min
  , heartrate_max
  , RespiratoryRate_min as resprate_min
  , RespiratoryRate_max as resprate_max
  , o2saturation_min as spo2_min
  , o2saturation_max as spo2_max
  , temperature_min as temp_min
  , temperature_max as temp_max
  , ibp_systolic_min as sysbp_invasive_min
  , ibp_systolic_max as sysbp_invasive_max
  , ibp_diastolic_min as diasbp_invasive_min
  , ibp_diastolic_max as diasbp_invasive_max
  , ibp_mean_min as mbp_invasive_min
  , ibp_mean_max as mbp_invasive_max

  , nibp_systolic_min as sysbp_noninvasive_min
  , nibp_systolic_max as sysbp_noninvasive_max
  , nibp_diastolic_min as diasbp_noninvasive_min
  , nibp_diastolic_max as diasbp_noninvasive_max
  , nibp_mean_min as mbp_noninvasive_min
  , nibp_mean_max as mbp_noninvasive_max

  -- any blood pressure, prioritize invasive
  , coalesce(ibp_mean_min,nibp_mean_min) as mbp_min
  , coalesce(ibp_mean_max,nibp_mean_max) as mbp_max

  , gcs_min, gcs_max
from ncproc
order by patientunitstayid;
