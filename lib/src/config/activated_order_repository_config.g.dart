// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activated_order_repository_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivatedOrderRepositoryConfig _$ActivatedOrderRepositoryConfigFromJson(
        Map<String, dynamic> json) =>
    ActivatedOrderRepositoryConfig(
      collectionName: json['collectionName'] as String,
      activatedSubCollectionName: json['activatedSubCollectionName'] as String,
      archivedSubCollectionName: json['archivedSubCollectionName'] as String,
      orderGuidFieldName: json['orderGuidFieldName'] as String,
    );

Map<String, dynamic> _$ActivatedOrderRepositoryConfigToJson(
        ActivatedOrderRepositoryConfig instance) =>
    <String, dynamic>{
      'collectionName': instance.collectionName,
      'activatedSubCollectionName': instance.activatedSubCollectionName,
      'archivedSubCollectionName': instance.archivedSubCollectionName,
      'orderGuidFieldName': instance.orderGuidFieldName,
    };
