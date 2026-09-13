/// Représente un compte e-mail connecté :
/// - provider 'gmail' : connexion OAuth (accessToken/refreshToken utilisés)
/// - provider 'smtp' : connexion par mot de passe d'application
///   (Zoho, GMX, Yahoo... — smtpHost/smtpPort/smtpPassword utilisés)
class EmailAccount {
  final String email;
  final String provider;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiry;
  final String? smtpHost;
  final int? smtpPort;
  final String? smtpPassword;
  final String? displayName;
  final String? defaultSignatureId;

  EmailAccount({
    required this.email,
    required this.provider,
    this.accessToken = '',
    this.refreshToken = '',
    DateTime? accessTokenExpiry,
    this.smtpHost,
    this.smtpPort,
    this.smtpPassword,
    this.displayName,
    this.defaultSignatureId,
  }) : accessTokenExpiry = accessTokenExpiry ?? DateTime.now();

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiry.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'email': email,
        'provider': provider,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiry': accessTokenExpiry.toIso8601String(),
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
        'smtpPassword': smtpPassword,
        'displayName': displayName,
        'defaultSignatureId': defaultSignatureId,
      };

  factory EmailAccount.fromJson(Map<String, dynamic> json) => EmailAccount(
        email: json['email'] as String,
        provider: json['provider'] as String,
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        accessTokenExpiry: json['accessTokenExpiry'] != null
            ? DateTime.parse(json['accessTokenExpiry'] as String)
            : null,
        smtpHost: json['smtpHost'] as String?,
        smtpPort: json['smtpPort'] as int?,
        smtpPassword: json['smtpPassword'] as String?,
        displayName: json['displayName'] as String?,
        defaultSignatureId: json['defaultSignatureId'] as String?,
      );

  EmailAccount copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiry,
    String? defaultSignatureId,
    bool clearDefaultSignature = false,
  }) =>
      EmailAccount(
        email: email,
        provider: provider,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiry: accessTokenExpiry ?? this.accessTokenExpiry,
        smtpHost: smtpHost,
        smtpPort: smtpPort,
        smtpPassword: smtpPassword,
        displayName: displayName,
        defaultSignatureId: clearDefaultSignature ? null : (defaultSignatureId ?? this.defaultSignatureId),
      );
}
