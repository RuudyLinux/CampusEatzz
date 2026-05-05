import 'api_config.dart';

class FoodImageResolver {
  static const String defaultFoodAsset = 'assets/images/Restaurants.jpg';

  static const String _menuItemUploadsRoot = '/uploads/menu_items/';

  static const Map<String, String> _exactNameToUploadFileName =
      <String, String>{
    'caesar salad': 'Caesar_Salad.jpg',
    'continental breakfast': 'Continental_Breakfast.jpg',
    'fish chips': 'Fish_&_Chips.jpg',
    'fish and chips': 'Fish_&_Chips.jpg',
    'gulab jamun': 'Gulab_Jamun.jpg',
    'iced latte': 'Iced_Latte.jpg',
    'margherita pizza': 'Margherita_Pizza.jpg',
    'mushroom stroganoff': 'Mushroom_Stroganoff.jpg',
    'nachos supreme': 'Nachos_Supreme.jpg',
    'new york cheesecake': 'New_York_Cheesecake.jpg',
    'pancakes stack': 'Pancakes_Stack.jpg',
    'paneer tikka masala': 'Paneer_Tikka_Masala.jpg',
    'pasta alfredo': 'Pasta_Alfredo.jpg',
    'penne arrabiata': 'Penne_Arrabiata.jpg',
    'pepperoni pizza': 'Pepperoni_Pizza.jpg',
    'scrambled eggs': 'Scrambled_Eggs.jpg',
    'spring rolls': 'Spring_Rolls.jpg',
    'tropical smoothie': 'Tropical_Smoothie.jpg',
    'vegetable biryani': 'Vegetable_Biryani.jpg',
    'virgin mojito': 'Virgin_Mojito.jpg',
  };

  static const Map<String, String> _exactNameToAsset = <String, String>{
    'caesar salad': 'assets/images/Caesar_Salad.jpg',
    'continental breakfast': 'assets/images/Continental _Breakfast.jpg',
    'fish chips': 'assets/images/Fish_&_Chips.jpg',
    'fish and chips': 'assets/images/Fish_&_Chips.jpg',
    'gulab jamun': 'assets/images/Gulab_Jamun.jpg',
    'iced latte': 'assets/images/Iced_Latte.jpg',
    'margherita pizza': 'assets/images/Margherita_Pizza.jpg',
    'mushroom stroganoff': 'assets/images/Mushroom_Stroganoff.jpg',
    'nachos supreme': 'assets/images/Nachos_Supreme.jpg',
    'new york cheesecake': 'assets/images/New_York_Cheesecake.jpg',
    'pancakes stack': 'assets/images/Pancakes_Stack.jpg',
    'paneer tikka masala': 'assets/images/Paneer_Tikka_Masala.jpg',
    'pasta alfredo': 'assets/images/Pasta_Alfredo.jpg',
    'penne arrabiata': 'assets/images/Penne_Arrabiata.jpg',
    'pepperoni pizza': 'assets/images/Pepperoni_Pizza.jpg',
    'scrambled eggs': 'assets/images/Scrambled_Eggs.jpg',
    'spring rolls': 'assets/images/Spring_Rolls.jpg',
    'tropical smoothie': 'assets/images/Tropical_Smoothie.jpg',
    'vegetable biryani': 'assets/images/Vegetable_Biryani.jpg',
    'virgin mojito': 'assets/images/Virgin_Mojito.jpg',
  };

  static const Map<String, String> _keywordToAsset = <String, String>{
    'salad': 'assets/images/Caesar_Salad.jpg',
    'breakfast': 'assets/images/Continental _Breakfast.jpg',
    'fish': 'assets/images/Fish_&_Chips.jpg',
    'chips': 'assets/images/Fish_&_Chips.jpg',
    'jamun': 'assets/images/Gulab_Jamun.jpg',
    'latte': 'assets/images/Iced_Latte.jpg',
    'pizza': 'assets/images/Margherita_Pizza.jpg',
    'stroganoff': 'assets/images/Mushroom_Stroganoff.jpg',
    'nachos': 'assets/images/Nachos_Supreme.jpg',
    'cheesecake': 'assets/images/New_York_Cheesecake.jpg',
    'pancake': 'assets/images/Pancakes_Stack.jpg',
    'paneer': 'assets/images/Paneer_Tikka_Masala.jpg',
    'alfredo': 'assets/images/Pasta_Alfredo.jpg',
    'arrabiata': 'assets/images/Penne_Arrabiata.jpg',
    'egg': 'assets/images/Scrambled_Eggs.jpg',
    'roll': 'assets/images/Spring_Rolls.jpg',
    'smoothie': 'assets/images/Tropical_Smoothie.jpg',
    'biryani': 'assets/images/Vegetable_Biryani.jpg',
    'mojito': 'assets/images/Virgin_Mojito.jpg',
    'tea': 'assets/images/chirag_tea_center.jpg',
    'coffee': 'assets/images/chirag_tea_center.jpg',
  };

  static String normalizeImageUrl(String rawUrl) {
    var value = rawUrl.trim();
    if (value.isEmpty) {
      return '';
    }

    value = value.replaceAll('\\', '/');

    if (value.startsWith('data:')) {
      return value;
    }

    final extractedUploadsPath = _extractUploadsPath(value);
    if (extractedUploadsPath != null) {
      return Uri.encodeFull('${ApiConfig.primaryBaseUrl}$extractedUploadsPath');
    }

    if (_isHttpUrl(value)) {
      final uri = Uri.tryParse(value);
      if (uri == null) {
        return Uri.encodeFull(value);
      }

      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
        final path = uri.path.isEmpty ? '/' : uri.path;
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return Uri.encodeFull('${ApiConfig.primaryBaseUrl}$path$query');
      }

      return Uri.encodeFull(value);
    }

    if (_looksLikeWindowsAbsolutePath(value)) {
      return '';
    }

    if (!value.startsWith('/')) {
      value = '/$value';
    }

    return Uri.encodeFull('${ApiConfig.primaryBaseUrl}$value');
  }

  static String? uploadPathForFoodName(String foodName) {
    final normalized = _normalize(foodName);
    if (normalized.isEmpty) {
      return null;
    }

    final fileName = _exactNameToUploadFileName[normalized];
    if (fileName == null) {
      return null;
    }

    return '$_menuItemUploadsRoot$fileName';
  }

  static String? uploadUrlForFoodName(String foodName) {
    final path = uploadPathForFoodName(foodName);
    if (path == null) {
      return null;
    }
    return Uri.encodeFull('${ApiConfig.primaryBaseUrl}$path');
  }

  static String? assetForFoodName(String foodName) {
    final normalized = _normalize(foodName);
    if (normalized.isEmpty) {
      return null;
    }

    final exact = _exactNameToAsset[normalized];
    if (exact != null) {
      return exact;
    }

    for (final entry in _keywordToAsset.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  static String fallbackAssetForFood(String foodName) {
    return assetForFoodName(foodName) ?? defaultFoodAsset;
  }

  static bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String? _extractUploadsPath(String value) {
    final lower = value.toLowerCase();
    const marker = '/uploads/';

    final markerIndex = lower.indexOf(marker);
    if (markerIndex >= 0) {
      return value.substring(markerIndex);
    }

    if (lower.startsWith('uploads/')) {
      return '/$value';
    }

    return null;
  }

  static bool _looksLikeWindowsAbsolutePath(String value) {
    return RegExp(r'^[a-zA-Z]:/').hasMatch(value);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
