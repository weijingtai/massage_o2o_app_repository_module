

import 'package:json_annotation/json_annotation.dart';

part 'service_repository_config.g.dart';
@JsonSerializable()
class ServiceRepositoryConfig {
  String collectionName;
  String masterUidFieldName;
  String orderGuidFieldName;
  String assignGuidFieldName;
  String serviceGuidFieldName;
  ServiceRepositoryConfig({
    required this.collectionName,
    required this.masterUidFieldName,
    required this.orderGuidFieldName,
    required this.assignGuidFieldName,
    required this.serviceGuidFieldName
});
  factory ServiceRepositoryConfig.fromJson(Map<String, dynamic> json) => _$ServiceRepositoryConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceRepositoryConfigToJson(this);
}