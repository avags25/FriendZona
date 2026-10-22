class PublicUser {
  const PublicUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.friendCode,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String friendCode;
  final DateTime createdAt;

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    friendCode: json['friendCode'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'friendCode': friendCode,
    'createdAt': createdAt.toIso8601String(),
  };

  PublicUser withDisplayName(String value) => PublicUser(
    id: id,
    email: email,
    displayName: value,
    friendCode: friendCode,
    createdAt: createdAt,
  );
}

class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final PublicUser user;

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
    accessToken: json['accessToken'] as String,
    tokenType: json['tokenType'] as String,
    expiresIn: (json['expiresIn'] as num).toInt(),
    refreshToken: json['refreshToken'] as String,
    refreshExpiresAt: DateTime.parse(json['refreshExpiresAt'] as String),
    user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'displayName': displayName,
  };
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RefreshRequest {
  const RefreshRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class ProfilePatchRequest {
  const ProfilePatchRequest({required this.displayName});

  final String displayName;

  Map<String, dynamic> toJson() => {'displayName': displayName};
}
