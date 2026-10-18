import 'package:flutter_test/flutter_test.dart';
import 'package:levmax/services/supabase_api_service.dart';

void main() {
  test('Test Supabase API Service configuration & connection', () async {
    expect(SupabaseApiService.isConfigured, isTrue);
    expect(SupabaseApiService.supabaseUrl, equals('https://eoujrrvbrqotbnhsgjni.supabase.co'));

    final feedbackList = await SupabaseApiService.getFeedbackList();
    expect(feedbackList, isNotNull);
  });
}
