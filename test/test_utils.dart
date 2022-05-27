
import 'dart:convert';

import 'dart:io';

import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';

import 'package:massage_o2o_app_repository_module/src/config/repository_config.dart';
import 'package:uuid/uuid.dart';

Future<RepositoryConfig> loadRepositoryConfig() async {
  final Map<String,dynamic> jsonMap = await json.decode(await File('test_resources${Platform.pathSeparator}config.json').readAsString());
  final repositoryConfig = RepositoryConfig.fromJson(jsonMap);
  return repositoryConfig;
}

AssignModel generateAssignModel() {
  var assignGuid = Uuid().v4();
  var masterUid = Uuid().v4();
  var orderGuid = Uuid().v4();
  var serviceGuid = Uuid().v4();
  var hostUid = Uuid().v4();
  var newAssignModel = AssignModel(assignGuid,
      masterUid: masterUid,
      serviceGuid: serviceGuid,
      orderGuid: orderGuid,
      hostUid: hostUid,
      assignTimeoutSeconds: 90,
      deliverTimeoutSeconds: 30,
      currentOrderStatus: OrderStatusEnum.Creating,
      senderUid: assignGuid,
      createdAt: DateTime.now());
  return newAssignModel;
}