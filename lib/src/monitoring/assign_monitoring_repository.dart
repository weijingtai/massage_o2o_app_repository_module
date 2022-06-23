
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:meta/meta.dart';
import 'package:quiver/iterables.dart';
import 'package:tuple/tuple.dart';

import '../config/assign_repository_config.dart';
import '../config/repository_config.dart';
import '../const_names.dart';
import '../converters/assign_model_converter.dart';
import '../enums/assign_model_change_type_enum.dart';

class AssignMonitoringRepository {
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
  CollectionReference<AssignModel?> get assignCollection => _assignCollection.withConverter<AssignModel?>(
    fromFirestore: AssignModelFromFirestoreFunction,
    toFirestore:  AssignModelToFirestoreFunction,
  );

  /// key is assign's guid
  @visibleForTesting
  final Map<String,AssignModel> monitoringAssignMap = {};

  /// key is orderGuid
  /// value is total assign count in monitoring
  @visibleForTesting
  final Map<String,int> monitoringOrderGuidMap = {};

  /// key is orderGuid
  /// value is listener
  final Map<String,StreamSubscription<QuerySnapshot<AssignModel?>>> assignListener = {};

  @visibleForTesting
  final StreamController<Tuple2<AssignModelChangeType,AssignModel>> assignStreamController = StreamController<Tuple2<AssignModelChangeType,AssignModel>>.broadcast();
  StreamSink<Tuple2<AssignModelChangeType,AssignModel>> get _sink=> assignStreamController.sink;
  Stream<Tuple2<AssignModelChangeType,AssignModel>> get assignStream => assignStreamController.stream;

  final StreamController<Tuple2<AssignModelChangeType,AssignModel>> singleAssignStreamController = StreamController<Tuple2<AssignModelChangeType,AssignModel>>.broadcast();
  StreamSink<Tuple2<AssignModelChangeType,AssignModel>> get _singleSink=> singleAssignStreamController.sink;
  Stream<Tuple2<AssignModelChangeType,AssignModel>> get singleAssignStream => singleAssignStreamController.stream;
  final Map<String,StreamSubscription<DocumentSnapshot<AssignModel?>>> assignDocListener = {};
  Map<String,AssignModel> singleAssignMap = {};

  @deprecated
  Map<String,Timer> assignTimeoutTimerMap = {};
  StreamSubscription<QuerySnapshot<AssignModel?>>? masterUidListener;

  AssignMonitoringRepository({
    required this.firestore,
    required this.repositoryConfig}):_assignCollection = firestore.collection(repositoryConfig.assignRepositoryConfig.collectionName);

  void _handleAssignAdded(AssignModel addedAssign,{DateTime? ignoreBeforeCreatedAtWhenAdded}){
    logger.v(addedAssign.toJson());
    var orderGuid = addedAssign.orderGuid;
    // add assignModel to monitoringAssignMap
    monitoringAssignMap[addedAssign.guid] = addedAssign;
    // add monitoringOrderGuidMap
    if (monitoringOrderGuidMap.containsKey(orderGuid)) {
      monitoringOrderGuidMap[orderGuid] = monitoringOrderGuidMap[orderGuid]! + 1;
    }
    else{
      monitoringOrderGuidMap[orderGuid] = 1;
    }
    logger.d("current total:${monitoringAssignMap.length} in monitoring, total:${monitoringOrderGuidMap[orderGuid]} in monitoringOrderGuidMap for orderGuid:$orderGuid");
    // check if assignModel.createdAt is before ignoreBeforeCreatedAtWhenAdded
    if (ignoreBeforeCreatedAtWhenAdded != null &&
        addedAssign.createdAt.isBefore(ignoreBeforeCreatedAtWhenAdded)){
      logger.d("ignore assignModel: ${addedAssign.guid} because it is created before: $ignoreBeforeCreatedAtWhenAdded");
    }else{
      logger.d("monitoringActivatedAssignByOrderGuid: DocumentChangeType.added assignGuid:${addedAssign.guid}");
      _sink.add(Tuple2(AssignModelChangeType.Added,addedAssign));
    }
  }
  void _handleAssignChanged(AssignModel changedAssign){
    logger.v(changedAssign.toJson());
    monitoringAssignMap[changedAssign.guid] = changedAssign;
    _sink.add(Tuple2(AssignModelChangeType.Updated,changedAssign));
  }
  void _handleAssignRemoved(AssignModel changedAssign){
    var orderGuid = changedAssign.orderGuid;
    if (monitoringOrderGuidMap.containsKey(orderGuid)) {
      monitoringOrderGuidMap[orderGuid] = monitoringOrderGuidMap[orderGuid]! - 1;
    }
    if (monitoringOrderGuidMap[orderGuid] == 0){
      logger.v("remove orderGuid:$orderGuid from monitoringOrderGuidMap");
      monitoringOrderGuidMap.remove(orderGuid);
    }
    monitoringAssignMap.remove(changedAssign.guid);
    _sink.add(Tuple2(AssignModelChangeType.Deleted,changedAssign));
  }

