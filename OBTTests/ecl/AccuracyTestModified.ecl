/*##############################################################################
    
    HPCC SYSTEMS software Copyright (C) 2022 HPCC Systems®.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
       
       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
############################################################################## */

// Modified version of the Accuracy test file that is 
// compatible with the OBT test system

IMPORT ML_Core;
IMPORT DBSCAN;
IMPORT DBSCAN.tests.datasets.frogDS_Small AS frog_data;
IMPORT DBSCAN.tests.datasets.blobsDS AS blobsDS;

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

// Compare with sklearn results
sk_res := frog_data.sklearn_results;

// Append an id field to sk_res
ML_Core.AppendSeqID(sk_res,id,sk_res_id);


// Find rows that do not match the sklearn result
no_match := JOIN(clustering, sk_res_id,
                 LEFT.id=RIGHT.id and LEFT.label <> RIGHT.a+1,
                 TRANSFORM({ML_Core.Types.ClusterLabels,INTEGER sklabel},
                           SELF.sklabel := RIGHT.a,
                           SELF := LEFT));
                           

// Test number of rows, allows for slight mismatch
OUTPUT(IF(COUNT(no_match) < 2, 'Pass',  'Fail: ' + COUNT(no_match) + ' Rows'), NAMED('Test1'));


/*
 * This test compares the results of HPCC DBSCAN against
 * sklearn's DBSCAN implementation on blobsDS dataset
 * using Chebyshev distance metric.
 */

// Load blobsDS dataset
blobs := blobsDS.trainRec;

// Convert to NumericField
ML_Core.ToField(blobs,recs);

// Training set (Independent Var)
trainNF := recs(number < 3);
// Testing set (Dependent Var)
testNF := recs(number = 3);

// Produce clustering result
mod := DBSCAN.DBSCAN(0.3, 2, dist := 'chebyshev').fit(trainNF);

// Accuracy test : The result shows the accuracy of our results compared to SK_learn results.
accuracy := JOIN(mod, testNF,
            LEFT.wi = RIGHT.wi
            AND
            LEFT.id = RIGHT.id,
            TRANSFORM({UNSIGNED4 id, INTEGER ecl, INTEGER sk, BOOLEAN same},
                      SELF.same := IF(LEFT.label = (RIGHT.value + 1), TRUE, FALSE),
                      SELF.ecl := LEFT.label,
                      SELF.sk := RIGHT.value,
                      SELF := LEFT));

// The same field should be true for each row (value of ecl = sk + 1)
NumDiffRows := COUNT(accuracy(same = FALSE));
OUTPUT(IF(NumDiffRows = 0, 'Pass', 'Fail: ' + NumDiffRows + ' Different Rows'), NAMED('Test2'));
