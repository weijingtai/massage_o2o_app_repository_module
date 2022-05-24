import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';

import 'const_names.dart';

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
  FirebaseFirestore instance;
  CollectionReference get assignCollection => instance
      .collection(ASSIGN_COLLECTION_NAME)
      .withConverter<AssignModel?>(
    fromFirestore: (snapshot, _){
      if (snapshot.exists){
        Map<String,dynamic> data = snapshot.data()!;
        data.map((key, value){
          if (value is Timestamp){
            return MapEntry(key,DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch));
          }
          return MapEntry(key, value);
        });
        return AssignModel.fromJson(data);
      }
      return null;
    },
    toFirestore: (model, _){
      if (model != null){
        Map<String,dynamic> mapData = model.toJson();
        return mapData.map((key, value){
          if (value is DateTime){
            return MapEntry(key, Timestamp.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch));
          }
          return MapEntry(key, value);
        });
      }else{
        return {} as Map<String,dynamic>;
      }

    },
  );
  AssignRepository(this.instance);

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
    if (guids.length > 9){
      logger.d("_loadByGuids assignGuidList is too long, try batch get.");
      // split assignGuidList to batch get
      List<List<String>> batchGuids = List.generate(guids.length ~/ 9 + 1,
              (index) => guids.sublist(index * 9, min(guids.length, (index + 1) * 9)));
      // get all reference from remote
      List<Future<QuerySnapshot>> getRemoteAssignListFutureList = batchGuids
          .map((assignGuidListChunk) => assignCollection.where(
          ASSIGN_GUID_FIELD_NAME, whereIn: assignGuidListChunk).get())
          .toList();
      var queryResultList = await Future.wait(getRemoteAssignListFutureList);
      result = queryResultList.where((e) => e.docs.isNotEmpty).expand((e) => e.docs.where((d) => d.exists)).toList();
    }
    else{
      // get all reference from remote
      var queryResult = await assignCollection.where(
          ASSIGN_GUID_FIELD_NAME, whereIn: guids).get();
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

  Future<AssignModel?> delete(String assignGuid){
    logger.i("delete assignGuid:$assignGuid");
    return assignCollection.doc(assignGuid).get().then((snapshot) async {
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
    });
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

  ///
  /// when after is null, list all assign for masterUid
  /// otherwise, list all assign for masterUid after given datetime
  /// [masterUid] is the masterUid of assign
  /// [after] is the datetime after which assign should be listed
  Future<List<AssignModel>> listAllByMasterUid(String masterUid,{DateTime? after}) async {
    logger.i("listAllMasterUid masterUid:$masterUid, with after:$after");
    Query query = assignCollection
        .where(ASSIGN_MASTER_UID_FIELD_NAME,isEqualTo: masterUid);
    if (after != null) {
      // query
      //     .orderBy("createdAt")
      //     .where("createdAt", isLessThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(after.millisecondsSinceEpoch));
      var snapshot =  await query
          .orderBy("createdAt")
          .where("createdAt", isLessThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(after.millisecondsSinceEpoch))
          .get();
      // await query.get();
      if (snapshot.docs.isNotEmpty) {
        // snapshot.docs.forEach((e) {
        //   logger.v(e.data());
        // });
        // List<AssignModel> result = snapshot.docs.map((e) => AssignModel.fromJson(e.data()! as Map<String,dynamic>)).toList();
        List<AssignModel> result = snapshot.docs.map((e) => e.data()! as AssignModel).toList();
        logger.i("listAllMasterUid masterUid:$masterUid, with after:$after, total:${result.length} found.");
        logger.v(result.first.toJson());
        logger.v(result.last.toJson());
        return Future.value(result);
      }
      else {
        logger.w("not found any assign with masterUid:$masterUid, after:$after");
        return Future.value([]);
      }
    }
    var snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      // snapshot.docs.forEach((e) {
      //   logger.v(e.data());
      // });
      // List<AssignModel> result = snapshot.docs.map((e) => AssignModel.fromJson(e.data()! as Map<String,dynamic>)).toList();
      List<AssignModel> result = snapshot.docs.map((e) => e.data()! as AssignModel).toList();
      logger.i("listAllMasterUid masterUid:$masterUid, with after:$after, total:${result.length} found.");
      logger.v(result.first.toJson());
      logger.v(result.last.toJson());
      return Future.value(result);
    }
    else {
      logger.w("not found any assign with masterUid:$masterUid, after:$after");
      return Future.value([]);
    }
  }
}