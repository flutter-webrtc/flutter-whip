import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'logger.dart';
import 'transports/http.dart' if (dart.library.html) 'transports/http_web.dart';
import 'utils.dart';

enum WhipMode {
  kSend,
  kReceive,
}

enum WhipState {
  kNew,
  kInitialized,
  kConnecting,
  kConnected,
  kDisconnected,
}

class WHIP {
  Function(RTCTrackEvent)? onTrack;
  WhipState state = WhipState.kNew;
  RTCPeerConnection? pc;
  late WhipMode mode;
  final String url;
  Map<String, String>? headers = {};
  String videoCodec = 'vp8';
  WHIP({required this.url, this.headers});

  Future<void> initlize(
      {required WhipMode mode, MediaStream? stream, String? videoCodec}) async {
    initHttpClient();
    if (pc != null) {
      return;
    }
    if (videoCodec != null) {
      this.videoCodec = videoCodec.toLowerCase();
    }
    this.mode = mode;
    pc = await createPeerConnection({'sdpSemantics': 'unified-plan'});
    pc!.onIceCandidate = onicecandidate;
    pc!.onTrack = (RTCTrackEvent event) => onTrack?.call(event);
    switch (mode) {
      case WhipMode.kSend:
        stream?.getTracks().forEach((track) async {
          await pc!.addTrack(track, stream);
        });
        break;
      case WhipMode.kReceive:
        await pc!.addTransceiver(kind: RTCRtpMediaType.RTCRtpMediaTypeAudio);
        await pc!.addTransceiver(kind: RTCRtpMediaType.RTCRtpMediaTypeVideo);
        break;
    }
    log.debug('Initlize whip connection: mode = $mode, stream = ${stream?.id}');
    state = WhipState.kInitialized;
  }

  Future<void> connect() async {
    try {
      state = WhipState.kConnecting;
      var desc = await pc!.createOffer();

      setPreferredCodec(desc, videoCodec: videoCodec);

      await pc!.setLocalDescription(desc);

      var offer = await pc!.getLocalDescription();
      log.debug('Sending offer: $offer');
      var respose = await httpPost(Uri.parse(url),
          headers: {
            'Content-Type': 'application/sdp',
            if (headers != null) ...headers!
          },
          body: offer!.sdp);
      final answer = RTCSessionDescription(respose.body, 'answer');
      log.debug('Received answer: ${answer.sdp}');
      await pc!.setRemoteDescription(answer);
      state = WhipState.kConnected;
    } catch (e) {
      log.error('connect error: $e');
      state = WhipState.kDisconnected;
      rethrow;
    }
  }

  void close() async {
    if (state == WhipState.kDisconnected) {
      return;
    }
    log.debug('Closing whip connection');
    await httpDelete(Uri.parse(url));
    state = WhipState.kDisconnected;
    await pc?.close();
  }

  void onicecandidate(RTCIceCandidate? candidate) async {
    if (candidate == null) {
      return;
    }
    log.debug('Sending candidate: ${candidate.toMap().toString()}');
    var respose = await httpPatch(Uri.parse(url),
        headers: {
          'Content-Type': 'application/trickle-ice-sdpfrag',
          if (headers != null) ...headers!
        },
        body: candidate.candidate);
    log.debug('Received Patch response: ${respose.body}');
    // TODO(cloudwebrtc): Add remote candidate to local pc.
  }

  void setPreferredCodec(RTCSessionDescription description,
      {String audioCodec = 'opus', String videoCodec = 'vp8'}) {
    var capSel = CodecCapabilitySelector(description.sdp!);
    var acaps = capSel.getCapabilities('audio');
    if (acaps != null) {
      acaps.codecs = acaps.codecs
          .where((e) => (e['codec'] as String).toLowerCase() == audioCodec)
          .toList();
      acaps.setCodecPreferences('audio', acaps.codecs);
      capSel.setCapabilities(acaps);
    }
    var vcaps = capSel.getCapabilities('video');
    if (vcaps != null) {
      vcaps.codecs = vcaps.codecs
          .where((e) => (e['codec'] as String).toLowerCase() == videoCodec)
          .toList();
      vcaps.setCodecPreferences('video', vcaps.codecs);
      capSel.setCapabilities(vcaps);
    }
    description.sdp = capSel.sdp();
  }
}
