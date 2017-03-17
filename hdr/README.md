# Map from spreadsheet to header file

In this folder are three files:

* `GOSISS_VARIABLE_LIST - all variables.csv`
* `variablelist2header.py`
* `header.csv`

The first is downloaded from a Google Document, and is a manually curated spreadsheet of all the variables for GOSISS.
In particular, the second column is the final set of field names for GOSISS variables.

The `variablelist2header.py` python script pulls out this second column and outputs it to `header.csv`, removing any empty rows.

The `header.csv` file is used by ETL code to generate a dataset that has consistent column names.
It's also useful for identifying when a mapping for a particular dataset has not been completed.
