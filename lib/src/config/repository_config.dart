
import 'package:json_annotation/json_annotation.dart';
import 'assign_repository_config.dart';
import 'service_repository_config.dart';
part 'repository_config.g.dart';

@JsonSerializable(
  explicitToJson: true,
)
class RepositoryConfig{
  int whereInLimit;
  ServiceRepositoryConfig serviceRepositoryConfig;
  AssignRepositoryConfig assignRepositoryConfig;
  RepositoryConfig({
    required this.whereInLimit,
    required this.serviceRepositoryConfig,
    required this.assignRepositoryConfig
});
  factory RepositoryConfig.fromJson(Map<String, dynamic> json) => _$RepositoryConfigFromJson(json);
  Map<String, dynamic> toJson() => _$RepositoryConfigToJson(this);
}