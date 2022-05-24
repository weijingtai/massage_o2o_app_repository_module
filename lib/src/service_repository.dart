
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'const_names.dart';

class ServiceRepository {
  static Logger logger = Logger();
  // CollectionReference orderCollection = FirebaseFirestore.instance.collection(ACTIVATED_ORDER_COLLECTION_NAME);
  // Query serviceCollectionGroup = FirebaseFirestore.instance.collectionGroup(SERVICES_COLLECTION_NAME);
  CollectionReference serviceCollection = FirebaseFirestore.instance.collection(SERVICE_COLLECTION_NAME);

  // CollectionReference orderCollection = FirebaseFirestore.instance.collection(ORDER_COLLECTION_NAME);
  ServiceRepository();

  Future<void> addAll(List<ServiceModel> serviceList) async {
    if (serviceList.isEmpty){
      logger.w("addAll serviceList is empty");
      return;
    }
    // map serviceModel to orderGuid and reduce
    Map<String, List<ServiceModel>> serviceMap = {};
    for (ServiceModel service in serviceList) {
      serviceMap[service.orderGuid] ??= [];
      serviceMap[service.orderGuid]!.add(service);
    }
    logger.d("addAll total:${serviceMap.length} orderGuids, and ${serviceList.length} services");
    await Future.wait(serviceMap.entries.map((entry)=>_remoteCreateServices(entry.key, entry.value)).toList());
    return ;
  }
  Future<void> _remoteCreateServices(String orderGuid,List<ServiceModel> services){
    // add each service /Service/<SERVICE_GUID>
    List<Future<dynamic>> addToRemoteFutureList = services.map((s)=>serviceCollection.doc(s.guid).set(s.toJson())).toList();
    return Future.wait(addToRemoteFutureList);
  }
  Future<void> deleteAllByOrderGuid(String orderGuid) async {

    // remove from /Service/<SERVICE_GUID>
    var querySnapshot = await serviceCollection.where("orderGuid",isEqualTo: orderGuid).get();
    if (querySnapshot.size > 0 ){
      logger.d("deleteServiceListByOrderGuid: orderGuid: $orderGuid,total:${querySnapshot.docs.length}.");
      List<Future<dynamic>> deleteFromRemoteFutureList = querySnapshot.docs.map((doc) => doc.reference.delete()).toList();
      await Future.wait(deleteFromRemoteFutureList);
    }else{
      logger.w(" deleteServiceListByOrderGuid: no service found for order: $orderGuid.");
    }
    return;
  }
  Future<void> deleteByGuidList(List<String> serviceGuidList) async {
    logger.i("deleteServiceByGuidList: for serviceGuidList: ${serviceGuidList.length}");
    // when serviceList is not null or empty, and length is greater than 9
    // split the list into chunks of 9,
    // delete each chunk
    if (serviceGuidList.isNotEmpty) {
      if (serviceGuidList.length > 9) {
        List<List<String>> chunks = List.generate(serviceGuidList.length ~/ 9, (i) => serviceGuidList.sublist(i * 9, i * 9 + 9));
        // var getFuture = chunks.map((e) => serviceCollectionGroup.where("guid", whereIn: serviceGuidList).get()).toList();
        // var result = await Future.wait(getFuture);
        // result.expand((element) => element.docs).forEach((e) => e.reference.delete());
        var getFuture = chunks.map((e) => serviceCollection.where("guid", whereIn: serviceGuidList).get()).toList();
        var result = await Future.wait(getFuture);
        result.expand((element) => element.docs).forEach((e) => e.reference.delete());
      }else{
        QuerySnapshot querySnapshot = await serviceCollection
            .where("guid", whereIn: serviceGuidList)
            .get();
        for (var e in querySnapshot.docs) {
          e.reference.delete();
        }
      }
    }else{
      logger.w("deleteServiceByGuidList: serviceGuidList is empty");
    }
  }