  @deprecated
  void removeAssignTimeout(AssignModel assignModel){
    logger.d("remove assignTimeout for assignModel: ${assignModel.guid}");
    var timer = assignTimeoutTimerMap[assignModel.guid];
    if (timer != null){
      timer.cancel();
      assignTimeoutTimerMap.remove(assignModel.guid);
    }
  }
  @deprecated
  void addAssignTimeout(AssignModel assignModel){
    if (!assignTimeoutTimerMap.containsKey(assignModel.guid)){
      if (assignModel.timeoutAt != null){
        logger.d("add assignTimeout for assignModel: ${assignModel.guid}");
        assignTimeoutTimerMap[assignModel.guid] = Timer(Duration(milliseconds: DateTime.now().difference(assignModel.timeoutAt!).inMilliseconds),(){
          logger.d("assign is timeout with guid: ${assignModel.guid}");
          assignTimeoutTimerMap.remove(assignModel.guid);
          _handleAssignRemoved(assignModel);
        });
      }
    }
  }
  @visibleForTesting
  void listenAssignModel(QuerySnapshot<Object?> event,{DateTime? ignoreBeforeCreatedAtWhenAdded}){
    for (var docChanges in event.docChanges) {
      // handle docChanges.type with switch case
      AssignModel? assignModel = docChanges.doc.data() as AssignModel?;
      if (docChanges.doc.exists && assignModel != null) {
        switch(docChanges.type){
          case DocumentChangeType.added:
            // if ([AssignStateEnum.Assigning,AssignStateEnum.Delivering].contains(assignModel.state)){
              // _handleAssignAdded(assignModel,ignoreBeforeCreatedAtWhenAdded: ignoreBeforeCreatedAtWhenAdded);
              // addAssignTimeout(assignModel);
            // }
            logger.d('handleAssignAdded: ${assignModel.guid} with ignoreBeforeCreatedAtWhenAdded:${ignoreBeforeCreatedAtWhenAdded?.toIso8601String() ?? "null"}');
            _handleAssignAdded(assignModel,ignoreBeforeCreatedAtWhenAdded: ignoreBeforeCreatedAtWhenAdded);
            break;
          case DocumentChangeType.modified:
            logger.d("monitoringActivatedAssignByOrderGuid: DocumentChangeType.modified assignGuid:${assignModel.guid}");
            // if ([AssignStateEnum.Assigning,AssignStateEnum.Delivering].contains(assignModel.state)){
            //   addAssignTimeout(assignModel);
            // }else{
            //   removeAssignTimeout(assignModel);
            // }
            _handleAssignChanged(assignModel);
            break;
          case DocumentChangeType.removed:
            // removeAssignTimeout(assignModel);
            logger.d("monitoringActivatedAssignByOrderGuid: DocumentChangeType.removed assignGuid:${assignModel.guid}");
            _handleAssignRemoved(assignModel);
            break;
        }
      }
      else{
        logger.e("monitoringActivatedAssignByOrderGuid: AssignModel is null");
      }
    }
  }
  ///
  /// monitoring assignModel with order's guid which is the same as order's guid in orderModel:
  monitorActivatedByOrderGuid(String orderGuid,{DateTime? ignoreBeforeCreatedAtWhenAdded}){
    if (assignListener.containsKey(orderGuid)){
      logger.i("monitoringActivatedByOrderGuid is already monitoring, $orderGuid");
      return;
    }
    assignListener[orderGuid] = assignCollection
        .where(config.orderGuidFieldName,isEqualTo: orderGuid)
        .snapshots()
        .listen((event)=>listenAssignModel(event,ignoreBeforeCreatedAtWhenAdded: ignoreBeforeCreatedAtWhenAdded),
        onError: (error)=>logger.e("monitoringActivatedByOrderGuid: $error"));
  }
  cancelMonitoringActivatedByOrderGuid(String orderGuid){
    if (assignListener.containsKey(orderGuid)){
      logger.i("cancel monitoringActivatedByOrderGuid, $orderGuid");
      assignListener[orderGuid]!.cancel();
      assignListener.remove(orderGuid);
      monitoringOrderGuidMap.remove(orderGuid);
    }
  }

