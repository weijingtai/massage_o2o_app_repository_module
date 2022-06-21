import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:tuple/tuple.dart';

import '../../config.dart';
import '../config/activated_order_repository_config.dart';
import '../const_names.dart';
import '../enums/order_list_updated_type_enum.dart';

/// class OrderMonitoringRepository
class OrderMonitoringRepository {
  static var logger = Logger();

  /// only do monitoring for 'false'
  bool isPreparingMonitored = false;
  bool isAppointmentMonitored = false;


  CollectionReference activatedOrderCollection = FirebaseFirestore.instance.collection(ACTIVATED_ORDER_COLLECTION_NAME);

  StreamController<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> monitorStreamController = StreamController.broadcast();
  StreamController<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> monitorCreatingStreamController = StreamController.broadcast();
  StreamController<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> monitorAssigningStreamController = StreamController.broadcast();


  StreamController<Tuple2<OrderListUpdatedTypeEnum,OrderModel?>> singleOrderStreamController = StreamController.broadcast();
  Map<String,OrderModel> monitoringOrderGuid = {};

  RepositoryConfig repositoryConfig;
  ActivatedOrderRepositoryConfig get config => repositoryConfig.activatedOrderRepositoryConfig;

  OrderMonitoringRepository({required this.repositoryConfig});

  String? getCollectionNameByOrderState(OrderStatusEnum orderState){
    switch(orderState){
      case OrderStatusEnum.Creating:
      case OrderStatusEnum.Assigning:
        return ORDER_COLLECTION_NAME_PREPARING;
      case OrderStatusEnum.Waiting:
        return ORDER_COLLECTION_NAME_APPOINTMENT;
      case OrderStatusEnum.Canceled:
      case OrderStatusEnum.Completed:
        return ORDER_COLLECTION_NAME_ARCHIVED;
      case OrderStatusEnum.Serving:
        return ORDER_COLLECTION_NAME_SERVING;
      default:
        return null;
    }
  }

