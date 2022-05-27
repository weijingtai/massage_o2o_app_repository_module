// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepositoryConfig _$RepositoryConfigFromJson(Map<String, dynamic> json) =>
    RepositoryConfig(
      whereInLimit: json['whereInLimit'] as int,
      serviceRepositoryConfig: ServiceRepositoryConfig.fromJson(
          json['serviceRepositoryConfig'] as Map<String, dynamic>),
      assignRepositoryConfig: AssignRepositoryConfig.fromJson(
          json['assignRepositoryConfig'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RepositoryConfigToJson(RepositoryConfig instance) =>
    <String, dynamic>{
      'whereInLimit': instance.whereInLimit,
      'serviceRepositoryConfig': instance.serviceRepositoryConfig.toJson(),
      'assignRepositoryConfig': instance.assignRepositoryConfig.toJson(),
    };
