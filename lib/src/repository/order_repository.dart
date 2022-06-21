
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:quiver/iterables.dart';
import 'package:tuple/tuple.dart';

import '../../config.dart';
import '../config/activated_order_repository_config.dart';
import '../const_names.dart';
import '../enums/order_list_updated_type_enum.dart';

class OrderRepository{
  static var logger = Logger();

  RepositoryConfig repositoryConfig;
  ActivatedOrderRepositoryConfig get config => repositoryConfig.activatedOrderRepositoryConfig;
  FirebaseFirestore firebaseInstance;
  OrderRepository({
    required this.repositoryConfig,
    required this.firebaseInstance
  }){
    activatedOrderGroup = firebaseInstance.collectionGroup(repositoryConfig.activatedOrderRepositoryConfig.collectionName);
    orderCollection = firebaseInstance.collection(repositoryConfig.activatedOrderRepositoryConfig.activatedSubCollectionName);
  }


  final Map<String,DateTime> fullFetchDateMapper = {};
  late Query<Map<String, dynamic>> activatedOrderGroup;
  late CollectionReference orderCollection;
  // CollectionReference orderCollection = FirebaseFirestore.instance.collection(ORDER_COLLECTION_NAME);
  // CollectionReference activatedOrderCollection = FirebaseFirestore.instance.collection(ACTIVATED_ORDER_COLLECTION_NAME);

  bool todayMonitored = false;
  bool servingMonitored = false;
  bool appointmentMonitored = false;
  bool preparingMonitored = false;

  bool isPreparingMonitored = false;



  List<OrderModel> displayedCreatingOrders = [];
  StreamController<Tuple3<OrderListTypeEnum,OrderListUpdatedTypeEnum,OrderModel>> activatedStreamController = StreamController.broadcast();
  StreamController<Tuple2<OrderListUpdatedTypeEnum,OrderModel>> preparingStreamController = StreamController.broadcast();
  StreamController<Tuple2<OrderListUpdatedTypeEnum,OrderModel>> appointmentStreamController = StreamController.broadcast();

  bool isMasterAssigningMonitored = false;
  StreamController<Tuple2<OrderListUpdatedTypeEnum,OrderModel>> masterAssigningStreamController = StreamController.broadcast();

  /// role = [Master] only
  Future<void> monitorMasterAssigningOrders(String hostUid,String orderGuid) async {
    logger.i("monitorMasterAssigningOrders");
    if (!isMasterAssigningMonitored){
      var collectionName = ORDER_COLLECTION_NAME_PREPARING;
      orderCollection
          .doc(hostUid)
          .collection(collectionName)
          .doc(orderGuid)
          .snapshots()
          .listen((event) {
            if (event.exists){
              var order = OrderModel.fromJson(event.data()!);
              logger.d("monitorMasterAssigningOrders: order.guid = ${order.guid}");
            }else{
              logger.d("monitorMasterAssigningOrders: order.guid = $orderGuid is null");
            }
          });
      isMasterAssigningMonitored = true;
    }
  }

