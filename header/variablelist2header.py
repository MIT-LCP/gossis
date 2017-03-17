# convert from the .csv file to a single text file of headers
# this text file defines the header used to generate the GOSISS data
import os
import pandas as pd


df = pd.read_csv('GOSISS_VARIABLE_LIST - all variables.csv',header=0)

hdr = df['Final field name'].dropna()
# all variables are lower case
hdr = hdr.apply(lambda x: x.lower())

# write out to file
hdr.to_csv('header.csv',index=False,header=None)


