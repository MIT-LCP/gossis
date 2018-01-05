# gossis
Extracting consistent concepts from multiple databases

## Adding variables

1. Add the info to `etc/variable-definitions.yaml`
2. Run `python3 variablelist2description.py`
3. Run `python3 variablelist2header.py`
4. Add the variable to each `load-data.ipynb` - sometimes this involves adding it to underlying SQL scripts as well
5. Re-run everything - if not available, the notebooks should prompt you about it
