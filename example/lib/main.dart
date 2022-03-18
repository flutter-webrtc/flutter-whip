import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'route_item.dart';
import 'pages/publish_sample.dart';
import 'pages/subscribe_sample.dart';

void main() {
  if (!WebRTC.platformIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late List<RouteItem> items;

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  ListBody _buildRow(context, item) {
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(item.title),
        onTap: () => item.push(context),
        trailing: Icon(Icons.arrow_right),
      ),
      Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: Text('Flutter WHIP example'),
          ),
          body: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: items.length,
              itemBuilder: (context, i) {
                return _buildRow(context, items[i]);
              })),
    );
  }

  void _initItems() {
    items = <RouteItem>[
      RouteItem(
          title: 'Publish Sample',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => WhipPublishSample()));
          }),
      RouteItem(
          title: 'Subscribe Sample',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => WhipSubscribeSample()));
          }),
    ];
  }
}
