# GOSSIS: The Global Open Source Severity of Illness Score

For more information about the GOSSIS consortium, please visit https://gossis.mit.edu/

This repository is focused on the extraction part of the GOSSIS pipeline.  It extract consistent concepts from multiple databases.
Currently only the ANZICS and eICU-CRD datasets are used to build the GOSSIS-1 model.

For code used to compute GOSSIS predictions, please see: https://github.com/jraffa/rGOSSIS1

## Adding variables

1. Add the info to `etc/variable-definitions.yaml`
2. Run `python3 variablelist2description.py`
3. Run `python3 variablelist2header.py`
4. Add the variable to each `load-data.ipynb` - sometimes this involves adding it to underlying SQL scripts as well
5. Re-run everything - if not available, the notebooks should prompt you about it
