import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart';

import 'logger.dart';
import 'stream.dart';
import 'transports/http.dart' if (dart.library.html) 'transports/http_web.dart';
import 'utils.dart';

const API_CHANNEL = 'whip-api';

class WHIP {
  Function(RTCTrackEvent)? onTrack;
  Function(RTCDataChannel)? onDataChannel;
  Function()? onAPIOpen;

  late RTCPeerConnection pc;
  RTCDataChannel? api;
  final String url;

  WHIP(this.url);

  void initlize() async {
    pc = await createPeerConnection({});

    api = await pc.createDataChannel(
        API_CHANNEL, RTCDataChannelInit()..maxRetransmits = 30);

    pc.onRenegotiationNeeded = onnegotiationneeded;
    pc.onIceCandidate = onicecandidate;
    await pc.setLocalDescription(await pc.createOffer());
  }

  void close() async {
    await httpDelete(Uri.parse(url));
  }

  Future<List<StatsReport>> getPubStats(MediaStreamTrack? selector) {
    return pc.getStats(selector);
  }

  Future<List<StatsReport>> getSubStats(MediaStreamTrack? selector) {
    return pc.getStats(selector);
  }

  Future<void> publish(LocalStream stream) async {
    await stream.publish(pc);
  }

  Future<void> onnegotiationneeded() async {
    try {
      var offer = await pc.createOffer({});
      setPreferredCodec(offer);
      await pc.setLocalDescription(offer);
      var answer = await httpPost(
        Uri.parse(url),
        body: offer,
        headers: {'Content-Type': 'application/sdp'},
      );
      //await pc.setRemoteDescription(answer.body);
    } catch (err, st) {
      log.error('onnegotiationneeded: e => ${err.toString()} $st');
    }
  }

  void onicecandidate(RTCIceCandidate? candidate) async {
    if (candidate == null) {
      return;
    }
    var respose = await httpPatch(Uri.parse(url),
        headers: {'Content-Type': 'application/trickle-ice-sdpfrag'},
        body: candidate.toMap());

    // TODO(cloudwebrtc): respose.statusCode
  }

  void setPreferredCodec(RTCSessionDescription description) {
    var capSel = CodecCapabilitySelector(description.sdp!);
    var acaps = capSel.getCapabilities('audio');
    if (acaps != null) {
      acaps.codecs = acaps.codecs
          .where((e) => (e['codec'] as String).toLowerCase() == 'opus')
          .toList();
      acaps.setCodecPreferences('audio', acaps.codecs);
      capSel.setCapabilities(acaps);
    }
    var vcaps = capSel.getCapabilities('video');
    if (vcaps != null) {
      vcaps.codecs = vcaps.codecs
          .where((e) => (e['codec'] as String).toLowerCase() == 'vp8')
          .toList();
      vcaps.setCodecPreferences('video', vcaps.codecs);
      capSel.setCapabilities(vcaps);
    }
    description.sdp = capSel.sdp();
  }
}
