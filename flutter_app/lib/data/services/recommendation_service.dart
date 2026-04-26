import '../models/recommendation_item.dart';
import 'api_client.dart';

class RecommendationService {
  RecommendationService(this._apiClient);

  final ApiClient _apiClient;

  Future<RecommendationSection> fetchTrending({int limit = 6}) async {
    final response = await _apiClient.request(
      'api/recommendations/trending',
      method: 'GET',
      authenticated: false,
      queryParameters: <String, dynamic>{'limit': limit},
    );
    return RecommendationSection.fromJson(_asMap(response.data));
  }

  Future<RecommendationSection> fetchBudgetMeals({
    double maxPrice = 150,
    int limit = 6,
  }) async {
    final response = await _apiClient.request(
      'api/recommendations/budget',
      method: 'GET',
      authenticated: false,
      queryParameters: <String, dynamic>{
        'maxPrice': maxPrice,
        'limit': limit,
      },
    );
    return RecommendationSection.fromJson(_asMap(response.data));
  }

  Future<RecommendationSection> fetchPersonal({
    int userId = 0,
    int limit = 6,
  }) async {
    final response = await _apiClient.request(
      'api/recommendations/personal',
      method: 'GET',
      authenticated: false,
      queryParameters: <String, dynamic>{
        if (userId > 0) 'userId': userId,
        'limit': limit,
      },
    );
    return RecommendationSection.fromJson(_asMap(response.data));
  }

  Future<RecommendationSection> fetchByCanteen(int canteenId, {int limit = 6}) async {
    final response = await _apiClient.request(
      'api/recommendations/canteen/$canteenId',
      method: 'GET',
      authenticated: false,
      queryParameters: <String, dynamic>{'limit': limit},
    );
    return RecommendationSection.fromJson(_asMap(response.data));
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}
