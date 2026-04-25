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
    final response = await _apiClient.request(
      'api/public/canteens/$canteenId/menu',
      method: 'GET',
      authenticated: false,
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
  }
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
