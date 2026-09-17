import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rest_api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = RestApiConfig.buildUri(
      path,
      queryParameters: queryParameters,
    );

    try {
      final mergedHeaders = <String, String>{
        'accept': 'application/json',
        'content-type': 'application/json',
        ...?headers,
      };

      final request = http.Request(method, uri)..headers.addAll(mergedHeaders);

      if (body != null) {
        request.body = jsonEncode(body);
      }

      if (kDebugMode) {
        debugPrint('[API] URL: $uri');
      }

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 20));
          
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = response.body;

      if (kDebugMode) {
        debugPrint('[API] STATUS: ${response.statusCode}');
        debugPrint('[API] RESPONSE LENGTH: ${responseBody.length}');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          message: 'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: responseBody,
        );
      }

      if (responseBody.isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const FormatException('Expected object JSON response');
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[API] ERROR: $e');
      rethrow;
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[API] ERROR: $e');
      rethrow;
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('[API] ERROR: $e');
      rethrow;
    } on http.ClientException catch (error) {
      if (kDebugMode) debugPrint('[API] ERROR: $error');
      rethrow;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[API] ERROR: $e');
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('[API] ERROR: $error');
      throw ApiException(message: 'Unexpected API error: $error');
    }
  }
}
