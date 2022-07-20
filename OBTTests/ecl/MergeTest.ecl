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

#ONWARNING(4550, ignore);

// Tests the merge function from globalMerge.ecl

IMPORT DBSCAN;
IMPORT DBSCAN.Internal;
IMPORT DBSCAN.DBSCAN_Types;

MergeType := DBSCAN_Types.l_stage3;

Input1 := DATASET([{ 1, 2, 3, 4},  {1, 5, 3, 4}], MergeType);

Result1 := Internal.globalMerge.merge(Input1);
NumRows1 := COUNT(Result1);
Expected1 := 1;

// Both rows of the input have the same wi and id so there should only be one row
OUTPUT(IF(NumRows1 = Expected1, 'Pass', 'Fail: ' + NumRows1 + ' Rows'), NAMED('Test1'));


Input2 := DATASET([{ 1, 2, 3, 4}, {5, 2, 5, 2}, {5, 1, 5, 3}, {8, 2, 8, 4}], MergeType);

Result2 := Internal.globalMerge.merge(Input2);
NumRows2 := COUNT(Result2);
Expected2 := 3;

// Two Rows merge, leaving 3 rows
OUTPUT(IF(NumRows2 = Expected2, 'Pass', 'Fail: ' + NumRows2 + ' Rows'), NAMED('Test2'));


Input3 := DATASET([{6, 2, 8, 2}, {6, 1, 7, 3}], MergeType);

Result3 := Internal.globalMerge.merge(Input3);

// Since Result3[2] has a lower id value than Result3[1], it should have the lower label value
OUTPUT(IF(Result3[1].label > Result3[2].label, 'Pass', 'Fail'), NAMED('Test3'));
