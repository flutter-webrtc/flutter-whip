import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_whip/flutter_whip.dart';

import 'qr_scanner.dart';

class WhipSubscribeSample extends StatefulWidget {
  static String tag = 'whip_subscribe_sample';

  @override
  _WhipSubscribeSampleState createState() => _WhipSubscribeSampleState();
}

class _WhipSubscribeSampleState extends State<WhipSubscribeSample> {
  final _remoteRenderer = RTCVideoRenderer();
  bool _connecting = false;
  late WHIP _whip;
  String? url;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  @override
  void deactivate() {
    super.deactivate();
    _remoteRenderer.dispose();
  }

  void initRenderers() async {
    await _remoteRenderer.initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _connect() async {
    if (url == null) {
      return;
    }
    _whip = WHIP(url: url!);
    try {
      await _whip.initlize(mode: WhipMode.kReceive);
      _whip.onTrack = (event) {
        if (event.track.kind == 'video') {
          _remoteRenderer.srcObject = event.streams[0];
        }
      };
      await _whip.connect();
    } catch (e) {
      print(e.toString());
      return;
    }
    if (!mounted) return;

    setState(() {
      _connecting = true;
    });
  }

  void _disconnect() async {
    try {
      _remoteRenderer.srcObject = null;
      _whip.close();
      setState(() {
        _connecting = false;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WHIP Subscribe Sample'), actions: <Widget>[
        if (!_connecting)
          IconButton(
            icon: Icon(Icons.qr_code_scanner_sharp),
            onPressed: () async {
              Future future = Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => QRViewExample()));

              future.then((value) {
                print('QR code result: $value');
                this.setState(() {
                  url = value;
                });
              });
            },
          ),
      ]),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Column(children: <Widget>[
            FittedBox(
              child: Text(
                'URL: ${url ?? 'Not set, Please scan the QR code ...'}',
                textAlign: TextAlign.left,
              ),
            ),
            Center(
              child: Container(
                margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height - 110,
                decoration: BoxDecoration(color: Colors.black54),
                child: RTCVideoView(_remoteRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            )
          ]);
        },
      ),
      floatingActionButton: url != null
          ? FloatingActionButton(
              onPressed: _connecting ? _disconnect : _connect,
              tooltip: _connecting ? 'Hangup' : 'Call',
              child: Icon(_connecting ? Icons.stop : Icons.play_arrow_sharp),
            )
          : Container(),
    );
  }
}
