# convert from the .csv file to a single text file of headers
# this text file defines the header used to generate the GOSISS data
import yaml
import pandas as pd

# load yaml definitions
with open("variable-definitions.yaml", 'r') as stream:
    try:
        varlist = yaml.load(stream)
    except yaml.YAMLError as exc:
        print(exc)

# convert to dataframe
df = pd.DataFrame.from_dict(varlist, orient='index')
df['varname'] = df.index

# specify the order of the categories - data is output in this order
category_order = {'identifier': 1,
                  'demographic': 2,
                  'APACHE covariate': 3,
                  'vitals': 4,
                  'labs': 5,
                  'labs blood gas': 6,
                  'APACHE prediction': 10}
df['category_order'] = df['category'].map(category_order)

# columns to print
col_print = ['category','varname','unitofmeasure','dataType','description','example']

# sort df by the category, then by the variable name
df.sort_values(['category_order','varname'],inplace=True)

# output the data to csv
df[col_print].to_csv('GOSISS_VARIABLE_DEFINITIONS.csv',index=False)
