import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:quiver/iterables.dart';
import '../config/repository_config.dart';
import '../config/service_repository_config.dart';
import '../const_names.dart';

class ServiceRepository {
  static Logger logger = Logger();
  // CollectionReference orderCollection = FirebaseFirestore.instance.collection(ACTIVATED_ORDER_COLLECTION_NAME);
  // Query serviceCollectionGroup = FirebaseFirestore.instance.collectionGroup(SERVICES_COLLECTION_NAME);

  // CollectionReference get serviceCollection => firestore.collection(SERVICES_COLLECTION_NAME);
  // CollectionReference serviceCollection = firestore.collection(SERVICE_COLLECTION_NAME);
  CollectionReference _serviceCollection;
  FirebaseFirestore firestore;
  RepositoryConfig repositoryConfig;
  ServiceRepositoryConfig get config =>
      repositoryConfig.serviceRepositoryConfig;

  // CollectionReference orderCollection = FirebaseFirestore.instance.collection(ORDER_COLLECTION_NAME);
  ServiceRepository({required this.firestore, required this.repositoryConfig})
      : _serviceCollection = firestore.collection(
            repositoryConfig.serviceRepositoryConfig.collectionName);

  Future<void> add(ServiceModel service) async {
    logger.i("add service.");
    logger.v(service.toJson());
    await _serviceCollection.doc(service.guid).set(service.toJson());
    logger.i("add service done.");
    return;
  }

  Future<void> addAll(List<ServiceModel> serviceList) async {
    if (serviceList.isEmpty) {
      logger.w("addAll serviceList is empty");
      return;
    }
    // map serviceModel to orderGuid and reduce
    Map<String, List<ServiceModel>> serviceMap = {};
    for (ServiceModel service in serviceList) {
      serviceMap[service.orderGuid] ??= [];
      serviceMap[service.orderGuid]!.add(service);
    }
    logger.d(
        "addAll total:${serviceMap.length} orderGuids, and ${serviceList.length} services");
    await Future.wait(serviceMap.entries
        .map((entry) => _remoteCreateServices(entry.key, entry.value))
        .toList());
    return;
  }

  Future<void> _remoteCreateServices(
      String orderGuid, List<ServiceModel> services) {
    // add each service /Service/<SERVICE_GUID>
    List<Future<dynamic>> addToRemoteFutureList = services
        .map((s) => _serviceCollection.doc(s.guid).set(s.toJson()))
        .toList();
    return Future.wait(addToRemoteFutureList);
  }

  Future<void> deleteAllByOrderGuid(String orderGuid) async {
    // remove from /Service/<SERVICE_GUID>
    var querySnapshot =
        await _serviceCollection.where("orderGuid", isEqualTo: orderGuid).get();
    if (querySnapshot.size > 0) {
      logger.d(
          "deleteServiceListByOrderGuid: orderGuid: $orderGuid,total:${querySnapshot.docs.length}.");
      List<Future<dynamic>> deleteFromRemoteFutureList =
          querySnapshot.docs.map((doc) => doc.reference.delete()).toList();
      await Future.wait(deleteFromRemoteFutureList);
    } else {
      logger.w(
          " deleteServiceListByOrderGuid: no service found for order: $orderGuid.");
    }
    return;
  }

  Future<void> deleteByGuidList(List<String> serviceGuidList) async {
    logger.i(
        "deleteServiceByGuidList: for serviceGuidList: ${serviceGuidList.length}");
    // when serviceList is not null or empty, and length is greater than
    // split the list into chunks of ,
    // delete each chunk
    if (serviceGuidList.isNotEmpty) {
      if (serviceGuidList.length > repositoryConfig.whereInLimit) {
        Iterable<List<String>> chunks =
            partition(serviceGuidList, repositoryConfig.whereInLimit);
        // var getFuture = chunks.map((e) => serviceCollectionGroup.where("guid", whereIn: serviceGuidList).get()).toList();
        // var result = await Future.wait(getFuture);
        // result.expand((element) => element.docs).forEach((e) => e.reference.delete());
        var getFuture = chunks
            .map((e) => _serviceCollection
                .where(config.serviceGuidFieldName, whereIn: serviceGuidList)
                .get())
            .toList();
        var result = await Future.wait(getFuture);
        result
            .expand((element) => element.docs)
            .forEach((e) => e.reference.delete());
      } else {
        QuerySnapshot querySnapshot = await _serviceCollection
            .where("guid", whereIn: serviceGuidList)
            .get();
        for (var e in querySnapshot.docs) {
          e.reference.delete();
        }
      }
    } else {
      logger.w("deleteServiceByGuidList: serviceGuidList is empty");
    }
  }

