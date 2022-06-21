

import 'package:json_annotation/json_annotation.dart';

part 'activated_order_repository_config.g.dart';
@JsonSerializable()
class ActivatedOrderRepositoryConfig {
  String collectionName;
  String activatedSubCollectionName;
  String archivedSubCollectionName;
  String orderGuidFieldName;
  ActivatedOrderRepositoryConfig({
    required this.collectionName,
    required this.activatedSubCollectionName,
    required this.archivedSubCollectionName,
    required this.orderGuidFieldName,
});
  factory ActivatedOrderRepositoryConfig.fromJson(Map<String, dynamic> json) => _$ActivatedOrderRepositoryConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ActivatedOrderRepositoryConfigToJson(this);
}