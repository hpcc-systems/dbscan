/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */
IMPORT ML_Core;
IMPORT ML_Core.Types AS Types;
IMPORT $.DBSCAN_Types AS Files;
IMPORT Std.system.Thorlib;
IMPORT $.internal.locCluster;
IMPORT $.internal.globalMerge;

/**
  * Scalable Parallel DBSCAN Clustering Algorithm Implementation based on [1].
  * It's an extension of the original DBSCAN algorithm [2] to meet the challenge
  * of clustering problems on the Big Data platforms such as HPCC Systems.
  *
  * Based on the algorithm, this implementation has three stages: 1. Data preparation,
  * 2. Local clustering, 3. Global Merge. The details of stage 2 and 3 can be found in
  * the /internal/locCluster.ecl and /internal/globalMerge.ecl.
  *
  * Reference
  * [1] Patwary, Mostofa Ali, et al. "A new scalable parallel DBSCAN algorithm using the
  * disjoint-set data structure." Proceedings of the International Conference on High
  * Performance Computing, Networking, Storage and Analysis. IEEE Computer Society Press, 2012.
  * [2] Ester, Martin, et al. "A density-based algorithm for discovering clusters in large
  * spatial databases with noise." Kdd. Vol. 96. No. 34. 1996.
  *
  * @param eps  the maximum distance threshold to be considered as a neighbor of the other.
  *             Default value is 0.0.
  * @param minPts the minimum number of points required for a point to become a core point.
  *             Default value is 2.
  * @param dist a string describing the distance metrics used to calcualte the distance
  *             between a paire of points. Default value is 'euclidean'. Other supported
  *             distance metrics includes 'cosine','haversine', 'chebyshev', 'manhattan',
  *             'minkowski'.
  * @param dist_params a set of parameters for distance metrics that need exta setup.
  *                    Default value is [] which should fit for most cases.
  */
EXPORT DBSCAN(REAL8 eps = 0.0,
                  UNSIGNED4 minPts = 2,
                      STRING dist = 'euclidian',
                          SET OF REAL8 dist_params = []):= MODULE

  /**
  * Fit function performs DBSCAN clustering on a dataset (ds) to find clusters and the cluster
  * index (Label) of each sample in the dataset.
  *
  * @param ds  The dataset in NumericField format to be clustered.
  * @return result in ML_Core.Types.ClusterLabels format describing the cluster index of
  * each sample.
  * @see ML_Core.Types.NumericField, ML_Core.Types.ClusterLabels
  */
  EXPORT DATASET(ML_Core.Types.ClusterLabels) fit(DATASET(Types.NumericField) ds) := FUNCTION

    //Stage 1: Transform and distribute input dataset ds for local clustering in stage 2.
    //Evenly distribute the data
    Xnf1 := DISTRIBUTE(ds, id);
    //Transform to 1_stage1
    // We use NOCOMBINE here to prevent the PROJECT being combined with the DISTRIBUTE resulting in
    // an incorrect assignment of nodeId.
    X0 := PROJECT(NOCOMBINE(Xnf1), TRANSFORM(
                                  Files.l_stage1,
                                  SELF.fields := [LEFT.value],
                                  SELF.nodeId := Thorlib.node(),
                                  SELF := LEFT),
                                  LOCAL);
    X1 := SORT(X0, wi, id, number, LOCAL);
    X2 := ROLLUP(X1, TRANSFORM(
                                Files.l_stage1,
                                SELF.fields := LEFT.fields + RIGHT.fields,
                                SELF := LEFT),
                                wi, id,
                                LOCAL);
    //Transform to l_stage2
    X3 := PROJECT(X2, TRANSFORM(
                                Files.l_stage2,
                                SELF.parentID := LEFT.id,
                                SELF := LEFT),
                                LOCAL);
    //Braodcast for local clustering.
    X := DISTRIBUTE(X3, ALL);

    //Stage 2: local clustering on each node
    rds := locCluster.locDBSCAN(X, eps := eps, minPts := minPts,
                                                  distance_func := dist, params := dist_params);

    //Stage 3: global merge the local clustering results to the final clustering result
    clusters := globalMerge.Merge(rds);

    //Return the cluster index of each sample
    RETURN clusters;
  END;//end fit()
  /**
    * Num_Clusters
    *
    * Provides the number of clusters that the given dataset will be divided into
    * when clustered by the DBSCAN algorithm.
    *
    * @param ds A dataset with cluster index information. Usually it's the result of Fit function.
    * @return DATASET(l_num_clusters) The number of clusters, per work item.
    * @see DBSCAN_Types.l_num_clusters
    */
  EXPORT DATASET(Files.l_num_clusters) Num_Clusters(DATASET(ML_Core.Types.ClusterLabels) ds) := FUNCTION
    //Find maxmimum label of X samples per work item
    result0 := TABLE(ds,{wi,num:=MAX(GROUP,label)},wi);
    //Project to match return type
    result1 := PROJECT(result0, TRANSFORM(Files.l_num_clusters,
                                          SELF.wi := LEFT.wi,
                                          SELF.num := LEFT.num));
    RETURN result1;
  END;//end Num_Clusters()
  /**
    * Num_Outliers
    *
    * Provides the number of outliers that the given dataset will have
    * when clustered by the DBSCAN algorithm.
    *
    * @param ds A dataset with cluster index information. Usually it's the result of Fit function.
    * @return DATASET(l_num_clusters) The number of outliers, per work item.
    * @see DBSCAN_Types.l_num_clusters
    */
  EXPORT DATASET(Files.l_num_clusters) Num_Outliers(DATASET(ML_Core.Types.ClusterLabels) ds) := FUNCTION
    //Find number of outliers per work item
    outliers := TABLE(ds(label=0),{wi,num:=COUNT(GROUP)},wi);
    //Project to match return type
    result := PROJECT(outliers, TRANSFORM(Files.l_num_clusters,
                                          SELF.wi := LEFT.wi,
                                          SELF.num := LEFT.num));
    RETURN result;
  END;//end Num_Outliers()

END;//end DBSCAN
