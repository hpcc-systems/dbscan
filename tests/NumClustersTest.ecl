
/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */IMPORT ML_Core;
IMPORT $.^ AS DBSCAN;
IMPORT $.datasets.frogDS_Small AS frog_data;

// Test to check the Num_clusters function

ds := frog_data.ds;

ML_Core.AppendSeqID(ds,id,dsID);
ML_Core.ToField(dsID,dsNF);

mod := DBSCAN.DBSCAN(0.3,10).Fit(dsNF);

NumberOfClusters := DBSCAN.DBSCAN().Num_Clusters(mod);
NumberOfOutliers := DBSCAN.DBSCAN().Num_Outliers(mod);

OUTPUT(NumberOfClusters, NAMED('NumberOfClusters'));
OUTPUT(NumberOfOutliers, NAMED('NumberOfOutliers'));