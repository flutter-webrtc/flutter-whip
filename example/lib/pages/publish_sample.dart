import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_whip/flutter_whip.dart';

import 'qr_scanner.dart';

class WhipPublishSample extends StatefulWidget {
  static String tag = 'whip_publish_sample';

  @override
  _WhipPublishSampleState createState() => _WhipPublishSampleState();
}

class _WhipPublishSampleState extends State<WhipPublishSample> {
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  List<MediaDeviceInfo>? _mediaDevicesList;
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
    _localRenderer.dispose();
  }

  void initRenderers() async {
    await _localRenderer.initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _connect() async {
    if (url == null) {
      return;
    }

    _whip = WHIP(url: url!);
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
      await _whip.initlize(mode: WhipMode.kSend, stream: _localStream);
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
      if (kIsWeb) {
        _localStream?.getTracks().forEach((track) => track.stop());
      }
      await _localStream?.dispose();
      _localRenderer.srcObject = null;
      _whip.close();
      setState(() {
        _connecting = false;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void _toggleCamera() async {
    if (_localStream == null) throw Exception('Stream is not initialized');
    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    await Helper.switchCamera(videoTrack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WHIP Publish Sample'), actions: <Widget>[
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
        if (_connecting)
          IconButton(
            icon: Icon(Icons.switch_video),
            onPressed: _toggleCamera,
          ),
        if (_connecting)
          PopupMenuButton<String>(
            onSelected: _selectAudioOutput,
            itemBuilder: (BuildContext context) {
              if (_mediaDevicesList != null) {
                return _mediaDevicesList!
                    .where((device) => device.kind == 'audiooutput')
                    .map((device) {
                  return PopupMenuItem<String>(
                    value: device.deviceId,
                    child: Text(device.label),
                  );
                }).toList();
              }
              return [];
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
                child: RTCVideoView(_localRenderer,
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
              child: Icon(_connecting ? Icons.call_end : Icons.phone),
            )
          : Container(),
    );
  }

  void _selectAudioOutput(String deviceId) {
    _localRenderer.audioOutput(deviceId);
  }
}
