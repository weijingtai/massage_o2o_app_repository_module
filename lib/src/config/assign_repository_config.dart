

import 'package:json_annotation/json_annotation.dart';

part 'assign_repository_config.g.dart';
@JsonSerializable()
class AssignRepositoryConfig {
  String collectionName;
  String masterUidFieldName;
  String orderGuidFieldName;
  String hostUidFieldName;
  String assignGuidFieldName;
  String serviceGuidFieldName;
  String createdAtFieldName;
  String timeoutAtFieldName;
  String assignAtFieldName;
  String assignStateFieldName;
  AssignRepositoryConfig({
    required this.collectionName,
    required this.hostUidFieldName,
    required this.masterUidFieldName,
    required this.orderGuidFieldName,
    required this.assignGuidFieldName,
    required this.serviceGuidFieldName,
    required this.createdAtFieldName,
    required this.assignAtFieldName,
    required this.timeoutAtFieldName,
    required this.assignStateFieldName,
});
  factory AssignRepositoryConfig.fromJson(Map<String, dynamic> json) => _$AssignRepositoryConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AssignRepositoryConfigToJson(this);
}