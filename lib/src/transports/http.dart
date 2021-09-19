import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

late IOClient ioClient;

void httpInit() {
  var trustSelfSigned = true;
  var httpClient = HttpClient()
    ..badCertificateCallback =
        ((X509Certificate cert, String host, int port) => trustSelfSigned);
  ioClient = IOClient(httpClient);
}

Future<http.Response> httpGet(Uri url, {Map<String, String>? headers}) =>
    ioClient.get(url, headers: headers);

Future<http.Response> httpPost(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    ioClient.post(url, headers: headers, body: body, encoding: encoding);