  Future<void> monitorActivatedOrder(String hostUid,String orderGuid,{bool isActivated = true}) async {
    if (monitoringOrderGuid.isEmpty || !monitoringOrderGuid.containsKey(orderGuid)){
      FirebaseFirestore.instance
          .collectionGroup(isActivated?config.activatedSubCollectionName:config.archivedSubCollectionName)
          .where("hostUid",isEqualTo: hostUid)
          .where(config.orderGuidFieldName,isEqualTo: orderGuid)
          .snapshots()
          .listen((snapshot){
        if (snapshot.docs.isNotEmpty){
          // convert Map to OrderModel
          OrderModel model = OrderModel.fromJson(snapshot.docs.first.data());
          logger.v(model);
          // when monitoring success, Order will be get from snapshot
          // check if the order is not in monitoringOrderGuid
          // add it to monitoringOrderGuid
          // if the order is in monitoringOrderGuid, do nothing
          if (!monitoringOrderGuid.containsKey(orderGuid)){
            logger.d("orderGuid monitoring success");
            monitoringOrderGuid[orderGuid] = model;
            singleOrderStreamController.sink.add(Tuple2(OrderListUpdatedTypeEnum.added,model));
          }else{
            logger.d("order update success.");
            singleOrderStreamController.sink.add(Tuple2(OrderListUpdatedTypeEnum.updated,model));
          }
        }
        else{
          // when orderGuid in local monitoringOrderGuid, but not in firestore, remove it from monitoringOrderGuid
          // and send OrderListUpdatedTypeEnum.removed
          if (monitoringOrderGuid.containsKey(orderGuid)){
            logger.d("orderGuid monitoring removed");
            var model = monitoringOrderGuid.remove(orderGuid);
            if (model != null){
              singleOrderStreamController.sink.add(Tuple2(OrderListUpdatedTypeEnum.deleted,model));
            }
          }else{
            logger.w("monitorActivatedOrder: not found activated order");
            singleOrderStreamController.sink.add(const Tuple2(OrderListUpdatedTypeEnum.NotFound,null));
          }
        }
      });
    }
    else{
      logger.i("monitorSingleOrder: order:$orderGuid already monitored.");
      singleOrderStreamController.sink.add(Tuple2(OrderListUpdatedTypeEnum.added,monitoringOrderGuid[orderGuid]));
    }
  }
  ///
  /// monitor order list
  Future<void> _monitorOrderCollection(String hostUid,String collectionName,StreamController<Tuple2<OrderListUpdatedTypeEnum,OrderModel>> streamController,{DateTime? lastFullFetchAt}) async {
    logger.d("_monitorOrderCollection: start monitoring $collectionName");
    activatedOrderCollection
        .doc(hostUid)
        .collection(collectionName)
        .snapshots()
        .listen((event) {
      for (var changedData in event.docChanges) {
        switch (changedData.type) {
          case DocumentChangeType.added:
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              logger.v("$collectionName added, order.createdAt isAfter lastFullFetchTime sink.add ");
              if (lastFullFetchAt == null){
                logger.v("monitorPreparingOrders: without lastFullFetchAt ,sink.add order.");
                streamController.sink.add(
                    Tuple2(OrderListUpdatedTypeEnum.added, order));
              }else{
                var lastFullFetchTime = lastFullFetchAt;
                if (order.createdAt.isAfter(lastFullFetchTime)) {
                  logger.v(
                      "$collectionName added, order.createdAt isAfter lastFullFetchTime sink.add ");
                  streamController.sink.add(
                      Tuple2(OrderListUpdatedTypeEnum.added, order));
                } else {
                  logger.v(
                      "$collectionName added, order.createdAt isBefore lastFullFetchTime ignore. ");
                }
              }
            }
            break;
          case DocumentChangeType.modified:
            logger.v("$collectionName: order updated.");
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              logger.d("$collectionName: order${order.guid} updated.");
              // ActivatedOrderListUpdatedEvent([order]);
              streamController.sink.add(
                  Tuple2(OrderListUpdatedTypeEnum.updated, order));
            }
            break;
          case DocumentChangeType.removed:
            logger.v("$collectionName: order removed.");
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              logger.d("$collectionName: order${order.guid} removed.");
              // ActivatedOrderListUpdatedEvent([order]);
              streamController.sink.add(
                  Tuple2(OrderListUpdatedTypeEnum.deleted, order));
            }
            break;
        }
      }
    });
  }

  /// method to monitor 'ActivatedOrder' collection
  /// monitoring order by order.status
  /// with order.status is 'Completed' or 'Cancelled' order is 'archived'
  /// @param withArchived: is 'true' will monitoring '/ActivatedOrder/<HOST_UID>/archived' collection
  /// @param ignoreBeforeCreatedAt:  when order.createdAt is before ignoreBeforeCreatedAt, ignore it when added
  startMonitoringActivatedOrders(String hostUid,{bool withArchived = true,DateTime? ignoreBeforeAt}) async {
    logger.d("startMonitoringActivatedOrders: start monitoring ActivatedOrder collection");
    // monitor draft order collection, status is 'None'
    // monitor creating order collection, status is 'Creating'
    // monitor assigning order collection, status is 'Assigning'
    // monitor appointment order collection, status is 'Waiting'
    // monitor serving order collection, status is 'Serving'
    // monitor today-archived order collection, status is 'Completed' or 'Cancelled'

    List<Future> allMonitoringFutures = [
      monitorDraftOrders(hostUid,monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
      _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Creating, monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
      _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Assigning, monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
      // monitorAssigningOrders(hostUid,monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
      monitorWaitingOrders(hostUid,monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
      monitorServingOrders(hostUid,monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt),
    ];
    if (withArchived) {
      allMonitoringFutures.add(monitorTodayArchivedOrders(hostUid,monitorStreamController.sink,ignoreBeforeAt: ignoreBeforeAt));
    }
    return Future.wait(allMonitoringFutures);
  }
  Future<void> monitorDraftOrders(String hostUid,StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,{DateTime? ignoreBeforeAt}) async {
    logger.d("monitorCreatingOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/${config.activatedSubCollectionName}?status=None' collection");
    return _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.None, sink,ignoreBeforeAt: ignoreBeforeAt);
  }

  Future<void> monitorServingOrders(String hostUid,StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,{DateTime? ignoreBeforeAt}){
    logger.d("monitorCreatingOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/${config.activatedSubCollectionName}?status=Serving' collection");
    return _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Serving, sink,ignoreBeforeAt: ignoreBeforeAt);
  }
  Future<void> monitorWaitingOrders(String hostUid,StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,{DateTime? ignoreBeforeAt}){
    logger.d("monitorCreatingOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/${config.activatedSubCollectionName}?status=Waiting' collection");
    return _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Waiting, sink,ignoreBeforeAt: ignoreBeforeAt);
  }
  Future<void> monitorAssigningOrders(String hostUid,{DateTime? ignoreBeforeAt}){
    logger.d("monitorCreatingOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/${config.activatedSubCollectionName}?status=Assigning' collection");
    return _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Assigning, monitorAssigningStreamController.sink,ignoreBeforeAt: ignoreBeforeAt);
  }
  Future<void> monitorCreatingOrders(String hostUid,{DateTime? ignoreBeforeAt}){
    logger.d("monitorCreatingOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/${config.activatedSubCollectionName}?status=Creating' collection");
    return _monitorActivatedOrderCollectionByStatus(hostUid, OrderStatusEnum.Creating, monitorCreatingStreamController.sink,ignoreBeforeAt: ignoreBeforeAt);
  }

  Future<void> monitorTodayArchivedOrders(String hostUid,StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,{DateTime? ignoreBeforeAt}) async {
    logger.i("monitorCompletedOrders: start monitoring '/${activatedOrderCollection.path}/<HOST_UID>/<TODAY_ARCHIVED>' collection");
    activatedOrderCollection
        .doc(hostUid)
        .collection(config.archivedSubCollectionName)
        .snapshots()
        .listen((event)=>handleListenEvent(event,OrderListTypeEnum.todayCompleted,sink,ignoreBeforeCreateAt: ignoreBeforeAt));
  }
  Future<void> _monitorActivatedOrderCollectionByStatus(String hostUid,OrderStatusEnum status,StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,{DateTime? ignoreBeforeAt}) async {
    var type = _getOrderListType(status);
    activatedOrderCollection
        .doc(hostUid)
        .collection(config.activatedSubCollectionName)
        .where("status", isEqualTo: status.name)
        .snapshots()
        .listen((event)=>handleListenEvent(event,type,sink,ignoreBeforeCreateAt: ignoreBeforeAt));
  }
  void handleListenEvent(
      QuerySnapshot<Map<String,dynamic>> event,
      OrderListTypeEnum type,
      StreamSink<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> sink,
      {
        DateTime? ignoreBeforeCreateAt,
      }){
    DateTime ignoreBeforeAt = ignoreBeforeCreateAt ?? DateTime.now();
    for (var changedData in event.docChanges) {
      if (changedData.doc.exists){
        var order = OrderModel.fromJson(changedData.doc.data()!);
        logger.d("activated order:${order.guid} changedData.type: ${changedData.type}, with status: ${order.status}");
      }
      switch (changedData.type) {
        case DocumentChangeType.added:
          if (changedData.doc.exists) {
            var order = OrderModel.fromJson(changedData.doc.data()!);
            if (order.createdAt.isBefore(ignoreBeforeAt)){
              logger.d("ignore order:${order.guid} with status: ${order.status}");
            }else{
              logger.d("_monitorOrdersByStatus: $type order:${order.guid} added.");
              sink.add(Tuple3(type,OrderListUpdatedTypeEnum.added,order));
            }
          }
          break;
        case DocumentChangeType.modified:
          if (changedData.doc.exists) {
            var order = OrderModel.fromJson(changedData.doc.data()!);
            logger.d("_monitorOrdersByStatus: $type order:${order.guid} modified.");
            sink.add(Tuple3(type,OrderListUpdatedTypeEnum.updated,order));
          }
          break;
        case DocumentChangeType.removed:
          if (changedData.doc.exists) {
            var order = OrderModel.fromJson(changedData.doc.data()!);
            logger.d("_monitorOrdersByStatus: $type order:${order.guid} removed.");
            sink.add(Tuple3(type,OrderListUpdatedTypeEnum.deleted,order));
          }
          break;
      }
    }
  }

  OrderListTypeEnum _getOrderListType(OrderStatusEnum status){
    OrderListTypeEnum type;
    switch(status){
      case OrderStatusEnum.Serving:
        type = OrderListTypeEnum.serving;
        break;
      case OrderStatusEnum.Waiting:
        type = OrderListTypeEnum.appointment;
        break;
      case OrderStatusEnum.Assigning:
        type = OrderListTypeEnum.assigning;
        break;
      case OrderStatusEnum.Creating:
        type = OrderListTypeEnum.creating;
        break;
      case OrderStatusEnum.Completed:
      case OrderStatusEnum.Canceled:
        type = OrderListTypeEnum.todayCompleted;
        break;
      case OrderStatusEnum.None:
        type = OrderListTypeEnum.draft;
        break;
    }
    return type;
  }

}