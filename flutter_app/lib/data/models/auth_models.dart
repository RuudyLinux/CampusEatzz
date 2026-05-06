class OtpChallenge {
  const OtpChallenge({
    required this.success,
    required this.message,
    required this.identifier,
    required this.deliveryEmail,
  });

  final bool success;
  final String message;
  final String identifier;
  final String deliveryEmail;
}
