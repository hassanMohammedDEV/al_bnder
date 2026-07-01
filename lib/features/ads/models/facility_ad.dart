import 'package:dart_mappable/dart_mappable.dart';

part 'facility_ad.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class FacilityAd with FacilityAdMappable {
  final String id;
  final String facilityGroupId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? linkUrl;
  final bool isActive;
  final String? startsAt;
  final String? endsAt;
  final String createdAt;
  final String updatedAt;
  final int sortOrder;

  const FacilityAd({
    required this.id,
    required this.facilityGroupId,
    required this.title,
    this.description,
    this.imageUrl,
    this.linkUrl,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  static const fromMap = FacilityAdMapper.fromMap;
}
