class OtpChallenge {
  const OtpChallenge({
    required this.success,
    required this.message,
    required this.identifier,
    this.developmentOtp,
  });

  final bool success;
  final String message;
  final String identifier;
  final String? developmentOtp;
}
