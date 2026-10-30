class UserCompany {
  final String id;
  final String corporateName;
  final String? tradeName;
  final String cnpj;

  UserCompany({
    required this.id,
    required this.corporateName,
    this.tradeName,
    required this.cnpj,
  });

  factory UserCompany.fromJson(Map<String, dynamic> json) {
    return UserCompany(
      id: json['id'] ?? '',
      corporateName: json['corporateName'] ?? '',
      tradeName: json['tradeName'],
      cnpj: json['cnpj'] ?? '',
    );
  }
}

class UserMeResponse {
  final String id;
  final String name;
  final String email;
  final bool isMaster;
  final List<UserCompany> companies;
  final List<String> permissions;

  UserMeResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.isMaster,
    required this.companies,
    required this.permissions,
  });

  factory UserMeResponse.fromJson(Map<String, dynamic> json) {
    return UserMeResponse(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      isMaster: json['isMaster'] ?? false,
      companies: (json['companies'] as List<dynamic>? ?? [])
          .map((c) => UserCompany.fromJson(c))
          .toList(),
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((p) => p.toString())
          .toList(),
    );
  }
}