  Future<List<ServiceModel>> loadAllServiceByMasterUid(String masterUid,
      {DateTime? startAt, DateTime? endAt}) async {
    logger.i("loadAllServiceByMasterUid: masterUid: $masterUid");
    var query = _serviceCollection
        .where("assignedMasterUid", isEqualTo: masterUid)
        .orderBy("createdAt", descending: false);
    if (startAt != null) {
      logger.d("loadAllServiceByMasterUid: with startAt: $startAt");
      query = query.startAt([startAt.toUtc().toIso8601String()]);
    }
    if (endAt != null) {
      logger.d("loadAllServiceByMasterUid: with startAt: $startAt");
      query = query.endAt([endAt.toUtc().toIso8601String()]);
    }
    var querySnapshot = await query.get();
    if (querySnapshot.size > 0) {
      logger.i("loadAllServiceByMasterUid: load total:${querySnapshot.size}.");
      return querySnapshot.docs
          .map((e) => ServiceModel.fromJson(e.data() as Map<String, dynamic>))
          .toList();
    }
    logger.i("loadAllServiceByMasterUid: load empty.");
    return [];
  }

  Future<ServiceModel?> load(String serviceGuid) async {
    var docSnap = await _serviceCollection.doc(serviceGuid).get();
    if (docSnap.exists) {
      return ServiceModel.fromJson(docSnap.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<ServiceModel>> loadAllByServiceGuids(
      List<String> serviceGuids) async {
    logger.i("loadAllByServiceGuids: total: ${serviceGuids.length}");
    var querySnapshot = await _serviceCollection
        .where(config.serviceGuidFieldName, whereIn: serviceGuids)
        .get();
    logger.d("loadAllByServiceGuids: total: ${querySnapshot.size} found.");
    return querySnapshot.docs
        .map((doc) => ServiceModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceModel>> loadAllByOrderGuidList(
      List<String> orderGuidList) async {
    logger.i("loadAllByOrderGuid: for total: ${orderGuidList.length} orders,");
    if (orderGuidList.isNotEmpty) {
      List<ServiceModel> serviceList = [];
      if (orderGuidList.length <= repositoryConfig.whereInLimit) {
        QuerySnapshot querySnapshot = await _serviceCollection
            .where(config.orderGuidFieldName, whereIn: orderGuidList)
            .get();
        serviceList = querySnapshot.docs
            .where((e) => e.exists)
            .map((e) =>
                ServiceModel.fromJson((e.data()! as Map<String, dynamic>)))
            .toList();
      } else {
        // split orderGuidList into chunks of
        // List<List<String>> orderGuidListChunks = List.generate(orderGuidList.length~/, (index) => orderGuidList.sublist(index*9, (index+1)*9));
        Iterable<List<String>> orderGuidListChunks =
            partition(orderGuidList, repositoryConfig.whereInLimit);
        // generate future querySnapshot for each chunk
        // List<Future<QuerySnapshot>> querySnapshotList = orderGuidListChunks.map((e) => serviceCollectionGroup
        //     .where("orderGuid", whereIn: e)
        //     .get())
        //     .toList();
        Iterable<Future<QuerySnapshot>> querySnapshotList =
            orderGuidListChunks.map((e) => _serviceCollection
                .where(config.orderGuidFieldName, whereIn: e)
                .get());
        var allResult = await Future.wait(querySnapshotList);
        // flatmap  all result to serviceList
        serviceList = allResult
            .map((e) => e.docs)
            .expand((e) => e)
            .where((e) => e.exists)
            .map((e) =>
                ServiceModel.fromJson((e.data()! as Map<String, dynamic>)))
            .toList();
      }
      logger.i(
          "loadAllByOrderGuid: for total: ${orderGuidList.length} orders, loaded: ${serviceList.length}");
      return serviceList;
    } else {
      logger.w("loadAllByOrderGuid: orderGuidList is empty");
      return Future.value([]);
    }
  }

  Future<List<ServiceModel>> loadAllByOrderGuid(String orderGuid) async {
    logger.i("loadAll: for order: $orderGuid");
    // QuerySnapshot<Object?> snapshot = await serviceCollectionGroup
    //     .where("orderGuid", isEqualTo: orderGuid)
    //     .get();
    // DocumentReference reference = serviceCollection.doc(orderGuid);
    QuerySnapshot snapshot = await _serviceCollection
        .where(config.orderGuidFieldName, isEqualTo: orderGuid)
        .get();
    if (snapshot.docs.isNotEmpty) {
      List<ServiceModel> serviceList = snapshot.docs
          .where((e) => e.exists)
          .map(
              (e) => ServiceModel.fromJson((e.data()! as Map<String, dynamic>)))
          .toList();
      if (serviceList.isNotEmpty) {
        logger.d(
            "loadAll: for order: $orderGuid with serviceList: ${serviceList.length}");
        return serviceList;
      }
    }
    logger.d("loadAll: for order: $orderGuid with serviceList: 0");
    return [];
  }

  Future<void> updateService(ServiceModel service) async {
    logger.i("updateService: service:${service.guid}");
    logger.v(service.toJson());
    // check service's lastModifiedAt is not null
    // it is null then add DateTime.now() to it
    service.lastModifiedAt ??= DateTime.now();
    await _serviceCollection
        .doc(service.guid)
        .set(service.toJson(), SetOptions(merge: true));
  }

  Future<void> updateServiceWithField(
      String serviceGuid, Map<String, dynamic> updatedField) async {
    logger.i(
        "updateServiceWithField: service:$serviceGuid, updatedField:$updatedField");
    // check service's lastModifiedAt is not null
    // it is null then add DateTime.now() to it
    updatedField["lastModifiedAt"] ??= DateTime.now().toUtc().toIso8601String();
    if (updatedField.containsValue(null)) {
      updatedField =
          updatedField.map((k, v) => MapEntry(k, v ?? FieldValue.delete()));
    }
    logger.v(updatedField);
    await _serviceCollection.doc(serviceGuid).update(updatedField);
    // .set(updatedField, SetOptions(merge: true)); // merge: true will update the field, not replace it
    // warming: 'set' is not accepting '<childName>.<childFiledName>'
  }

  Future<void> updateServiceListWithField(
      List<String> serviceGuids, Map<String, dynamic> updatedField) async {
    if (serviceGuids.isNotEmpty && updatedField.isNotEmpty) {
      logger.i("updateAssignListFields total:${serviceGuids.length}");
      logger.v(serviceGuids);
      // check fieldsMap contains lastModifiedAt
      // if not set to DateTime.now()
      if (!updatedField.containsKey(config.lastModifiedAtFieldName)) {
        updatedField[config.lastModifiedAtFieldName] =
            DateTime.now().toUtc().toIso8601String();
      }
      // check fieldsMap's value is null replace with FirebaseFeilds.Delete;
      if (updatedField.containsValue(null)) {
        updatedField =
            updatedField.map((k, v) => MapEntry(k, v ?? FieldValue.delete()));
      }
      logger.v(updatedField);
      List<QueryDocumentSnapshot> serviceAssignData =
          await _loadByGuids(serviceGuids);
      logger.d(
          "total:${serviceGuids.length} to update, found total:${serviceAssignData.length} in remote.");
      // check allAssignData is not empty
      if (serviceAssignData.isNotEmpty) {
        // update allAssignData with fieldsMap by reference
        List<Future<dynamic>> updateRemoteAssignFutureList = serviceAssignData
            .map((assignData) => assignData.reference.update(updatedField))
            .toList();
        await Future.wait(updateRemoteAssignFutureList);

        // get not found assignGuidList
        // 1. get all assignGuid from allAssignData

        // var allAssignGuid = allAssignData.where((e) => e.exists).map((e) => (e.data()! as Map<String,dynamic>)[ASSIGN_GUID_FIELD_NAME]).toList();
        var allServiceGuid = serviceAssignData
            .where((e) => e.exists)
            .map((e) =>
                ServiceModel.fromJson(e.data()! as Map<String, dynamic>).guid)
            .toList();
        // 2. get not found assignGuidList
        var notFoundAssignGuidList =
            serviceGuids.where((e) => !allServiceGuid.contains(e)).toList();
        if (notFoundAssignGuidList.isNotEmpty) {
          logger.d(
              "not found assignGuidList total :${notFoundAssignGuidList.length}");
          logger.v(notFoundAssignGuidList);
          return Future.value(notFoundAssignGuidList);
        } else {
          logger.i("updateAssignListFields total:${serviceGuids.length} done.");
          return Future.value([]);
        }
      } else {
        logger.w("not found any assign in remote.");
        return Future.value(serviceGuids);
      }
    } else {
      if (serviceGuids.isEmpty) {
        logger.w(
            "updateAssignListFields no assignGuidList to update, param is empty.");
      }
      if (updatedField.isEmpty) {
        logger.w("updateAssignListFields no fields to update, param is empty.");
      }
      return null;
    }
  }

  Future<List<QueryDocumentSnapshot<Object?>>> _loadByGuids(
      List<String> guids) async {
    List<QueryDocumentSnapshot<Object?>> result = [];
    if (guids.length > repositoryConfig.whereInLimit) {
      logger.d("_loadByGuids assignGuidList is too long, try batch get.");
      // split assignGuidList to batch get
      // List<List<String>> batchGuids = List.generate(guids.length ~/  + 1,
      //         (index) => guids.sublist(index * , min(guids.length, (index + 1) * )));
      Iterable<List<String>> batchGuids =
          partition(guids, repositoryConfig.whereInLimit);
      // get all reference from remote
      Iterable<Future<QuerySnapshot>> getRemoteServiceListFutureList =
          batchGuids.map((serviceGuidListChunk) => _serviceCollection
              .where(config.serviceGuidFieldName, whereIn: serviceGuidListChunk)
              .get());
      var queryResultList = await Future.wait(getRemoteServiceListFutureList);
      result = queryResultList
          .where((e) => e.docs.isNotEmpty)
          .expand((e) => e.docs.where((d) => d.exists))
          .toList();
    } else {
      // get all reference from remote
      var queryResult = await _serviceCollection
          .where(config.serviceGuidFieldName, whereIn: guids)
          .get();
      result = queryResult.docs.where((e) => e.exists).toList();
    }
    logger.d("_loadByGuids done with total:${result.length}.");
    logger.v(result);
    return result;
  }

  @deprecated
  Future<void> deleteAssign(String serviceGuid) async {
    logger.i("updateService: service:$serviceGuid");
    await _serviceCollection.doc(serviceGuid).update({
      "assign": FieldValue.delete(),
      "assignedMasterUid": FieldValue.delete()
    });
  }

  Future<void> updateServiceList(List<ServiceModel> newServiceList) async {
    // split newServiceList by orderGuid
    logger.i(
        "updateAssignState: total:${newServiceList.length} new service list");
    if (newServiceList.isNotEmpty) {
      var lastModifiedAt = DateTime.now();
      await Future.wait(newServiceList
          .map((e) => e..lastModifiedAt ??= lastModifiedAt)
          .map((e) => _serviceCollection.doc(e.guid).update(e.toJson()))
          .toList());
    } else {
      logger.w("updateAssignState: newServiceList is empty");
    }
  }
}
