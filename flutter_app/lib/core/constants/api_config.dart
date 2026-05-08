class ApiConfig {
  static const int backendPort = 5266;
  static const String primaryBaseUrl = 'https://campuseatzz.onrender.com';

  static List<String> allBaseUrls([String? overrideBase]) {
    final urls = <String>[];

    void push(String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) return;
      final normalized = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
      if (!_isSupportedBackendUrl(normalized)) return;
      if (!urls.contains(normalized)) urls.add(normalized);
    }

    push(primaryBaseUrl);

    // If the user has saved a custom base URL that differs from primary, add it
    // as a fallback (covers dev override set via settings).
    if (overrideBase != null) {
      final norm = overrideBase.trim().endsWith('/')
          ? overrideBase.trim().substring(0, overrideBase.trim().length - 1)
          : overrideBase.trim();
      // Only add local/dev overrides as fallback, not a duplicate of primary.
      if (norm != primaryBaseUrl && _isSupportedBackendUrl(norm)) {
        push(norm);
      }
    }

    return urls;
  }

  static bool _isSupportedBackendUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    // Allow standard ports (0 = default for scheme, 80, 443) or the local dev port
    final port = uri.port;
    if (port == 0 || port == 80 || port == 443 || port == backendPort) {
      return true;
    }

    return false;
  }
}
