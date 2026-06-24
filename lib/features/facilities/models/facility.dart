import 'package:dart_mappable/dart_mappable.dart';

part 'facility.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Facility with FacilityMappable {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String? location;
  final List<String>? images;
  final double pricePerHour;
  final bool isActive;

  const Facility({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.location,
    this.images,
    this.pricePerHour = 0,
    this.isActive = true,
  });

  static const fromMap = FacilityMapper.fromMap;
}
