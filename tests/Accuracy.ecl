/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */
IMPORT ML_Core;
IMPORT $.^ AS DBSCAN;
IMPORT $.datasets.frogDS_Small AS frog_data;
IMPORT $.datasets.blobsDS AS blobsDS;

/*
 * This test compares the results of HPCC DBSCAN against
 * sklearn's DBSCAN implementation on frogDS_Small dataset
 * using Euclidean distance metric.
 */

// Load frog_data
ds := frog_data.ds;
// Convert to NumericField
ML_Core.AppendSeqID(ds,id,dsID);
ML_Core.ToField(dsID,dsNF);
// Produce clustering result
clustering := DBSCAN.DBSCAN(0.3,10).fit(dsNF);
// Output clustering result
OUTPUT(clustering, NAMED('FIT'));
// Compare with sklearn results
sk_res := frog_data.sklearn_results;
ML_Core.AppendSeqID(sk_res,id,sk_res_id);
// Find rows that do not match the sklearn result
no_match := JOIN(clustering, sk_res_id,
                 LEFT.id=RIGHT.id and LEFT.label <> RIGHT.a+1,
                 TRANSFORM({ML_Core.Types.ClusterLabels,INTEGER sklabel},
                           SELF.sklabel := RIGHT.a,
                           SELF := LEFT));
// Ideally, the result must be as close to zero rows as possible,
// however, some mismatch is inevitable due to difference in traversal
// orders during parallel computation
// OUTPUT(no_match, NAMED('no_match'));
// OUTPUT(clustering(label = 5));
t := TABLE(clustering, {wi, label, cnt := COUNT(GROUP)}, wi, label);
OUTPUT(t);


/*
 * This test compares the results of HPCC DBSCAN against
 * sklearn's DBSCAN implementation on blobsDS dataset
 * using Chebyshev distance metric.
 */

// Load blobsDS dataset
blobs := blobsDS.trainRec;
// Convert to NumericField
ML_Core.ToField(blobs,recs);
// training set
trainNF := recs(number < 3);
// testing set
testNF := recs(number = 3);
// Produce clustering result
mod := DBSCAN.DBSCAN(0.3, 2, dist := 'chebyshev').fit(trainNF);
// Output clustering result
OUTPUT(mod, NAMED('mod'));

// Accuracy test : The result shows the accuracy of our results compared to SK_learn results.
evl := JOIN(mod, testNF,
            LEFT.wi = RIGHT.wi
            AND
            LEFT.id = RIGHT.id,
            TRANSFORM({UNSIGNED4 id, INTEGER ecl, INTEGER sk, BOOLEAN same},
                      SELF.same := IF(LEFT.label = (RIGHT.value + 1), TRUE, FALSE),
                      SELF.ecl := LEFT.label,
                      SELF.sk := RIGHT.value,
                      SELF := LEFT));
OUTPUT((1-COUNT(evl(same = FALSE))/COUNT(mod)), NAMED('evl'));
