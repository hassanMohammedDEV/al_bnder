import 'package:dart_mappable/dart_mappable.dart';

part 'facility_group.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class FacilityGroup with FacilityGroupMappable {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final bool isActive;

  const FacilityGroup({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.isActive = true,
  });

  static const fromMap = FacilityGroupMapper.fromMap;
}
