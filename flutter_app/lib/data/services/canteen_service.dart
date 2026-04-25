import '../models/canteen.dart';
import '../models/menu_item.dart';
import 'api_client.dart';

class CanteenService {
  CanteenService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Canteen>> fetchPublicCanteens() async {
    final response = await _apiClient.request(
      'api/public/canteens',
      method: 'GET',
      authenticated: false,
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Failed to load canteens').toString());
    }

    final data = _asMap(body['data']);
    final rows = (data['canteens'] is List) ? (data['canteens'] as List) : const [];

    return rows
        .whereType<Map>()
        .map((e) => Canteen.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<MenuItem>> fetchMenuItems(int canteenId) async {
    try {
      final response = await _apiClient.request(
        'api/canteen/menu-items',
        method: 'GET',
        queryParameters: <String, dynamic>{
          'canteenId': canteenId,
        },
        authenticated: true,
      );

      final body = _asMap(response.data);
      if (body['success'] != true) {
        throw Exception((body['message'] ?? 'Failed to load menu items').toString());
      }

      final data = _asMap(body['data']);
      final rows = (data['items'] is List) ? (data['items'] as List) : const [];

      return rows
          .whereType<Map>()
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e), canteenId: canteenId))
          .toList(growable: false);
    } catch (_) {
      return _sampleMenu(canteenId);
    }
  }
}

List<MenuItem> _sampleMenu(int canteenId) {
  final base = <MenuItem>[
    MenuItem(
      id: 1,
      name: 'Masala Tea',
      description: 'Hot and spicy masala tea',
      price: 15,
      category: 'beverages',
      imageUrl: '',
      isAvailable: true,
      isVegetarian: true,
      canteenId: canteenId,
    ),
    MenuItem(
      id: 2,
      name: 'Veg Sandwich',
      description: 'Fresh vegetable sandwich with cheese',
      price: 40,
      category: 'snacks',
      imageUrl: '',
      isAvailable: true,
      isVegetarian: true,
      canteenId: canteenId,
    ),
    MenuItem(
      id: 3,
      name: 'Samosa',
      description: 'Crispy and spicy potato samosa',
      price: 20,
      category: 'snacks',
      imageUrl: '',
      isAvailable: true,
      isVegetarian: true,
      canteenId: canteenId,
    ),
    MenuItem(
      id: 4,
      name: 'Cheese Pizza',
      description: 'Delicious cheese pizza slice',
      price: 80,
      category: 'meals',
      imageUrl: '',
      isAvailable: true,
      isVegetarian: true,
      canteenId: canteenId,
    ),
    MenuItem(
      id: 5,
      name: 'Ice Cream',
      description: 'Vanilla and chocolate ice cream scoop',
      price: 30,
      category: 'desserts',
      imageUrl: '',
      isAvailable: true,
      isVegetarian: true,
      canteenId: canteenId,
    ),
  ];

  return base;
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return <String, dynamic>{};
}