  Future<void> monitorPreparingOrders(String hostUid) async {
    logger.i("monitorPreparingOrders");
    if (!isPreparingMonitored){
      var collectionName = config.activatedSubCollectionName;
      orderCollection
          .doc(hostUid)
          .collection(collectionName)
          .snapshots()
          .listen((event) {
        event.docChanges.forEach((changedData) {
          switch (changedData.type) {
            case DocumentChangeType.added:
              if (changedData.doc.exists) {
                var order = OrderModel.fromJson(changedData.doc.data()!);
                var lastFullFetchTime = fullFetchDateMapper[collectionName] ??
                    DateTime.now();
                if (order.createdAt.isAfter(lastFullFetchTime)) {
                  logger.v(
                      "$collectionName added, order.createdAt isAfter lastFullFetchTime sink.add ");
                  preparingStreamController.sink.add(
                      Tuple2(OrderListUpdatedTypeEnum.added, order));
                } else {
                  logger.v(
                      "$collectionName added, order.createdAt isBefore lastFullFetchTime ignore. ");
                }
              }
              break;
            case DocumentChangeType.modified:
              logger.v("$collectionName: order updated.");
              if (changedData.doc.exists) {
                var order = OrderModel.fromJson(changedData.doc.data()!);
                logger.d("$collectionName: order${order.guid} updated.");
                // ActivatedOrderListUpdatedEvent([order]);
                preparingStreamController.sink.add(
                    Tuple2(OrderListUpdatedTypeEnum.updated, order));
              }
              break;
            case DocumentChangeType.removed:
              logger.v("$collectionName: order removed.");
              if (changedData.doc.exists) {
                var order = OrderModel.fromJson(changedData.doc.data()!);
                logger.d("$collectionName: order${order.guid} removed.");
                // ActivatedOrderListUpdatedEvent([order]);
                preparingStreamController.sink.add(
                    Tuple2(OrderListUpdatedTypeEnum.deleted, order));
              }
              break;
          }
        });
      });
      isPreparingMonitored = true;
    }

    // await _monitoringActivatedOrderList(hostUid, OrderListTypeEnum.preparing, preparingStreamController);
  }