  ///
  /// [return] serviceGuid List which is already monitoring
  List<String> monitorActivatedByOrderGuidList(List<String> orderGuids,{DateTime? ignoreBeforeCreatedAtWhenAdded}){
    // check orderGuids is not empty
    if (orderGuids.isEmpty){
      logger.w("monitoringActivatedByOrderGuidList: orderGuids is empty");
      return [];
    }
    List<String> inMonitoringOrderGuidList = [];
    orderGuids.forEach((guid) {
      if (assignListener.containsKey(guid)){
        logger.d("monitoringActivatedByOrderGuidList: $guid is already monitoring");
        inMonitoringOrderGuidList.add(guid);
      }else{
        logger.d("monitoringActivatedByOrderGuidList: $guid is not monitoring");
        monitorActivatedByOrderGuid(guid,ignoreBeforeCreatedAtWhenAdded: ignoreBeforeCreatedAtWhenAdded);
      }
    });

    if (inMonitoringOrderGuidList.isNotEmpty){
      logger.i("monitoringActivatedByOrderGuidList: total:${inMonitoringOrderGuidList.length} in monitoring, and skip duplicate monitoring.");
      logger.v(inMonitoringOrderGuidList);
    }
    return inMonitoringOrderGuidList;
  }

  cancelMonitoringActivatedByOrderGuidList(List<String> orderGuids){
    if (orderGuids.isEmpty){
      logger.w("cancelMonitoringActivatedByOrderGuidList: orderGuids is empty");
      return;
    }
    orderGuids.forEach((guid) {
      if (assignListener.containsKey(guid)){
        logger.d("cancelMonitoringActivatedByOrderGuidList: $guid is monitoring");
        cancelMonitoringActivatedByOrderGuid(guid);
      }else{
        logger.d("cancelMonitoringActivatedByOrderGuidList: $guid is not monitoring");
      }
    });
  }
  monitorAssign(String assignGuid){
    if (singleAssignMap.containsKey(assignGuid)){
      logger.i("monitorAssign is already monitoring, $assignGuid");
      return;
    }
    assignCollection
        .doc(assignGuid)
        .snapshots()
        .listen((event){
          if (event.exists) {
            logger.d("monitorAssign assignGuid: $assignGuid");
            AssignModel assignModel = (event.data() as AssignModel);
            logger.v(assignModel.toJson());
            singleAssignMap[assignModel.guid] = assignModel;
            if (singleAssignMap.containsKey(assignModel.guid)){
              logger.d("monitorAssign: ${assignModel.guid} is updated.");
              _singleSink.add(Tuple2(AssignModelChangeType.Updated,assignModel));
            }else{
              logger.d("monitorAssign: ${assignModel.guid} is added.");
              _singleSink.add(Tuple2(AssignModelChangeType.Added,assignModel));
            }
          }else{
            logger.w("monitorAssign assignGuid: $assignGuid is null.");
          }
    },
        onError: (error)=>logger.e("monitorAssign: $error"));
  }
  ///
  /// Warning: this listen will not trigger DocumentChangeType.removed event
  ///
  /// monitoring assignModel with order's guid which is the same as order's guid in orderModel
  /// and assignModel's status is "Assigning" or "Delivering"
  monitorAssigningByMasterUid(String masterUid){
    if (masterUidListener != null){
      logger.i("monitoringAssigningByMasterUid is already monitoring");
      return;
    }
    masterUidListener = assignCollection
        .where(config.masterUidFieldName,isEqualTo: masterUid)
        .where(config.assignStateFieldName,whereIn: [AssignStateEnum.Assigning.name,AssignStateEnum.Delivering.name])
        .orderBy(config.timeoutAtFieldName)
        .where(config.timeoutAtFieldName,isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
        .snapshots()
        .listen((event)=>listenAssignModel(event));
    logger.i("monitoringAssigningByMasterUid is monitoring successfully.");
  }
  cancelMonitoringAssigningByMasterUid(){
    if (masterUidListener != null){
      logger.i("cancel monitoringAssigningByMasterUid");
      masterUidListener!.cancel();
      masterUidListener = null;
    }
  }
}