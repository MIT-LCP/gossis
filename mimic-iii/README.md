# MIMIC-III concepts

This code extracts concepts for GOSISS from MIMIC-III. You will need an instance of PostgreSQL v9.4 or higher with the MIMIC-III v1.4 database installed, along with privileges necessary to create materialized views.

Run the scripts in the following order:

```
\i sql/cohort.sql
\i sql/gcs-first-day.sql
\i sql/labs-first-day.sql
\i sql/urine-output-first-day.sql
\i sql/ventilation-durations.sql
\i sql/vitals-first-day.sql
\i sql/bg-first-day.sql

\i sql/apsiii.sql
```


