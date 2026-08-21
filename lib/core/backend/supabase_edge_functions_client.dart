import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'edge_functions_client.dart';

/// The real [EdgeFunctionsClient], backed by `supabase_flutter`'s
/// [sb.FunctionsClient]. Constructed from a [sb.SupabaseClient] that
/// already carries the signed-in user's session — this class never reads
/// or holds a service-role key, and never constructs its own Supabase
/// client with elevated credentials. Every call runs as whichever user
/// is currently signed in on [_client], exactly like any other
/// `supabase_flutter` call the rest of the app might make.
class SupabaseEdgeFunctionsClient implements EdgeFunctionsClient {
  const SupabaseEdgeFunctionsClient(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<Map<String, Object?>> invoke(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final sb.FunctionResponse response;
    try {
      response = await _client.functions.invoke(functionName, body: body);
    } on sb.FunctionException catch (e) {
      throw EdgeFunctionCallFailure(
        _extractMessage(e.details) ??
            e.reasonPhrase ??
            'Edge function call failed.',
        errorCode: _extractErrorCode(e.details),
        statusCode: e.status,
      );
    } catch (e) {
      throw EdgeFunctionCallFailure('Edge function call failed: $e');
    }

    final data = response.data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const EdgeFunctionCallFailure(
      'Edge function returned a non-object response body.',
    );
  }

  String? _extractMessage(Object? details) {
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    return null;
  }

  String? _extractErrorCode(Object? details) {
    if (details is Map && details['errorCode'] is String) {
      return details['errorCode'] as String;
    }
    return null;
  }
}
