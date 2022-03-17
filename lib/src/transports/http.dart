import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

late IOClient ioClient;
bool initliazed = false;

void initHttpClient() {
  if (!initliazed) {
    var trustSelfSigned = true;
    var httpClient = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => trustSelfSigned);
    ioClient = IOClient(httpClient);
    initliazed = true;
  }
}

// POST/PATCH/DELETE
Future<http.Response> httpPost(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    ioClient.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> httpPatch(Uri url,
    {Map<String, String>? headers, Object? body}) async {
  final response = await ioClient.patch(url, headers: headers, body: body);
  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
  return response;
}

Future<http.Response> httpDelete(Uri url) async {
  final response = await ioClient.delete(url);
  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
  return response;
}
