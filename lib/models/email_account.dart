/// Représente un compte e-mail connecté (Gmail pour l'instant,
/// Outlook viendra plus tard avec la même structure).
class EmailAccount {
  final String email;
  final String provider; // 'gmail' pour l'instant
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiry;

  EmailAccount({
    required this.email,
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
  });

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiry.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'email': email,
        'provider': provider,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiry': accessTokenExpiry.toIso8601String(),
      };

  factory EmailAccount.fromJson(Map<String, dynamic> json) => EmailAccount(
        email: json['email'] as String,
        provider: json['provider'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiry: DateTime.parse(json['accessTokenExpiry'] as String),
      );

  EmailAccount copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiry,
  }) =>
      EmailAccount(
        email: email,
        provider: provider,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiry: accessTokenExpiry ?? this.accessTokenExpiry,
      );
}
