class OtpChallenge {
  const OtpChallenge({
    required this.success,
    required this.message,
    required this.identifier,
  });

  final bool success;
  final String message;
  final String identifier;
}
