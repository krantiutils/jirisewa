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
    authOptions: const AuthClientOptions(autoRefreshToken: false),
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

  final isSingle = _isSingleRequest(query);

  List<Map<String, dynamic>> rows;
  switch (table) {
    case 'users':
      rows = [mockUserRow];
      break;

    case 'user_roles':
      rows = mockUserRolesRows;
      break;

    case 'orders':
      rows = mockOrders;
      break;

    case 'order_items':
      rows = mockOrderItems;
      break;

    case 'produce_listings':
      rows = mockProduceListings;
      break;

    case 'rider_trips':
      rows = mockRiderTrips;
      break;

    default:
      return Response('[]', 200, headers: _jsonHeaders, request: request);
  }

  final filteredRows = _applyQueryFilters(rows, query);
  final responseBody = isSingle
      ? jsonEncode(filteredRows.isNotEmpty ? filteredRows.first : null)
      : jsonEncode(filteredRows);

  return Response(responseBody, 200, headers: _jsonHeaders, request: request);
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

const _reservedQueryKeys = {
  'select',
  'order',
  'limit',
  'offset',
  'on_conflict',
  'columns',
};

bool _isSingleRequest(Map<String, String> query) {
  return query.containsKey('id') && query['id']?.startsWith('eq.') == true;
}

List<Map<String, dynamic>> _applyQueryFilters(
  List<Map<String, dynamic>> rows,
  Map<String, String> query,
) {
  var filtered = rows.where((row) {
    for (final entry in query.entries) {
      final key = entry.key;
      if (_reservedQueryKeys.contains(key)) continue;

      final value = entry.value;
      final rowValue = row[key];

      if (value.startsWith('eq.')) {
        if (!_matchesEq(rowValue, value.substring(3))) return false;
      } else if (value.startsWith('in.(') && value.endsWith(')')) {
        final allowedValues = _parseInValues(value);
        if (allowedValues.isEmpty) return false;
        if (!allowedValues.any((allowed) => _matchesEq(rowValue, allowed))) {
          return false;
        }
      }
    }
    return true;
  }).toList();

  final limit = int.tryParse(query['limit'] ?? '');
  if (limit != null && limit >= 0 && filtered.length > limit) {
    filtered = filtered.sublist(0, limit);
  }

  return filtered;
}

List<String> _parseInValues(String expression) {
  final values = expression.substring(4, expression.length - 1);
  if (values.trim().isEmpty) return const [];
  return values
      .split(',')
      .map((value) => value.trim().replaceAll('"', '').replaceAll("'", ''))
      .toList();
}

bool _matchesEq(dynamic rowValue, String expectedRaw) {
  if (expectedRaw == 'null') {
    return rowValue == null;
  }

  if (rowValue is bool) {
    return expectedRaw == rowValue.toString();
  }

  if (rowValue is num) {
    final expectedNum = num.tryParse(expectedRaw);
    return expectedNum != null && rowValue == expectedNum;
  }

  return rowValue?.toString() == expectedRaw;
}
