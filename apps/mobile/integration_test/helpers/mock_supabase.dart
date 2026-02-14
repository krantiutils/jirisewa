import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_data.dart';

/// Creates a [SupabaseClient] backed by mock HTTP responses.
///
/// This client does not need `Supabase.initialize()` or platform channels.
/// It can be used in both widget tests (`flutter test`) and integration tests.
SupabaseClient createMockSupabaseClient() {
  final mockHttpClient = MockClient((request) async {
    final path = request.url.path;
    final query = request.url.queryParameters;

    // Auth endpoints — return minimal valid responses.
    if (path.contains('/auth/')) {
      return _authResponse(request);
    }

    // PostgREST endpoints: /rest/v1/{table_name}
    if (path.contains('/rest/v1/')) {
      return _restResponse(path, query);
    }

    return Response('{"error": "not found"}', 404, headers: _jsonHeaders);
  });

  return SupabaseClient(
    'http://localhost:54321',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
    httpClient: mockHttpClient,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
    ),
  );
}

Response _authResponse(Request request) {
  final path = request.url.path;

  // Token refresh — return empty (no session).
  if (path.contains('/token')) {
    return Response(
      jsonEncode({'access_token': '', 'token_type': 'bearer'}),
      200,
      headers: _jsonHeaders,
    );
  }

  // Session recovery — no stored session.
  if (path.contains('/session')) {
    return Response('{"error": "no session"}', 401, headers: _jsonHeaders);
  }

  // OTP send — success.
  if (path.contains('/otp')) {
    return Response('{}', 200, headers: _jsonHeaders);
  }

  return Response('{}', 200, headers: _jsonHeaders);
}

Response _restResponse(String path, Map<String, String> query) {
  // Extract table name from /rest/v1/{table}
  final segments = path.split('/');
  final tableIdx = segments.indexOf('v1');
  if (tableIdx < 0 || tableIdx + 1 >= segments.length) {
    return Response('[]', 200, headers: _jsonHeaders);
  }
  final table = segments[tableIdx + 1];

  // Check if this is a single-row request (has id=eq.<uuid> filter).
  final isSingle =
      query.containsKey('id') && query['id']?.startsWith('eq.') == true;

  switch (table) {
    case 'users':
      if (isSingle) {
        return Response(jsonEncode(mockUserRow), 200, headers: _jsonHeaders);
      }
      return Response(jsonEncode([mockUserRow]), 200, headers: _jsonHeaders);

    case 'user_roles':
      return Response(
        jsonEncode(mockUserRolesRows),
        200,
        headers: _jsonHeaders,
      );

    case 'orders':
      if (isSingle) {
        return Response(
          jsonEncode(mockOrders.first),
          200,
          headers: _jsonHeaders,
        );
      }
      return Response(jsonEncode(mockOrders), 200, headers: _jsonHeaders);

    case 'order_items':
      return Response(
        jsonEncode(mockOrderItems),
        200,
        headers: _jsonHeaders,
      );

    case 'produce_listings':
      return Response(
        jsonEncode(mockProduceListings),
        200,
        headers: _jsonHeaders,
      );

    case 'rider_trips':
      return Response(jsonEncode(mockRiderTrips), 200, headers: _jsonHeaders);

    default:
      return Response('[]', 200, headers: _jsonHeaders);
  }
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