  Future<ServiceModel?> load(String serviceGuid) async {
    var docSnap = await serviceCollection.doc(serviceGuid).get();
    if (docSnap.exists) {
      return ServiceModel.fromJson(docSnap.data() as Map<String, dynamic>);
    }
    return null;
  }
  Future<List<ServiceModel>> loadAllByOrderGuidList(List<String> orderGuidList) async {
    logger.i("loadAllByOrderGuid: for total: ${orderGuidList.length} orders,");
    if (orderGuidList.isNotEmpty) {
      List<ServiceModel> serviceList = [];
      if (orderGuidList.length <= 9){
        QuerySnapshot querySnapshot = await serviceCollection
            .where("orderGuid", whereIn: orderGuidList)
            .get();
        serviceList = querySnapshot.docs.where((e) => e.exists).map((e) => ServiceModel.fromJson((e.data()! as Map<String,dynamic>))).toList();
      }else{
        // split orderGuidList into chunks of 9
        List<List<String>> orderGuidListChunks = List.generate(orderGuidList.length~/9, (index) => orderGuidList.sublist(index*9, (index+1)*9));
        // generate future querySnapshot for each chunk
        // List<Future<QuerySnapshot>> querySnapshotList = orderGuidListChunks.map((e) => serviceCollectionGroup
        //     .where("orderGuid", whereIn: e)
        //     .get())
        //     .toList();
        List<Future<QuerySnapshot>> querySnapshotList = orderGuidListChunks
            .map((e) => serviceCollection
            .where("orderGuid", whereIn: e)
            .get())
            .toList();
        var allResult = await Future.wait(querySnapshotList);
        // flatmap  all result to serviceList
        serviceList = allResult.map((e) => e.docs).expand((e) => e).where((e) => e.exists).map((e) => ServiceModel.fromJson((e.data()! as Map<String,dynamic>))).toList();
      }
      logger.i("loadAllByOrderGuid: for total: ${orderGuidList.length} orders, loaded: ${serviceList.length}");
      return serviceList;
    }else{
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
    QuerySnapshot snapshot = await serviceCollection.where("serviceList",isEqualTo: orderGuid).get();
    if (snapshot.docs.isNotEmpty){
      List<ServiceModel> serviceList = snapshot.docs.where((e) => e.exists).map((e) => ServiceModel.fromJson((e.data()! as Map<String,dynamic>))).toList();
      if (serviceList.isNotEmpty){
        logger.d("loadAll: for order: $orderGuid with serviceList: ${serviceList.length}");
        return serviceList;
      }
    }
    logger.d("loadAll: for order: $orderGuid with serviceList: 0");
    return [];
  }

  Future<void> updateService(ServiceModel service) async {
    logger.i("updateService: service:${service.guid}");
    logger.v(service.toJson());
    await serviceCollection
        .doc(service.guid)
        .set(service.toJson(), SetOptions(merge: true));
  }
  Future<void> updateServiceWithField(String serviceGuid, Map<String,dynamic> updatedField) async {
    logger.i("updateServiceWithField: service:$serviceGuid, updatedField:$updatedField");
    await serviceCollection
        .doc(serviceGuid)
        .update(updatedField);
        // .set(updatedField, SetOptions(merge: true)); // merge: true will update the field, not replace it
        // warming: 'set' is not accepting '<childName>.<childFiledName>'
  }
  Future<void> deleteAssign(String serviceGuid) async {
    logger.i("updateService: service:$serviceGuid");
    await serviceCollection
        .doc(serviceGuid)
        .update({"assign": FieldValue.delete(),"masterUid":FieldValue.delete()});
  }

  Future<void> updateServiceList(List<ServiceModel> newServiceList) async {
    // split newServiceList by orderGuid

    logger.i("updateAssignState: total:${newServiceList.length} new service list");
    if (newServiceList.isNotEmpty){
      await Future.wait(newServiceList.map((e) => serviceCollection.doc(e.guid).update(e.toJson())).toList());
    }else{
      logger.w("updateAssignState: newServiceList is empty");
    }
  }

}