
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/service_changed_type_enum.dart';
import 'package:tuple/tuple.dart';

import 'const_names.dart';

class ServiceMonitoringRepository {
  static Logger logger = Logger();

  CollectionReference serviceCollection = FirebaseFirestore.instance.collection(SERVICE_COLLECTION_NAME);
  Query<Map<String, dynamic>> serviceGroupCollection = FirebaseFirestore.instance.collectionGroup("Service");

  // Tuple3.item2: order guid
  StreamController<Tuple3<ServiceChangedTypeEnum,String,ServiceModel>> orderServiceStreamController = StreamController.broadcast();
  final List<String> _monitoringOrderGuids = [];
  ServiceMonitoringRepository();

  Future<void> monitorSingleService(String hostUid, String orderGuid, String serviceGuid) async {
    if (_monitoringOrderGuids.contains(serviceGuid)) {
      return;
    }
    serviceCollection.doc(hostUid).collection(orderGuid).doc(serviceGuid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        logger.v(snapshot.data());
        ServiceModel serviceModel = ServiceModel.fromJson(snapshot.data() as Map<String, dynamic>);
        orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED, orderGuid, serviceModel));
      }
    });
    _monitoringOrderGuids.add(serviceGuid);
  }

  Future<void> monitorServiceListByOrderGuid(String orderGuid,{DateTime? ignoreCreatedAtBefore}) async {
    if (_monitoringOrderGuids.contains(orderGuid)) {
      logger.i("monitorServiceListByOrderGuid: Already monitoring order guid: $orderGuid");
      return;
    }
    logger.i("monitorServiceListByOrderGuid: Monitoring order guid: $orderGuid and ignoreCreatedAtBefore: $ignoreCreatedAtBefore");
    serviceGroupCollection.where('orderGuid',isEqualTo: orderGuid)
        .snapshots()
        .listen((event) {
      for (var changedData in event.docChanges) {
        if (changedData.doc.exists){
          // convert to model
          ServiceModel serviceModel = ServiceModel.fromJson(changedData.doc.data()!);
          logger.v("monitorServiceByOrderGuid: ${changedData.type.name} ${serviceModel.toJson()}");
          // handle changedType by changedData.type with switch-case
          switch (changedData.type) {
            case DocumentChangeType.added:
              // only handle if createdAt is after ignoreCreatedAtBefore
              if (ignoreCreatedAtBefore == null || serviceModel.createdAt.isAfter(ignoreCreatedAtBefore)){
                orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.ADDED,orderGuid,serviceModel));
              }else{
                logger.d("monitorServiceByOrderGuid: ignore ${serviceModel.guid} which createdAt is before ignoreCreatedAtBefore");
              }
              break;
            case DocumentChangeType.modified:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.CHANGED,orderGuid,serviceModel));
              break;
            case DocumentChangeType.removed:
              orderServiceStreamController.add(Tuple3(ServiceChangedTypeEnum.REMOVED,orderGuid,serviceModel));
              break;
          }
        }
        else{
          logger.w("monitorServiceByOrderGuid: service not found");
        }
      }
    });
    _monitoringOrderGuids.add(orderGuid);
  }
}