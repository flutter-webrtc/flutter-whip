import 'dart:convert';

import 'package:http/http.dart' as http;

void httpInit() {}

Future<http.Response> httpGet(Uri url, {Map<String, String>? headers}) =>
    http.get(url, headers: headers);

Future<http.Response> httpPost(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    http.post(url, headers: headers, body: body, encoding: encoding);
