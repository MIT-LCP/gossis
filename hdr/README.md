# Map from spreadsheet to header file

In this folder are three files:

* `variable-definitions.yaml`
* `variablelist2description.py`
* `GOSSIS_VARIABLE_DEFINITIONS.csv`
* `variablelist2header.py`
* `header.csv`

The `variablelist2description.py` generates the `GOSSIS_VARIABLE_DEFINITIONS.csv` file from the `variable-definitions.yaml` file.

The `variablelist2header.py` python script generates `header.csv` from the `GOSSIS_VARIABLE_DEFINITIONS.csv` file, removing any empty rows.

The `header.csv` file is used by ETL code to generate a dataset that has consistent column names.
It's also useful for identifying when a mapping for a particular dataset has not been completed.
