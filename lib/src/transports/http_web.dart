import 'dart:convert';

import 'package:http/http.dart' as http;

void initHttpClient() {}

Future<http.Response> httpPost(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    http.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> httpPatch(Uri url,
    {Map<String, String>? headers, Object? body}) async {
  final response = await http.patch(url, headers: headers, body: body);
  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
  return response;
}

Future<http.Response> httpDelete(Uri url) async {
  final response = await http.delete(url);
  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
  return response;
}
