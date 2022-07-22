
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/src/enums/service_changed_type_enum.dart';
import 'package:tuple/tuple.dart';

import '../const_names.dart';

class ServiceMonitoringRepository {
  static Logger logger = Logger();

  CollectionReference serviceCollection = FirebaseFirestore.instance.collection(SERVICE_COLLECTION_NAME);
  Query<Map<String, dynamic>> serviceGroupCollection = FirebaseFirestore.instance.collectionGroup("Service");

  // Tuple3.item2: order guid
  StreamController<Tuple3<ServiceChangedTypeEnum,String,ServiceModel>> orderServiceStreamController = StreamController.broadcast();
  final Map<String,StreamSubscription> _monitoringOrderGuids = {};
  final Map<String,StreamSubscription> _monitoringServiceGuids = {};
  final Map<String,StreamSubscription> _monitoringMasterUid = {};
  ServiceMonitoringRepository();

  Future<void> monitorSingleService(String hostUid, String orderGuid, String serviceGuid) async {
    if (_monitoringServiceGuids.containsKey(serviceGuid)) {
      return;
    }
    _monitoringServiceGuids[serviceGuid] = serviceCollection
        .doc(hostUid)
        .collection(orderGuid)
        .doc(serviceGuid)
        .snapshots().listen((snapshot) {
      if (snapshot.exists) {
        logger.v(snapshot.data());
        ServiceModel serviceModel = ServiceModel.fromJson(snapshot.data() as Map<String, dynamic>);
        orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED, orderGuid, serviceModel));
      }
    });
  }

  Future<void> monitorAllServiceByOrderGuidList(List<String> orderGuidList,{DateTime? ignoreAddBeforeItCreated})async {
    var notMonitoringOrderGuid = orderGuidList.toSet().difference(_monitoringOrderGuids.keys.toSet());
    if (notMonitoringOrderGuid.isNotEmpty){
      logger.d("monitorAllServiceByOrderGuidList: total:${notMonitoringOrderGuid.length} is not monitoring.");
      logger.v(notMonitoringOrderGuid);
      for (var orderGuid in notMonitoringOrderGuid) {
        monitorServiceListByOrderGuid(orderGuid,ignoreCreatedAtBefore: ignoreAddBeforeItCreated);
      }
    }else{
      logger.d("monitorAllServiceByOrderGuidList: total:${orderGuidList.length - notMonitoringOrderGuid.length} is monitoring.");
    }
  }
  Future<void> monitorServiceListByOrderGuid(String orderGuid,{DateTime? ignoreCreatedAtBefore}) async {
    if (_monitoringOrderGuids.containsKey(orderGuid)) {
      logger.i("monitorServiceListByOrderGuid: Already monitoring order guid: $orderGuid");
      return;
    }
    logger.i("monitorServiceListByOrderGuid: Monitoring order guid: $orderGuid and ignoreCreatedAtBefore: $ignoreCreatedAtBefore");
    _monitoringOrderGuids[orderGuid] = serviceGroupCollection.where('orderGuid',isEqualTo: orderGuid)
        .snapshots()
        .listen((event) {
      for (var changedData in event.docChanges) {
        if (changedData.doc.exists){
          // convert to model
          ServiceModel serviceModel = ServiceModel.fromJson(changedData.doc.data()!);
          logger.v("monitorServiceListByOrderGuid: ${changedData.type.name} ${serviceModel.toJson()}");
          // handle changedType by changedData.type with switch-case
          switch (changedData.type) {
            case DocumentChangeType.added:
              // only handle if createdAt is after ignoreCreatedAtBefore
              if (ignoreCreatedAtBefore == null || serviceModel.createdAt.isAfter(ignoreCreatedAtBefore)){
                orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.ADDED,orderGuid,serviceModel));
              }else{
                logger.d("monitorServiceListByOrderGuid: ignore ${serviceModel.guid} which createdAt is before ignoreCreatedAtBefore");
              }
              break;
            case DocumentChangeType.modified:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED,orderGuid,serviceModel));
              break;
            case DocumentChangeType.removed:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.REMOVED,orderGuid,serviceModel));
              if (_monitoringOrderGuids.containsKey(orderGuid)){
                _monitoringOrderGuids[orderGuid]?.cancel();
                _monitoringOrderGuids.remove(orderGuid);
              }else{
                logger.w("monitorServiceListByOrderGuid: orderGuid: $orderGuid not found in monitoringOrderGuid");
              }

              break;
          }
        }
        else{
          logger.w("monitorServiceListByOrderGuid: service not found");
        }
      }
    });
  }
  Future<void> monitorServiceListByMasterUid(String masterUid,DateTime afterDoneAt,{DateTime? ignoreCreatedAtBefore}) async{
    logger.i("monitorServiceListByMasterUid: Monitoring for masterUid: $masterUid and ignoreCreatedAtBefore: $ignoreCreatedAtBefore");
    // var whereNotInList =[
    //   ServiceStateEnum.NoMasterSelected.name,
    //   ServiceStateEnum.Preparing.name,
    //   ServiceStateEnum.Assigning.name];
    // .where("state",whereNotIn: whereNotInList)
    _monitoringMasterUid[masterUid] = serviceGroupCollection.where('masterUid',isEqualTo: masterUid)
        .snapshots()
        .listen((event) {
      for (var changedData in event.docChanges) {
        if (changedData.doc.exists){
          // convert to model
          ServiceModel serviceModel = ServiceModel.fromJson(changedData.doc.data()!);
          logger.v("monitorServiceListByMasterUid: ${changedData.type.name} ${serviceModel.toJson()}");
          // handle changedType by changedData.type with switch-case
          switch (changedData.type) {
            case DocumentChangeType.added:
              // only handle if createdAt is after ignoreCreatedAtBefore
              if (ignoreCreatedAtBefore == null || serviceModel.createdAt.isAfter(ignoreCreatedAtBefore)){
                orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.ADDED,serviceModel.orderGuid,serviceModel));
              }else{
                logger.d("monitorServiceListByMasterUid: ignore ${serviceModel.guid} which createdAt is before ignoreCreatedAtBefore");
              }
              break;
            case DocumentChangeType.modified:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED,serviceModel.orderGuid,serviceModel));
              break;
            case DocumentChangeType.removed:
              if (_monitoringMasterUid.containsKey(masterUid)){
                _monitoringMasterUid[masterUid]?.cancel();
                _monitoringMasterUid.remove(masterUid);
              }else{
                logger.w("monitorServiceListByMasterUid: masterUid: $masterUid not found in monitoringMasterUid");
              }

              break;
          }
        }
        else{
          logger.w("monitorServiceListByMasterUid: service not found");
        }
      }
    });
    _monitoringMasterUid[masterUid] = serviceGroupCollection.where('masterUid',isEqualTo: masterUid)
        .orderBy("doneAt",descending: true)
        .startAfter([afterDoneAt])
        .snapshots()
        .listen((event) {
      for (var changedData in event.docChanges) {
        if (changedData.doc.exists){
          // convert to model
          ServiceModel serviceModel = ServiceModel.fromJson(changedData.doc.data()!);
          logger.v("monitorServiceListByMasterUid: ${changedData.type.name} ${serviceModel.toJson()}");
          // handle changedType by changedData.type with switch-case
          switch (changedData.type) {
            case DocumentChangeType.added:
            // only handle if createdAt is after ignoreCreatedAtBefore
              if (ignoreCreatedAtBefore == null || serviceModel.createdAt.isAfter(ignoreCreatedAtBefore)){
                orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.ADDED,serviceModel.orderGuid,serviceModel));
              }else{
                logger.d("monitorServiceListByMasterUid: ignore ${serviceModel.guid} which createdAt is before ignoreCreatedAtBefore");
              }
              break;
            case DocumentChangeType.modified:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED,serviceModel.orderGuid,serviceModel));
              break;
            case DocumentChangeType.removed:
              if (_monitoringMasterUid.containsKey(masterUid)){
                _monitoringMasterUid[masterUid]?.cancel();
                _monitoringMasterUid.remove(masterUid);
              }else{
                logger.w("monitorServiceListByMasterUid: masterUid: $masterUid not found in monitoringMasterUid");
              }
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.REMOVED,serviceModel.orderGuid,serviceModel));
              break;
          }
        }
        else{
          logger.w("monitorServiceListByMasterUid: service not found");
        }
      }
    });
  }
}