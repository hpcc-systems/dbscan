/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */
IMPORT ML_Core;
IMPORT $.^ AS DBSCAN;
IMPORT $.datasets.frogDS_Small AS frog_data;

// Test to confirm that multiple work items are evaluated separately and
// independently

ds := frog_data.ds;

ML_Core.AppendSeqID(ds,id,dsID);
ML_Core.ToField(dsID,dsNF);

wi1 := PROJECT(dsNF, TRANSFORM(ML_Core.Types.NumericField,SELF.wi := 1, SELF := LEFT));
wi2 := PROJECT(dsNF, TRANSFORM(ML_Core.Types.NumericField,SELF.wi := 2, SELF := LEFT));
test := wi1 + wi2;

clustering := DBSCAN.DBSCAN(0.3,10).fit(test);

OUTPUT(clustering,NAMED('Final'));

// Extract records which have not produced the same results for different wi
// eval must have zero records

eval := JOIN(clustering(wi=1),clustering(wi=2),
             LEFT.id=RIGHT.id and LEFT.label <> RIGHT.label,
             TRANSFORM(RECORDOF(clustering),
                       SELF.wi := LEFT.wi,
                       SELF.id := LEFT.id,
                       SELF.label := LEFT.label));

OUTPUT(eval,NAMED('eval'));
