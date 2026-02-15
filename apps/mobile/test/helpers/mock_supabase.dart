import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_data.dart';

/// Creates a mock [Client] that returns test data for Supabase REST API calls.
///
/// Use this with [Supabase.initialize] to provide mock HTTP transport.
Client createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;
    final query = request.url.queryParameters;

    if (path.contains('/auth/')) {
      return _authResponse(request);
    }

    if (path.contains('/rest/v1/')) {
      return _restResponse(request, path, query);
    }

    return Response(
      '{"error": "not found"}',
      404,
      headers: _jsonHeaders,
      request: request,
    );
  });
}

/// Creates a [SupabaseClient] backed by mock HTTP responses.
///
/// This client can be used directly in widget tests via
/// [SessionService.forTesting].
SupabaseClient createMockSupabaseClient() {
  return SupabaseClient(
    'http://localhost:54321',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
    httpClient: createMockHttpClient(),
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
    ),
  );
}

Response _authResponse(Request request) {
  final path = request.url.path;

  if (path.contains('/token')) {
    return Response(
      jsonEncode({'access_token': '', 'token_type': 'bearer'}),
      200,
      headers: _jsonHeaders,
      request: request,
    );
  }

  if (path.contains('/session')) {
    return Response(
      '{"error": "no session"}',
      401,
      headers: _jsonHeaders,
      request: request,
    );
  }

  if (path.contains('/otp')) {
    return Response('{}', 200, headers: _jsonHeaders, request: request);
  }

  return Response('{}', 200, headers: _jsonHeaders, request: request);
}

Response _restResponse(
  Request request,
  String path,
  Map<String, String> query,
) {
  final segments = path.split('/');
  final tableIdx = segments.indexOf('v1');
  if (tableIdx < 0 || tableIdx + 1 >= segments.length) {
    return Response('[]', 200, headers: _jsonHeaders, request: request);
  }
  final table = segments[tableIdx + 1];

  final isSingle =
      query.containsKey('id') && query['id']?.startsWith('eq.') == true;

  switch (table) {
    case 'users':
      if (isSingle) {
        return Response(
          jsonEncode(mockUserRow),
          200,
          headers: _jsonHeaders,
          request: request,
        );
      }
      return Response(
        jsonEncode([mockUserRow]),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    case 'user_roles':
      return Response(
        jsonEncode(mockUserRolesRows),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    case 'orders':
      if (isSingle) {
        return Response(
          jsonEncode(mockOrders.first),
          200,
          headers: _jsonHeaders,
          request: request,
        );
      }
      return Response(
        jsonEncode(mockOrders),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    case 'order_items':
      return Response(
        jsonEncode(mockOrderItems),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    case 'produce_listings':
      return Response(
        jsonEncode(mockProduceListings),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    case 'rider_trips':
      return Response(
        jsonEncode(mockRiderTrips),
        200,
        headers: _jsonHeaders,
        request: request,
      );

    default:
      return Response('[]', 200, headers: _jsonHeaders, request: request);
  }
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
