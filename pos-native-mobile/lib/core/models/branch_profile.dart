class BranchProfile {
  final String id;
  final String name;
  final String? qrisImageUrl;

  const BranchProfile({
    required this.id,
    required this.name,
    this.qrisImageUrl,
  });

  factory BranchProfile.fromJson(Map<String, dynamic> json) => BranchProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        qrisImageUrl: json['qrisImageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'qrisImageUrl': qrisImageUrl,
      };
}
