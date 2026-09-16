import 'branch_profile.dart';

class TenantProfile {
  final String id;
  final String slug;
  final String name;
  final List<BranchProfile> branches;

  const TenantProfile({
    required this.id,
    required this.slug,
    required this.name,
    this.branches = const [],
  });

  factory TenantProfile.fromJson(Map<String, dynamic> json) {
    final List<BranchProfile> parsedBranches;
    final rawBranches = json['branches'];
    if (rawBranches is List) {
      parsedBranches = rawBranches
          .whereType<Map<String, dynamic>>()
          .map(BranchProfile.fromJson)
          .toList(growable: false);
    } else {
      parsedBranches = const [];
    }
    return TenantProfile(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      branches: parsedBranches,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'branches': branches.map((b) => b.toJson()).toList(growable: false),
      };
}

