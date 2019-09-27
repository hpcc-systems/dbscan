/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */
IMPORT ML_Core;
IMPORT ML_Core.Types as Types;

/*
 * This module contains Type definitions required for the internal calculations performed
 * within the DBSCAN module.
 */

EXPORT DBSCAN_Types := MODULE
    /**
      * l_stage1 extends NumericField by adding a nodeID field and a fields field for the data
      * preparation of stage 2 local clustering.
      * The nodeID field records the physical cluster node to which the data point is assigned to.
      * The fields filed allows each data point to be stored as a vector for embeded
      * C++ computing at stage 2.
      *
      * @field wi The work-item identifier for this cell.
      * @field id The record-identifier for this cell.
      * @field number The field number (i.e. featureId) of this cell.
      * @field value The numerical value of this cell.
      * @field nodeID The physical cluster node to which the data point is assigned to.
      *               It's 0-based index by default.
      * @field fields The SET of feature values of each data point. It's similar to the
      *               vector definition in C++.
      * @see ML_Core.Types.NumericField.
      */
    EXPORT l_stage1 := RECORD(Types.NumericField)
        UNSIGNED4 nodeId;
        SET OF REAL4 fields;
    END;
    /**
      * l_stage2 is the data strucuture for the local clustering of locDBSCAN() function.
      *
      * @field wi The work-item identifier for this cell.
      * @field id The record-identifier for this cell.
      * @field parentID the largest core points a data point belongs to.
      * @field nodeID The physical cluster node to which the data point is assigned to.
      * @field fields The SET of feature values of each data point. It's similar to the vector
      *               definition in C++.
      * @field if_local TRUE if the data point is physically located at the current cluster.
      *                 Otherwise FALSE.
      * @field if_core TRUE if the data point is a core point. Otherwise FALSE.
      */
    EXPORT l_stage2 := RECORD
        Types.NumericField.wi;
        Types.NumericField.id;
        Types.t_RecordID parentID;
        UNSIGNED nodeId;
        SET OF REAL4 fields;
        BOOLEAN if_local := FALSE;
        BOOLEAN if_core := FALSE;
    END;
    /**
      * l_stage3 is the data strucuture for global merging of globalMerge() function.
      *
      * @field wi The work-item identifier for this cell.
      * @field id The record-identifier for this cell.
      * @field parentID the largest core points a data point belongs to.
      * @field nodeID The physical cluster node it's located. It's 0-based index by default.
      * @field if_local TRUE if the data point is physically located at the current cluster.
      *                 Otherwise FALSE.
      * @field if_core TRUE if the data point is a core point. Otherwise FALSE.
      * @see ML_Core.Types.NumericField.
      */
    EXPORT l_stage3 := RECORD
      UNSIGNED4 wi;
      UNSIGNED4 nodeid;
      UNSIGNED4 id;
      UNSIGNED4 parentID;
      BOOLEAN   if_local := FALSE;
      BOOLEAN   if_core := FALSE;
    END;
    /**
      * l_num_clusters
      *
      * This record structure holds the results of functions that return statistics
      * about the clusters formed in DBSCAN clustering, that is, it is the result
      * structure for num_clusters and num_outliers.
      *
      * It contains the value of the statistic, per work-item
      *
      * @field wi The work-item identifier
      * @field num The value of the statistic (Number of clusters / outliers)
      */
    EXPORT l_num_clusters := RECORD
        UNSIGNED4 wi;
        UNSIGNED4 num;
    END;

END;
