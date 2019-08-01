#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import os
import io
import boto3
import json
import csv
import pandas as pd
import numpy as np
from sagemaker import get_execution_role

ENDPOINT_NAME = '<nome-do-endpoint>' # endpoint criado em R
runtime= boto3.client('runtime.sagemaker', region_name='<region>') # Region é um param opcional


# In[ ]:


role = get_execution_role()
bucket='<s3-bucket-name>' # S3 bucket where test file is located
data_key = '<prefix>/<file-name.csv>' # S3 file name prefix + file name 
data_location = 's3://{}/{}'.format(bucket, data_key)
print(data_location)

data = pd.read_csv(data_location, header=None) # read test data from S3

test_y = ((data.iloc[:,0]) ).as_matrix();
test_X = data.iloc[:,1:].as_matrix();
test_X = test_X[0:500]
#print(test_y)
#print(test_X)


# In[ ]:


# Convert Array to CSV
def np2csv(arr):
    csv = io.BytesIO()
    np.savetxt(csv, arr, delimiter=',', fmt='%g')
    return csv.getvalue().decode().rstrip()


# In[ ]:


payload = np2csv(test_X) # Convertion

# Endpoint Call
response = runtime.invoke_endpoint(EndpointName=ENDPOINT_NAME,
                                   ContentType='text/csv',
                                   Body=payload) 

result = response['Body'].read().decode()
result_matrix = pd.DataFrame(np.array(result.split(",")))
#print(result_matrix)

# View
data_concat = pd.concat([result_matrix, data[0:500]], axis=1)
data_concat.columns = ["predicted_rings","rings","female","male","infant","length","diameter","height","whole_weight","shucked_weight","viscera_weight","shell_weight"]
print(data_concat)


# In[ ]:




