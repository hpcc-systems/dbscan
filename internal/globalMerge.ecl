/*##############################################################################
## HPCC SYSTEMS software Copyright (C) 2019 HPCC Systems.  All rights reserved.
############################################################################## */
IMPORT $.^.DBSCAN_Types AS Files;
IMPORT ML_Core;
IMPORT Std.system.Thorlib;

/**
  * globalMerge Module
  *
  * This module implements the stage 3 of the scalalbe and parallel DBSCAN algorithm [1].
  * It merges the results from each node in stage 2 local clustering. It results in
  * a synchronized cluster index for each data point.
  * The cluster index is 1-based and the outliers are indexed as 0.
  *
  * Reference
  * [1] Patwary, Mostofa Ali, et al. "A new scalable parallel DBSCAN algorithm using the
  * disjoint-set data structure." Proceedings of the International Conference on High
  * Performance Computing, Networking, Storage and Analysis. IEEE Computer Society Press, 2012.
  */
EXPORT globalMerge := MODULE

  //Layout for Ultimate function and Loop_Func fuction
  SHARED  l_ultimate := RECORD
    UNSIGNED4 wi;
    UNSIGNED4 id;
    UNSIGNED4 parentID;        // the largest core point a data point belongs locally
    UNSIGNED4 largestID := 0;  // the largest parentID of each data point among all local results
    UNSIGNED4 ultimateID := 0; // the current cluster index
  END;
  //Ultimate function updates the largest parentID and the cluster index of each data point.
  //It takes the dataset inl_utimate format and the number of data points in the dataset as input.
  SHARED STREAMED DATASET(l_ultimate) ultimate(STREAMED DATASET(l_ultimate) dsin,
                                                  UNSIGNED4 pointcount) := EMBED(C++:activity)
    #include <stdio.h>
    // The struct for each data point
    struct upt
    {
      uint32_t wi;
      uint32_t id;
      uint32_t pid; //parentID
    };

    class MyStreamInlineDataset : public RtlCInterface, implements IRowStream
      {
        public:
          MyStreamInlineDataset(IEngineRowAllocator * _resultAllocator,
                                              IRowStream * _ds, uint32_t _pc)
            :resultAllocator(_resultAllocator), ds(_ds), pc(_pc)
            {
              uptable = (upt*) rtlMalloc(pc * sizeof(upt));
              for(uint32_t i = 0; i < pc; i++)
              {
                uptable[i].wi = 0;
                uptable[i].id = 0;
                uptable[i].pid = 0;
              };
              calculated = false;
              rc = 0;
              lastgroupend = 0;
              curWi = 0;
              lastid = 0;
            }
            ~MyStreamInlineDataset()
            {
              rtlFree(uptable);
            }

          RTLIMPLEMENT_IINTERFACE
          //calculate the ultimate id
          virtual const void *nextRow() override
          {
            if(!calculated)
            {
              // read in the input dataset into a table
              while(true)
              {
                const byte * next = (const byte *)ds->nextRow();
                if (!next) break;
                const byte * pos = next;
                uint32_t wi = *(uint32_t*)pos;
                pos += sizeof(uint32_t);
                uint32_t id = *(uint32_t*)pos;
                pos += sizeof(uint32_t);
                uint32_t pid = *(uint32_t *) pos;
                if(curWi == 0){
                  curWi = wi;
                }
                if(curWi != wi)
                {
                  curWi = wi;
                  lastgroupend = lastid;
                }
                id += lastgroupend;
                pid += lastgroupend;
                if (id > 0 && id <= pc)
                {
                  uptable[id -1].wi = wi;
                  uptable[id -1].id = id;
                  uptable[id -1].pid = pid;
                }
                lastid = id;
                rtlReleaseRow(next);
              }// End while()
              // update the parentID
              for(uint32_t i = 0; i < pc; i++)
              {
                uint32_t wi = uptable[i].wi;
                uint32_t id = uptable[i].id;
                uint32_t pid = uptable[i].pid;
                if(id == 0) continue;
                while(id != pid)
                {
                  id = pid;
                  if(pid - 1  >= pc){
                    break;
                  }
                  if(uptable[pid -1].pid == 0 || uptable[pid -1].wi != wi)
                  {
                    break;
                  }else{
                    pid = uptable[pid -1].pid;
                  }
                }
                uptable[i].pid = pid;
              };// end for()

              calculated = true;
              lastgroupend = 0;
              curWi = 0;
              lastid = 0;
            }//end if(!calculated)
            //output the result
            byte* row;
            RtlDynamicRowBuilder rowBuilder(resultAllocator);
            uint32_t returnsize = 5*sizeof(uint32_t);
            while(rc < pc && uptable[rc].id == 0){ rc++;}
            if(rc < pc)
            {
              row = rowBuilder.ensureCapacity(returnsize, NULL);
              void * pos = row;
              uint32_t id = uptable[rc].id;
              uint32_t pid = uptable[rc].pid;
              uint32_t wi = uptable[rc].wi;

              if(curWi == 0)
              {
                curWi = wi;
              }
              if(curWi != wi)
              {
                curWi = wi;
                lastgroupend = lastid;
              }
              id = id - lastgroupend;
              pid = pid - lastgroupend;
              *(uint32_t *)pos = wi;
              pos += sizeof(uint32_t);
              *(uint32_t *)pos = id;
              pos += sizeof(uint32_t);
              *(uint32_t *)pos = pid;
              pos += sizeof(uint32_t);
              *(uint32_t *)pos = rc;
              pos += sizeof(uint32_t);
              *(uint32_t *)pos = lastgroupend;
              lastid = id;
              rc++;
              return rowBuilder.finalizeRowClear(returnsize);
            }else{
              return NULL;
            }// end if()
          }// end nextRow()

          virtual void stop() override
          {
            // ds->stop();
          }

          protected:
            Linked<IEngineRowAllocator> resultAllocator;
            IRowStream * ds;
            uint32_t pc;
            upt * uptable;
            bool calculated;
            uint32_t rc;// row counter
            uint32_t lastgroupend;
            uint32_t curWi;
            uint32_t lastid;
      };

    #body

    return new MyStreamInlineDataset(_resultAllocator, dsin, pointcount);

  ENDEMBED;//end ultimate()

  //LOOP to get the final ultimateID of each data point
  SHARED Loop_Func(DATASET(l_ultimate) ds, UNSIGNED c) := FUNCTION
        tempLayout := RECORD
          UNSIGNED4 wi;
          UNSIGNED4 id;
          UNSIGNED4 newParentID;
        END;
        tempChanges := PROJECT(ds, TRANSFORM(tempLayout,
                                      SELF.wi := LEFT.wi,
                                      SELF.id := LEFT.ultimateID,
                                      SELF.newParentID := LEFT.largestID), LOCAL);
        changes := DEDUP(SORT(tempChanges, wi, id, -newParentID, LOCAL), wi, id, LOCAL);
        newParent := JOIN(ds, changes,
                          LEFT.wi = RIGHT.wi
                          AND
                          LEFT.id = RIGHT.id,
                          TRANSFORM(RECORDOF(LEFT),
                                    SELF.parentID := IF(right.id > 0,
                                                        RIGHT.newParentID,
                                                        LEFT.parentID),
                                    SELF := LEFT), LEFT OUTER, LOCAL);
        newUltimate :=  Ultimate(newParent, c);
        rst := JOIN(newParent, newUltimate,
                    LEFT.wi = RIGHT.wi
                    AND
                    LEFT.id = RIGHT.id,
                    TRANSFORM(l_ultimate,
                              SELF.ultimateID := RIGHT.parentID,
                              SELF := LEFT));
        RETURN rst;
  END;//end loop_func()

  // Merge function merges the results from each node in stage 2 local clustering.
  // It results in a synchronized cluster index for each data point.
  // The cluster index is 1-based and the outliers are indexed as 0.
  EXPORT DATASET(ML_Core.Types.ClusterLabels) Merge(DATASET(Files.l_stage3) rds) := FUNCTION
    //get non_outliers and its largest parentID
    rds1 := rds( NOT( if_core = FALSE AND id = parentID));
    non_outliers := DEDUP(SORT(rds1,wi, id,-parentID),wi,id );

    //Get outliers
    outliers := PROJECT(JOIN(rDS, non_outliers,
                              LEFT.wi = RIGHT.wi
                              AND
                              LEFT.id = RIGHT.id,
                              LEFT ONLY), TRANSFORM(l_ultimate,
                                                    SELF.ultimateid := LEFT.parentid,
                                                    SELF := LEFT));
    unfiltered := rDS(if_local = TRUE);
    ntunfiltered := COUNT(unfiltered );
    dds := DISTRIBUTE(unfiltered, wi); //
    f0 := PROJECT(NOCOMBINE(dds), TRANSFORM({l_Ultimate, UNSIGNED4 nodeid},
                                            SELF.nodeid := Thorlib.node(),
                                            SELF := LEFT));
    t := TABLE(f0, { nodeid , cnt := COUNT(GROUP)}, nodeid, LOCAL);
    c := t(nodeid = thorlib.node())[1].cnt;

    //get local core points
    f1 := rDS(if_local = TRUE AND if_core=TRUE);
    f2 := DISTRIBUTE(f1, wi);
    localCores := SORT(PROJECT(NOCOMBINE(f2),TRANSFORM(l_ultimate,
                                                      SELF := LEFT),
                                                      LOCAL),
                                                      wi, id, LOCAL);

    locals_ultimate:=  ultimate(localCores, c);// all the ultimates for locals

    //get largestID for the core points
    largest := DISTRIBUTE(non_outliers(if_core = TRUE), wi);

    //Prepare the input dataset 'initial' for Loop_Func()
    //Join largest and locals_ultimate
    initial0 := JOIN(largest, locals_ultimate,
                    LEFT.wi = RIGHT.wi
                    AND
                    LEFT.id = RIGHT.id,
                    TRANSFORM(l_ultimate,
                              SELF.ultimateID := RIGHT.parentID,
                              SELF.largestID := LEFT.parentID,
                              SELF := LEFT), LOCAL);

    //Join locals
    initial := JOIN(initial0, localCores,
                    LEFT.wi = RIGHT.wi
                    AND
                    LEFT.id = RIGHT.id,
                    TRANSFORM(l_ultimate,
                            SELF.parentID := RIGHT.parentID,
                            SELF := LEFT), LOCAL);

    l := LOOP(initial,
              LEFT.id > 0,
              EXISTS(ROWS(LEFT)(ultimateID < largestID)),
              LOOP_Func(ROWS(LEFT), c) );
    //Update the parentID of all non_outliers from the result
    update_non_outliers := JOIN(non_outliers, l,
                                LEFT.wi = RIGHT.wi
                                AND
                                LEFT.parentid = RIGHT.id,
                                TRANSFORM(l_ultimate,
                                          SELF.ultimateID := IF(right.id =0,
                                                                LEFT.parentid,
                                                                RIGHT.ultimateID),
                                          SELF:= LEFT),
                                          LEFT OUTER);
    //Convert ultimate id of outliers to zero
    outliers1 := PROJECT(outliers, TRANSFORM(ML_Core.Types.ClusterLabels,
                                              SELF.label := 0,
                                              SELF.id := LEFT.id,
                                              SELF.wi := LEFT.wi));
    //Get mapping to 1-based cluster labels
    map0 := TABLE(update_non_outliers,{wi,ultimateId,id_min:=MIN(GROUP,id)},wi,ultimateId);
    map1 := PROJECT(SORT(map0,wi,id_min), TRANSFORM(RECORDOF(map0),
                                    SELF.wi:=LEFT.wi,
                                    SELF.ultimateId:=LEFT.ultimateID,
                                    SELF.id_min:=COUNTER));
    //Map 1 based indices to the cluster labels
    result0 := PROJECT(update_non_outliers,
                      TRANSFORM(ML_Core.Types.ClusterLabels,
                                SELF.label := map1(wi=LEFT.wi
                                                  AND
                                                  ultimateid=LEFT.ultimateId)[1].id_min
                                                  - MIN(map1(wi=LEFT.wi),map1(wi=LEFT.wi).id_min)
                                                  + 1,
                                SELF.wi := LEFT.wi,
                                SELF.id := LEFT.id));
    //Combine outliers and non outliers to form final result
    result := result0 + outliers1;
    //Return the final cluster index of each data point
    RETURN result;
  END;
END;