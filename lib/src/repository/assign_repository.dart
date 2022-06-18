import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/src/config/repository_config.dart';
import 'package:quiver/iterables.dart';

import '../config/assign_repository_config.dart';
import '../const_names.dart';
import '../converters/assign_model_converter.dart';

class AssignRepository {

  static Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 6,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    filter: DevelopmentFilter(),
  );
  FirebaseFirestore firestore;
  RepositoryConfig repositoryConfig;
  AssignRepositoryConfig get config => repositoryConfig.assignRepositoryConfig;
  CollectionReference _assignCollection;
  // current 'withConverter' primary job is mapping the datetime filed of AssignModel to Timestamp of Firestore
  CollectionReference get assignCollection => _assignCollection
      .withConverter<AssignModel?>(
    fromFirestore: AssignModelFromFirestoreFunction,
    toFirestore:  AssignModelToFirestoreFunction,
  );
  AssignRepository({
    required this.firestore,
    required this.repositoryConfig}):_assignCollection = firestore.collection(repositoryConfig.assignRepositoryConfig.collectionName);

  Future<AssignModel?> get(String guid) async {
    if (guid.isEmpty){
      logger.w("guid is blank.");
      return null;
    }
    logger.i("get by guid: $guid");
    var querySnapshot = await assignCollection.doc(guid).get();
    if (!querySnapshot.exists) {
      logger.w("get by guid: $guid, not exists.");
      return null;
    }
    logger.v(querySnapshot.data());
    logger.i("get by guid: $guid, done.");
    // return AssignModel.fromJson(querySnapshot.data() as Map<String, dynamic>);
    return querySnapshot.data() as AssignModel;
  }
  Future<List<AssignModel>?> getAll(List<String> guids) async {
    logger.i("getAll by guids total:${guids.length}");
    logger.v(guids);
    if (guids.isEmpty){
      logger.w("guids is empty.");
      return null;
    }
    List<QueryDocumentSnapshot> queryDocs = await _loadByGuids(guids);

    // convert to AssignModel
    // var resultList = queryDocs.map((e) => AssignModel.fromJson(e.data() as Map<String, dynamic>)).toList();
    List<AssignModel> resultList = queryDocs.where((e) => e.exists).map((e) =>e.data()! as AssignModel).toList();

    logger.i("getAll by guids done whit total:${resultList.length} found.");
    logger.v(resultList);
    return resultList;
  }
  /// method provide exists check\
  /// all QueryDocumentSnapshot in queryDocs should be exists
  Future<List<QueryDocumentSnapshot<Object?>>> _loadByGuids(List<String> guids) async {
    List<QueryDocumentSnapshot<Object?>> result = [];
    if (guids.length > repositoryConfig.whereInLimit){
      logger.d("_loadByGuids assignGuidList is too long, try batch get.");
      // split assignGuidList to batch get
      // List<List<String>> batchGuids = List.generate(guids.length ~/  + 1,
      //         (index) => guids.sublist(index * , min(guids.length, (index + 1) * )));
      Iterable<List<String>> batchGuids = partition(guids, repositoryConfig.whereInLimit);
      // get all reference from remote
      Iterable<Future<QuerySnapshot>> getRemoteAssignListFutureList = batchGuids
          .map((assignGuidListChunk) => assignCollection.where(
          config.assignGuidFieldName, whereIn: assignGuidListChunk).get());
      var queryResultList = await Future.wait(getRemoteAssignListFutureList);
      result = queryResultList.where((e) => e.docs.isNotEmpty).expand((e) => e.docs.where((d) => d.exists)).toList();
    }
    else{
      // get all reference from remote
      var queryResult = await assignCollection.where(
          config.assignGuidFieldName, whereIn: guids).get();
      result = queryResult.docs.where((e) => e.exists).toList();
    }
    logger.d("_loadByGuids done with total:${result.length}.");
    logger.v(result);
    return result;
  }
  /// add to /Assign/<AssignGuid>
  Future<void> add(AssignModel assign) async {
    logger.i("assignGuid:${assign.guid}");
    logger.v(assign.toJson());
    await assignCollection.doc(assign.guid).set(assign);
    logger.i("assignGuid:${assign.guid} done");
    // logger
    return;
  }

  /// add all assign  to /Assign/<AssignGuid>
  Future<void> addAll(List<AssignModel> assigns) async {
    if (assigns.isNotEmpty){
      logger.i("addAll total:${assigns.length}.");
      // generate future list to add each assign to firebase
      List<Future<dynamic>> addToRemoteFutureList = assigns
          .map((assign)=>assignCollection.doc(assign.guid).set(assign))
          .toList();
      await Future.wait(addToRemoteFutureList);
      logger.i("addAll total:${assigns.length} done.");
    }else{
      logger.w("addAll no assign to add, param is empty.");
    }

    return;
  }

  /// merge assign to /Assign/<AssignGuid>
  Future<void> update(AssignModel assign) async{
    logger.i("update assignGuid:${assign.guid}");
    logger.v(assign.toJson());
    logger.d("try get old assign from remote.");
    // update assign's lastModifiedAt
    assign.lastModifiedAt = DateTime.now();
    var querySnapshot = await assignCollection.doc(assign.guid).get();
    if (querySnapshot.exists) {
      logger.v(querySnapshot.data());
      logger.d("replace old assign with new one.");
      await querySnapshot.reference.set(assign, SetOptions(merge: true));
    }else {
      logger.w("assignGuid:${assign.guid} not found.");
    }
    logger.i("update assignGuid:${assign.guid} done.");
  }

  Future<void> updateFields(String assignGuid,Map<String,dynamic> fieldsMap) async {
    // check fieldsMap is not empty
    // when it's logger with warm level, it will print all fieldsMap
    if (fieldsMap.isNotEmpty) {
      logger.i("updateFields assignGuid:$assignGuid");
      logger.v(fieldsMap);
      logger.d("try get old assign from remote.");
      // check fieldsMap contains lastModifiedAt
      // if not set to DateTime.now()
      if (!fieldsMap.containsKey(config.lastModifiedAtFieldName)){
        fieldsMap[config.lastModifiedAtFieldName] = DateTime.now().toIso8601String();
      }
      var querySnapshot = await assignCollection.doc(assignGuid).get();
      if (querySnapshot.exists) {
        logger.v(querySnapshot.data());
        logger.d("replace old assign with new one.");
        await querySnapshot.reference.update(fieldsMap);
        logger.i("updateFields assignGuid:$assignGuid done.");
      } else {
        logger.w("assignGuid:$assignGuid not found.");
      }
    }else{
      logger.w("updateFields no fields to update, param is empty.");
    }
  }

  /// WARNING: this method will only update assign which exist in remote.
  ///
  /// method will update fields for multi-assigns
  /// [assignGuidList] is a list of assignGuid
  /// [fieldsMap] is a map of fields to update
  ///
  /// return a list of assignGuid which not found in remote, aka not updated.
  Future<List<String>?> updateAssignListFields(List<String> assignGuidList,Map<String,dynamic> fieldsMap) async {
    // check assignGuidList is not empty
    // when it's logger with warm level, it will print all assignGuidList
    if (assignGuidList.isNotEmpty && fieldsMap.isNotEmpty) {
      logger.i("updateAssignListFields total:${assignGuidList.length}");
      logger.v(fieldsMap);
      logger.v(assignGuidList);
      // check fieldsMap contains lastModifiedAt
      // if not set to DateTime.now()
      if (!fieldsMap.containsKey(config.lastModifiedAtFieldName)){
        fieldsMap[config.lastModifiedAtFieldName] = DateTime.now().toIso8601String();
      }
      List<QueryDocumentSnapshot> allAssignData = await _loadByGuids(assignGuidList);
      logger.d("total:${assignGuidList.length} to update, found total:${allAssignData.length} in remote.");
      // check allAssignData is not empty
      if (allAssignData.isNotEmpty){
        // update allAssignData with fieldsMap by reference
        List<Future<dynamic>> updateRemoteAssignFutureList = allAssignData
            .map((assignData) => assignData.reference.update(fieldsMap))
            .toList();
        await Future.wait(updateRemoteAssignFutureList);

        // get not found assignGuidList
        // 1. get all assignGuid from allAssignData
        // var allAssignGuid = allAssignData.where((e) => e.exists).map((e) => (e.data()! as Map<String,dynamic>)[ASSIGN_GUID_FIELD_NAME]).toList();
        var allAssignGuid = allAssignData.where((e) => e.exists).map((e) => (e.data()! as AssignModel).guid).toList();
        // 2. get not found assignGuidList
        var notFoundAssignGuidList = assignGuidList.where((e) => !allAssignGuid.contains(e)).toList();
        if (notFoundAssignGuidList.isNotEmpty){
          logger.d("not found assignGuidList total :${notFoundAssignGuidList.length}");
          logger.v(notFoundAssignGuidList);
          return Future.value(notFoundAssignGuidList);
        }else{
          logger.i("updateAssignListFields total:${assignGuidList.length} done.");
          return Future.value([]);
        }
      }else{
        logger.w("not found any assign in remote.");
        return Future.value(assignGuidList);
      }


    }else{
      if (assignGuidList.isEmpty) {
        logger.w("updateAssignListFields no assignGuidList to update, param is empty.");
      }
      if (fieldsMap.isEmpty) {
        logger.w("updateAssignListFields no fields to update, param is empty.");
      }
      return null;
    }
  }

  Future<AssignModel?> delete(String assignGuid) async {
    logger.i("delete assignGuid:$assignGuid");
    var snapshot = await assignCollection.doc(assignGuid).get();
    if (snapshot.exists) {
      var deletedAssign = snapshot.data()! as AssignModel;
      logger.v(deletedAssign.toJson());
      await snapshot.reference.delete();
      logger.i("delete assignGuid:$assignGuid done.");
      return deletedAssign;
    } else {
      logger.w("assignGuid:$assignGuid not found.");
      return Future.value(null);
    }
  }

  /// WARNING: this method will only delete assign which exist in remote.
  /// [assignGuidList] is a list of assignGuid
  /// return a list of assignGuid which not found in remote, aka not deleted.
  Future<List<AssignModel>?> deleteAll(List<String> guids) async {
    // check guids is not empty
    // when it's logger with warm level
    if (guids.isNotEmpty){
      logger.i("deleteAll total:${guids.length}");
      logger.v(guids);
      List<QueryDocumentSnapshot> allAssignData = await _loadByGuids(guids);
      logger.d("total:${guids.length} to delete, found total:${allAssignData.length} in remote.");
      List<AssignModel> deletedAssignList = [];
      if (allAssignData.isNotEmpty){
        var deleteFutureList = allAssignData.map((e){
          deletedAssignList.add(e.data()! as AssignModel);
          return e.reference.delete();
        }).toList();
        await Future.any(deleteFutureList);
        logger.i("deleteAll total:${guids.length} done.");
        return Future.value(deletedAssignList);
      }else{
        logger.w("not found any assign with data in remote.");
        return Future.value(null);
      }
    }else {
      logger.w("deleteAll no guids to delete, param is empty.");
      return Future.value(null);
    }

  }


  ///  add "startAfter" and "endBefore" to query
  ///  with "orderBy" and "limit"
  Query _queryWithStartEndLimit(Query query,DateTime? start,DateTime? end,int? limit) {
    if (start != null) {
      // query = query.startAfter([Timestamp.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch)]);
      query = query.startAfter([start.toIso8601String()]);
      // query.where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch));
      // await query.get();
    }
    if (end != null){
      // query = query.endBefore([Timestamp.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch)]);
      query = query.endBefore([end.toIso8601String()]);
      // query.where("createdAt", isLessThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch));
    }
    if (limit != null && limit > 0){
      query = query.limit(limit);
    }
    return query;
  }

  List<AssignModel> _querySnapshot2AssignList(QuerySnapshot querySnapshot){
    // List<AssignModel> assignList = [];
    return querySnapshot.docs.where((element) => element.exists).map((e) => e.data()! as AssignModel).toList();
    // return assignList;
  }

  ///
  /// when after is null, list all assign for masterUid
  /// otherwise, list all assign for masterUid after given datetime
  /// [masterUid] is the masterUid of assign
  /// [start] is the datetime after which assign should be listed
  /// [end] is the max number of assign to be listed
  Future<List<AssignModel>> listAllByMasterUid(String masterUid,{DateTime? start,DateTime? end,int? limit}) async {
    logger.i("listAllMasterUid masterUid:$masterUid, with start:$start~end:$end,limit:$limit");
    Query query = assignCollection
        .where(config.masterUidFieldName,isEqualTo: masterUid)
        .orderBy(config.createdAtFieldName);
    var snapshot = await _queryWithStartEndLimit(query,start,end,limit).get();
    if (snapshot.docs.isNotEmpty) {
      // snapshot.docs.forEach((e) {
      //   logger.v(e.data());
      // });
      // List<AssignModel> result = snapshot.docs.map((e) => AssignModel.fromJson(e.data()! as Map<String,dynamic>)).toList();
      List<AssignModel> result = _querySnapshot2AssignList(snapshot);
      logger.i("listAllMasterUid masterUid:$masterUid, with start:$start~end:$end,limit:$limit done.");
      logger.v(result);
      return result;
    }
    else {
      logger.w("not found any assign with masterUid:$masterUid, start:$start~end:$end");
      return Future.value([]);
    }
  }



  ///
  ///
  /// when after is null, list all assign for masterUid
  /// otherwise, list all assign for masterUid after given datetime
  /// [masterUid] is the masterUid of assign
  /// [start] is the datetime after which assign should be listed
  /// [end] is the max number of assign to be listed
  Future<List<AssignModel>> listAllByHostUid(String hostUid,{DateTime? start,DateTime? end,int? limit}) async {
    Query query = assignCollection
        .where(config.hostUidFieldName,isEqualTo: hostUid)
        .orderBy(config.createdAtFieldName);
    var snapshot = await _queryWithStartEndLimit(query,start,end,limit).get();
    List<AssignModel> result = _querySnapshot2AssignList(snapshot);

    logger.i("listAllByHostUid hostUid:$hostUid, with start:$start~end:$end,limit:$limit, found:${result.length}");
    logger.v(result);
    return result;
  }

  Future<List<AssignModel>> listAllByOrderGuid(String orderGuid) async {
    var querySnapshot = await assignCollection
        .where(config.orderGuidFieldName,isEqualTo: orderGuid)
        .orderBy(config.createdAtFieldName)
        .get();
    List<AssignModel> result = _querySnapshot2AssignList(querySnapshot);

    logger.i("listAllByOrderGuid orderGuid:$orderGuid, found:${result.length}");
    logger.v(result);
    return result;
  }

  Future<List<AssignModel>> listAllByOrderGuidList(List<String> orderGuidList) async {

    logger.i("listAllByOrderGuidList result:${orderGuidList.length}");
    if (orderGuidList.isEmpty){
      logger.w("listAllByOrderGuidList no orderGuidList to list.");
      return Future.value([]);
    }
    logger.v(orderGuidList);
    List<AssignModel> result;
    // split orderGuidList to chunks with size of
    if (orderGuidList.length <= repositoryConfig.whereInLimit){
      logger.d("run query with single query");
      var snapshot = await assignCollection
          .where(config.orderGuidFieldName, whereIn: orderGuidList)
          .orderBy(config.createdAtFieldName)
          .get();
      result = _querySnapshot2AssignList(snapshot);
    }else{
      Iterable<List<String>> orderGuidChunks = partition(orderGuidList, repositoryConfig.whereInLimit);

      logger.d("run query with ${orderGuidChunks.length} times query");
      // mapping each chunk to a future with whereIn for where of firestore query
      Iterable<Future<List<AssignModel>>> futureList = orderGuidChunks.map((chunk) async {
        var snapshot = await assignCollection
            .where(config.orderGuidFieldName, whereIn: chunk)
            .orderBy(config.createdAtFieldName)
            .get();
        return _querySnapshot2AssignList(snapshot);
      });
      // flatten result
      List<List<AssignModel>> resultList = await Future.wait(futureList);
      result = resultList.expand((e) => e).toList();
    }


    // execute all futures with Future.wait
    logger.i("listAllByOrderGuidList result:${result.length}");
    logger.v(result);
    return result;
  }
}