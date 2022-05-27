// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_repository_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceRepositoryConfig _$ServiceRepositoryConfigFromJson(
        Map<String, dynamic> json) =>
    ServiceRepositoryConfig(
      collectionName: json['collectionName'] as String,
      masterUidFieldName: json['masterUidFieldName'] as String,
      orderGuidFieldName: json['orderGuidFieldName'] as String,
      assignGuidFieldName: json['assignGuidFieldName'] as String,
      serviceGuidFieldName: json['serviceGuidFieldName'] as String,
    );

Map<String, dynamic> _$ServiceRepositoryConfigToJson(
        ServiceRepositoryConfig instance) =>
    <String, dynamic>{
      'collectionName': instance.collectionName,
      'masterUidFieldName': instance.masterUidFieldName,
      'orderGuidFieldName': instance.orderGuidFieldName,
      'assignGuidFieldName': instance.assignGuidFieldName,
      'serviceGuidFieldName': instance.serviceGuidFieldName,
    };
