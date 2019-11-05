# Build an ecl version of the Blobs Dataset for testing purposes.
# See: http://tiny.cc/be8fcz for details.
# To run:  python gen_blobsDS.py > ..\datasets\blobsDS.ecl

import numpy as np
from sklearn.cluster import DBSCAN
from sklearn import metrics
from sklearn.datasets.samples_generator import make_blobs
from sklearn.preprocessing import StandardScaler

centers = [[1, 1], [-1, -1], [1, -1]]
X, labels_true = make_blobs(n_samples=30, centers=centers, cluster_std=0.4,
                            random_state=0)

X = StandardScaler().fit_transform(X)

db = DBSCAN(eps=0.3,metric='chebyshev', metric_params=None, min_samples=2).fit(X)
labels = db.labels_

n_clusters_ = len(set(labels)) - (1 if -1 in labels else 0)
n_noise_ = list(labels).count(-1)

listdata = []
datarows = X.shape[0]
for i in range(datarows):
    row = [(i + 1)] + list(X[i]) + [labels[i]]
    listdata.append(row)

columnsOut = ['id', 'x', 'y', 'label']
outLines = []
line = 'EXPORT blobsDS := MODULE'
outLines.append(line)
line = '  EXPORT blobsRec := RECORD'
outLines.append(line)
datacolunms = len(columnsOut)
for i in range(datacolunms):
    field = columnsOut[i]
    if i == 0:
        line = '    UNSIGNED4 ' + field + ';'
    else:
        line = '    REAL ' + field + ';'
    outLines.append(line)
line = '  END;'
outLines.append(line)
outLines.append('')

line = '  EXPORT trainRec := DATASET(['
outLines.append(line)
outRecs = []
for rec in listdata:
    strRec = []
    for field in rec:
        strRec.append(str(field))
    line = '    {' + ','.join(strRec) + '}'
    outRecs.append(line)
outLines.append(',\n'.join(outRecs) + ']\n    ,' + 'blobsRec);')
outLines.append('')
outLines.append('END;')
print(outLines)