  Future<void> monitorAppointmentOrders(String hostUid) async {
    logger.i("monitorAppointmentOrders");
    var collectionName = ORDER_COLLECTION_NAME_APPOINTMENT;
    orderCollection
        .doc(hostUid)
        .collection(collectionName)
        .snapshots()
        .listen((event) {
      event.docChanges.forEach((changedData) {
        switch (changedData.type) {
          case DocumentChangeType.added:
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              var lastFullFetchTime = fullFetchDateMapper[collectionName] ??
                  DateTime.now();
              if (order.createdAt.isAfter(lastFullFetchTime)) {
                logger.v(
                    "$collectionName added, order.createdAt isAfter lastFullFetchTime sink.add ");
                appointmentStreamController.sink.add(
                    Tuple2(OrderListUpdatedTypeEnum.added, order));
              } else {
                logger.v(
                    "$collectionName added, order.createdAt isBefore lastFullFetchTime ignore. ");
              }
            }
            break;
          case DocumentChangeType.modified:
            logger.v("$collectionName: order updated.");
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              logger.d("$collectionName: order${order.guid} updated.");
              // ActivatedOrderListUpdatedEvent([order]);
              appointmentStreamController.sink.add(
                  Tuple2(OrderListUpdatedTypeEnum.updated, order));
            }
            break;
          case DocumentChangeType.removed:
            logger.v("$collectionName: order removed.");
            if (changedData.doc.exists) {
              var order = OrderModel.fromJson(changedData.doc.data()!);
              logger.d("$collectionName: order${order.guid} removed.");
              // ActivatedOrderListUpdatedEvent([order]);
              appointmentStreamController.sink.add(
                  Tuple2(OrderListUpdatedTypeEnum.deleted, order));
            }
            break;
        }
      });
    });
    // await _monitoringActivatedOrderList(hostUid, OrderListTypeEnum.preparing, preparingStreamController);
  }

  /// method will monitoring the order collection of _preparing collection, and set the preparingStream
  /// only when preparingStream is null
  /// [hostUid] is the uid of the host
  Future<void> _monitoringTodayCompletedOrders(String hostUid) async {
    if (!todayMonitored){
      orderCollection
          .doc(hostUid)
          .collection(config.archivedSubCollectionName)
          .where("allDoneAt", isEqualTo: DateFormat("yyyy-MM-dd").format(DateTime.now()))
          .snapshots()
          .listen((event) {
        event.docChanges.forEach((changedData) {
          switch (changedData.type){
            case DocumentChangeType.added:
              logger.d("monitoringTodayCompletedOrders: new order added");
              if (changedData.doc.exists){
                var order = OrderModel.fromJson(changedData.doc.data()!);
                logger.d("monitoringTodayCompletedOrders: order${order.guid} created.");
                activatedStreamController.sink.add(Tuple3(OrderListTypeEnum.todayCompleted,OrderListUpdatedTypeEnum.added, order));
              }
              break;
            case DocumentChangeType.modified:
              logger.d("monitoringTodayCompletedOrders: order updated.");
              if (changedData.doc.exists){
                var order = OrderModel.fromJson(changedData.doc.data()!);
                logger.d("monitoringTodayCompletedOrders: order${order.guid} updated.");
                // ActivatedOrderListUpdatedEvent([order]);
                activatedStreamController.sink.add(Tuple3(OrderListTypeEnum.todayCompleted,OrderListUpdatedTypeEnum.updated, order));
              }
              break;
            case DocumentChangeType.removed:
              logger.d("monitoringTodayCompletedOrders: order removed.");
              if (changedData.doc.exists){
                var order = OrderModel.fromJson(changedData.doc.data()!);
                logger.d("monitoringTodayCompletedOrders: order${order.guid} removed.");
                // ActivatedOrderListUpdatedEvent([order]);
                activatedStreamController.sink.add(Tuple3(OrderListTypeEnum.todayCompleted,OrderListUpdatedTypeEnum.deleted, order));
              }
              break;
          }
        });

      });
      todayMonitored = true;
    }
  }
  /// notifies OrderStateEnum.Completed should only be ues for todayCompleted list
  String? _getCollectionNameByOrderState(OrderStatusEnum orderState){
    switch(orderState){
      case OrderStatusEnum.Creating:
      case OrderStatusEnum.Assigning:
        return ORDER_COLLECTION_NAME_PREPARING;
      case OrderStatusEnum.Waiting:
        return ORDER_COLLECTION_NAME_APPOINTMENT;
      case OrderStatusEnum.Serving:
        return ORDER_COLLECTION_NAME_SERVING;
      case OrderStatusEnum.Completed:
        return config.archivedSubCollectionName;
    }
    return null;
  }
  Future<OrderModel?> getOrderByState(String orderGuid,String hostUid, OrderStatusEnum orderState) async {
    var collectionName = _getCollectionNameByOrderState(orderState);
    if (collectionName == null){
      logger.e("getWithOrderState: collectionName is null with orderState: $orderState");
      return null;
    }
    var orderDocumentRef =  orderCollection.doc(hostUid).collection(collectionName).doc(orderGuid);
    // load order first
    var order = await orderDocumentRef.get();
    if (order.exists){
      var orderModel = OrderModel.fromJson(order.data()!);

      if (orderModel.status == orderState){
        logger.d("getWithOrderState: load order success.");
        return orderModel;
      }else{
        logger.w("getWithOrderState: orderModel.state is not equal to orderState: $orderState");
      }
    }
    else{
      logger.w("getWithOrderState: order:$orderGuid with state:${orderState.name} is not exist.");
    }
    return null;
  }

  Future<OrderModel?> getAssigningOrder(String hostUid,String orderGuid) async {
    var order = await orderCollection
        .doc(hostUid)
        .collection(ORDER_COLLECTION_NAME_PREPARING)
        .doc(orderGuid)
        .get();
    if (order.exists){
      var orderModel = OrderModel.fromJson(order.data()!);
      logger.i("getAssigningOrder: success.");
      return orderModel;
      // if (orderModel.state == OrderStateEnum.Assigning){
      //   logger.i("getAssigningOrder: success.");
      //   return orderModel;
      // }else{
      //   logger.w("getAssigningOrder: orderModel.state is not equal to OrderStateEnum.Assigning");
      // }
    }else{
      logger.w("getAssigningOrder: order:$orderGuid is not exist.");
    }
    return null;
  }
  Future<OrderModel?> get(String orderGuid,String hostUid,{bool isActivated = true}) async {
    logger.i("load orderModel by hostUid:$hostUid, orderGuid:$orderGuid ${isActivated?"${config.activatedSubCollectionName}":config.archivedSubCollectionName}");
    // creating / assigning / serving / waiting
    var dataSnap = await orderCollection
        .doc(hostUid)
        .collection(isActivated?config.activatedSubCollectionName:config.archivedSubCollectionName)
        .doc(orderGuid.toString())
        .get();
    if (dataSnap.exists){
      return OrderModel.fromJson(dataSnap.data()!);
    }else{
      logger.w("not found by Order/$hostUid/${isActivated?config.activatedSubCollectionName:config.archivedSubCollectionName}/$orderGuid");
      return null;
    }
  }
  Future<List<OrderModel>> loadCreatingOrders(String hostUid) async {
    logger.i("load creating orders by hostUid:$hostUid");
    var dataSnap = await orderCollection
        .doc(hostUid)
        .collection(config.activatedSubCollectionName)
        .orderBy("createdAt",descending: false)
        .where("status",isEqualTo: OrderStatusEnum.Creating.name)
        .get();
    if (dataSnap.docs.isNotEmpty){
      var orders = dataSnap.docs.map((docSnap) => OrderModel.fromJson(docSnap.data())).toList();
      logger.i("load creating orders success.");
      return orders;
    }else{
      return [];
    }
  }
  Future<List<OrderModel>> loadAssigningOrders(String hostUid) async {
    logger.i("load creating orders by hostUid:$hostUid");
    var dataSnap = await orderCollection
        .doc(hostUid)
        .collection(config.activatedSubCollectionName)
        .orderBy("createdAt",descending: false)
        .where("status",isEqualTo: OrderStatusEnum.Assigning.name)
        .get();
    if (dataSnap.docs.isNotEmpty){
      var orders = dataSnap.docs.map((docSnap) => OrderModel.fromJson(docSnap.data())).toList();
      logger.i("load creating orders success.");
      return orders;
    }else{
      return [];
    }
  }

  Future<List<OrderModel>> loadAppointmentOrders(String hostUid) async {
    logger.i("load creating orders by hostUid:$hostUid");
    // if (displayedCreatingOrders.isEmpty){
      var dataSnap = await orderCollection
          .doc(hostUid)
          .collection(ORDER_COLLECTION_NAME_APPOINTMENT)
          .get();
      // displayedCreatingOrders = dataSnap.docs.where((e) => e.exists).map((docSnap) => OrderModel.fromJson(docSnap.data())).toList();
    return dataSnap.docs.where((e) => e.exists).map((docSnap) => OrderModel.fromJson(docSnap.data())).toList();
    // }

    // return displayedCreatingOrders;
  }

  Future<List<List<OrderModel>>> loadActivatedOrders(String hostUid) async {
    // load from collection with collectionName list:
    //  - activated
    //  - archived
    var docRef = orderCollection.doc(hostUid);
    List<QuerySnapshot<Map<String,dynamic>>> allResults = await Future.wait([
      docRef.collection(config.activatedSubCollectionName).get(),
      docRef.collection(config.archivedSubCollectionName).get(),
    ]);
    return allResults.map((e) => e.docs.where((e) => e.exists).map((e) => OrderModel.fromJson(e.data())).toList()).toList();
  }

  Future<OrderModel?> load(String orderGuid) async{
    logger.i("load orderModel by orderGuid:$orderGuid");
    var querySnapshot = await activatedOrderGroup.where(config.orderGuidFieldName,isEqualTo: orderGuid).get();
    if (querySnapshot.docs.isNotEmpty){
      return OrderModel.fromJson(querySnapshot.docs.first.data());
    }else{
      return null;
    }
  }
  // this functions will load all given order's guid
  Future<List<OrderModel>> loadAllByOrderGuids(List<String> orderGuids) async {
    logger.i("loadAllByOrderGuids: with total:${orderGuids.length} orderGuids.");
    logger.v(orderGuids);
    // load from collection with collectionName list:
    //  - activated
    //  - archived
    if (orderGuids.length <= repositoryConfig.whereInLimit){
      QuerySnapshot querySnapshot = await activatedOrderGroup.where(config.orderGuidFieldName,whereIn: orderGuids).get();
      
      if (querySnapshot.size > 0){
        logger.d("loadAllByOrderGuids: success with total ${querySnapshot.size}.");
        return querySnapshot.docs.map((e) => OrderModel.fromJson(e.data() as Map<String,dynamic>)).toList();
      }else{
        logger.d("loadAllByOrderGuids: success with empty.");
        return [];
      }
    }else{
      // partition the orderGuids into several batches
      var batchSize = repositoryConfig.whereInLimit;
      Iterable<Future<QuerySnapshot<Map<String,dynamic>>>> queryFutures =  partition(orderGuids, repositoryConfig.whereInLimit).map((e) => activatedOrderGroup.where(config.orderGuidFieldName,whereIn: e).get());
      List<QuerySnapshot> querySnapshotList = await Future.wait(queryFutures);
      var resultList = querySnapshotList
          .map((e) => e.docs.map((e) => OrderModel.fromJson(e.data() as Map<String,dynamic>)).toList())
          .expand((e) => e);
      if (resultList.isNotEmpty){
        logger.d("loadAllByOrderGuids: success with total ${resultList.length}.");
        return resultList.toList();
      }else{
        logger.d("loadAllByOrderGuids: success with empty.");
        return [];
      }
    }

  }

  Future<List<List<OrderModel>>> loadActivatedOrderList(String hostUid) async {
    // load from collection with collectionName list:
    //  - preparing
    //  - appointment
    //  - serving
    //  - archived where order.allDoneAt is today

    List<QuerySnapshot<Map<String,dynamic>>> allResults = await Future.wait([
      orderCollection.doc(hostUid).collection(ORDER_COLLECTION_NAME_PREPARING).get(),
      orderCollection.doc(hostUid).collection(ORDER_COLLECTION_NAME_APPOINTMENT).get(),
      orderCollection.doc(hostUid).collection(ORDER_COLLECTION_NAME_SERVING).get(),
      orderCollection.doc(hostUid).collection(ORDER_COLLECTION_NAME_ARCHIVED).where("allDoneAt",isEqualTo: DateFormat("yyyy-MM-dd").format(DateTime.now())).get(),
    ]);
    var now = DateTime.now();
    fullFetchDateMapper[ORDER_COLLECTION_NAME_PREPARING] = now;
    fullFetchDateMapper[ORDER_COLLECTION_NAME_APPOINTMENT] = now;
    fullFetchDateMapper[ORDER_COLLECTION_NAME_SERVING] = now;
    fullFetchDateMapper[ORDER_COLLECTION_NAME_ARCHIVED] = now;
    // map QuerySnapshot's documents list to OrderModel list
    return allResults.map((e) => e.docs.where((e) => e.exists).map((e) => OrderModel.fromJson(e.data())).toList()).toList();


  }
  Future<OrderModel?> loadActivatedOrder(String hostUid,String orderGuid) async {
    logger.i("load activated order by hostUid:$hostUid,orderGuid:$orderGuid");
    var snap = await orderCollection
        .doc(hostUid)
        .collection(config.activatedSubCollectionName)
        .doc(orderGuid)
        .get();
    if (snap.exists) {
      logger.v("loadActivatedOrder:${snap.data()}");
      return OrderModel.fromJson(snap.data()!);
    } else {
      logger.w("load activated order by hostUid:$hostUid,orderGuid:$orderGuid not found");
      return null;
    }
  }
  /**
   *  Only 'Date' will be accepted as query params
   */
  Future<List<OrderModel>> loadArchivedOrders(String hostUid,DateTime from,{DateTime? endAt}) async{
    var endDate = endAt != null ?DateTime(endAt.year,endAt.month,endAt.day): DateTime.now();
    var fromDateOnly = DateTime(from.year,from.month,from.day);
    logger.i("loadArchivedOrders from $fromDateOnly date to ${endDate} days.");

    var snapshotList = await orderCollection
        .doc(hostUid)
        .collection(ORDER_COLLECTION_NAME_ARCHIVED)
        .orderBy("createdAt")
        .startAfter([fromDateOnly])
        .endBefore([endDate])
        .get();
    logger.i("loadArchivedOrders with total:${snapshotList.size} data.");
    return snapshotList.docs.where((e) => e.exists).map((e) => OrderModel.fromJson(e.data())).toList();

  }
  // Future<List<OrderModel>> loadActivatedOrders(String hostUid) async {
  //   logger.i("loadActivatedOrders: hostUid:$hostUid");
  //   var snapshotList = await orderCollection.doc(hostUid).collection(ACTIVATED_COLLECTION_NAME).get();
  //   logger.i("loadActivatedOrders: hostUid:$hostUid total:${snapshotList.size} loaded.");
  //   return snapshotList.docs.where((e) => e.exists).map((e) => OrderModel.fromJson(e.data())).toList();
  // }
  /**
   * method will create new order
   */
  Future<void> add(OrderModel order){
    logger.i("create new order with guid:${order.guid}");
    return _remoteCreateActivatedOrder(order);
  }

  /// method will create a new document Firestore with '/Order/<CURRENT_LOGGED_IN_HOST_UID>/<PREPARING_COLLECTION_NAME>/<ORDER_GUID>'
  /// remove assignList and assigneeList from order
  Future<void> _remoteCreateActivatedOrder(OrderModel order) async {
    logger.i("_remoteCreateActivatedOrder create new order /$ORDER_COLLECTION_NAME/${order.hostUid}/${config.activatedSubCollectionName} with order:${order.guid}");
    var orderDocumentRef = orderCollection
        .doc(order.hostUid)
        .collection(config.activatedSubCollectionName)
        .doc(order.guid);
    var orderJsonData = order.toJson();
    await orderDocumentRef.set(orderJsonData, SetOptions(merge: true));
    return;

    // return orderCollection
    //     .doc(order.hostUid)
    //     .collection(PREPARING_COLLECTION_NAME)
    //     .doc(order.guid)
    //     .set(order.toJson());

  }





  Future<void> _remoteDelete(OrderModel order){
    logger.d("delete order:${order.guid} with ${order.status}");
    if (order.status == OrderStatusEnum.Creating || order.status == OrderStatusEnum.Assigning){
      logger.d("delete order from /order/${order.hostUid}/$ORDER_COLLECTION_NAME_PREPARING");
      return orderCollection
          .doc(order.hostUid)
          .collection(ORDER_COLLECTION_NAME_PREPARING)
          .doc(order.guid)
          .delete();
    }
    return orderCollection
        .doc(order.hostUid)
        .collection(ORDER_COLLECTION_NAME_PREPARING)
        .doc(order.guid)
        .set(order.toJson());
  }
  Future<void> deleteActivatedOrder(String hostUid,String orderGuid){
    logger.d("delete order from /${orderCollection.path}/$hostUid/${config.activatedSubCollectionName}/$orderGuid");
    return orderCollection
        .doc(hostUid)
        .collection(config.activatedSubCollectionName)
        .doc(orderGuid)
        .delete();
  }
  Future<void> update(String hostUid,String orderGuid,Map<String,dynamic> updateField,{bool isActivated = true}) async{
    logger.i("update order:$orderGuid with $updateField, isActivated:$isActivated");
    // await orderCollection
    //     .doc(hostUid)
    //     .collection(isActivated?ACTIVATED_ORDER_COLLECTION_NAME_ACTIVATED:ACTIVATED_ORDER_COLLECTION_NAME_ARCHIVED)
    //     .doc(orderGuid)
    //     .set(updateField,SetOptions(merge: true));


    // check updateField contains 'lastModifiedAt' is not add DateTime.now() with toISOString() to updateField
    if (updateField.containsKey("lastModifiedAt")){
      updateField["lastModifiedAt"] = DateTime.now().toIso8601String();
    }
    await orderCollection
        .doc(hostUid)
        .collection(isActivated?config.activatedSubCollectionName:config.archivedSubCollectionName)
        .doc(orderGuid)
        .update(updateField);
        // .set(updateField,SetOptions(merge: true));

  }
  Future<bool> updateByOrder(OrderModel order) async {
    // check order lastModifiedAt is not null
    // if it is null, then update it with DateTime.now().toIso8601String()
    order.lastModifiedAt ??= DateTime.now();
    var collectionName = _getCollectionNameByOrderState(order.status);
    if (collectionName == null){
      logger.w("update order:${order.guid} with ${order.status} but collection name is null.");
      return false;
    }
    if (order.status == OrderStatusEnum.Creating || order.status == OrderStatusEnum.Assigning){

      logger.d("update order:${order.guid} to /order/${order.hostUid}/$ORDER_COLLECTION_NAME_PREPARING");
      await orderCollection
          .doc(order.hostUid)
          .collection(collectionName)
          .doc(order.guid)
          .set(order.toJson(),SetOptions(merge: true));
      return true;
    }
    logger.i("update order:${order.guid} state from old:${order.previousStatus.name} to new:${order.status.name}.");
    if (order.isArchived && OrderModel.checkIsActivated(order.previousStatus)){
      logger.d("order:${order.guid} will be '${config.archivedSubCollectionName}'");
      logger.v("move order:${order.guid} from '${config.activatedSubCollectionName}' to '${config.archivedSubCollectionName}'.");
      await Future.wait([
        orderCollection
            .doc(order.hostUid)
            .collection(config.activatedSubCollectionName)
            .doc(order.guid)
            .delete(),
        orderCollection
            .doc(order.hostUid)
            .collection(config.archivedSubCollectionName)
            .doc(order.guid)
            .set(order.toJson())
      ]);
      logger.i("update: order:${order.guid} '${config.archivedSubCollectionName}'.");
      return true;
    }
    logger.d("update /order/${order.hostUid}/${config.activatedSubCollectionName}/${order.guid}");
    await FirebaseFirestore
        .instance
        .collection("Order")
        .doc(order.hostUid)
        .collection(config.activatedSubCollectionName)
        .doc(order.guid)
        .set(order.toJson(),SetOptions(merge: true));
    return true;
  }

  @deprecated
  Future<void> acceptAssign(String hostUid, String orderGuid, String assignGuid) async {

    var docMap = await FirebaseFirestore
        .instance
        .collection("Order")
        .doc(hostUid)
        .collection(ORDER_COLLECTION_NAME_PREPARING)
        .doc(orderGuid)
        .collection("assigns")
        .doc(assignGuid)
        // .where("guid",isEqualTo: assignGuid)
        .get();

    // if (docMap.docs.isNotEmpty && docMap.docs.first.exists){
    if (docMap.exists){
      print("-------- acceptAssign:${ docMap.data()}");
      // var assign = AssignModel.fromJson(docMap.data());
      // assign.state = AssignStateEnum.Accepted;
      // await FirebaseFirestore
      //     .instance
      //     .collection("Order")
      //     .doc(hostUid)
      //     .collection(PREPARING_COLLECTION_NAME)
      //     .doc(orderGuid)
      //     .collection("assignList")
      //     .doc(assignGuid)
      //     .set(assign.toJson());
    }else{
      print("-------- acceptAssign: not exist.");
    }

  }




}