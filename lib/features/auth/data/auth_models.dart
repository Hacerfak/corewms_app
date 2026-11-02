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
      id: json['id']?.toString() ?? '',
      corporateName:
          json['corporateName']?.toString() ?? json['name']?.toString() ?? '',
      tradeName: json['tradeName']?.toString(),
      cnpj: json['cnpj']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'corporateName': corporateName,
    'tradeName': tradeName,
    'cnpj': cnpj,
  };
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

  UserMeResponse copyWith({
    String? id,
    String? name,
    String? email,
    bool? isMaster,
    List<UserCompany>? companies,
    List<String>? permissions,
  }) {
    return UserMeResponse(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isMaster: isMaster ?? this.isMaster,
      companies: companies ?? this.companies,
      permissions: permissions ?? this.permissions,
    );
  }

  factory UserMeResponse.fromLoginData(
    Map<String, dynamic> json,
    List<String> perms,
  ) {
    final userData = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final rawCompanies = json['companies'] ?? userData['companies'] ?? [];
    final companiesList = <UserCompany>[];
    if (rawCompanies is List) {
      for (final item in rawCompanies) {
        if (item is Map) {
          companiesList.add(
            UserCompany.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final email =
        userData['email']?.toString() ?? json['email']?.toString() ?? '';
    final rawName =
        userData['name']?.toString() ??
        userData['userName']?.toString() ??
        userData['fullName']?.toString() ??
        json['name']?.toString() ??
        json['userName']?.toString() ??
        '';
    final displayName = rawName.trim().isNotEmpty
        ? rawName.trim()
        : (email.isNotEmpty ? email.split('@').first : 'Usuário');

    return UserMeResponse(
      id: userData['id']?.toString() ?? userData['userId']?.toString() ?? '',
      name: displayName,
      email: email,
      isMaster: userData['isMaster'] == true,
      companies: companiesList,
      permissions: perms,
    );
  }
}
