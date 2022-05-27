// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assign_repository_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssignRepositoryConfig _$AssignRepositoryConfigFromJson(
        Map<String, dynamic> json) =>
    AssignRepositoryConfig(
      collectionName: json['collectionName'] as String,
      hostUidFieldName: json['hostUidFieldName'] as String,
      masterUidFieldName: json['masterUidFieldName'] as String,
      orderGuidFieldName: json['orderGuidFieldName'] as String,
      assignGuidFieldName: json['assignGuidFieldName'] as String,
      serviceGuidFieldName: json['serviceGuidFieldName'] as String,
      createdAtFieldName: json['createdAtFieldName'] as String,
      assignAtFieldName: json['assignAtFieldName'] as String,
      timeoutAtFieldName: json['timeoutAtFieldName'] as String,
      assignStateFieldName: json['assignStateFieldName'] as String,
    );

Map<String, dynamic> _$AssignRepositoryConfigToJson(
        AssignRepositoryConfig instance) =>
    <String, dynamic>{
      'collectionName': instance.collectionName,
      'masterUidFieldName': instance.masterUidFieldName,
      'orderGuidFieldName': instance.orderGuidFieldName,
      'hostUidFieldName': instance.hostUidFieldName,
      'assignGuidFieldName': instance.assignGuidFieldName,
      'serviceGuidFieldName': instance.serviceGuidFieldName,
      'createdAtFieldName': instance.createdAtFieldName,
      'timeoutAtFieldName': instance.timeoutAtFieldName,
      'assignAtFieldName': instance.assignAtFieldName,
      'assignStateFieldName': instance.assignStateFieldName,
    };
