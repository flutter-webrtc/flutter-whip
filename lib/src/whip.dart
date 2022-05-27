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
  kFailure,
}

class WHIP {
  Function(RTCTrackEvent)? onTrack;
  Function(WhipState)? onState;
  Object? lastError;
  WhipState state = WhipState.kNew;
  RTCPeerConnection? pc;
  late WhipMode mode;
  final String url;
  String? resourceURL;
  Map<String, String>? headers = {};
  String? videoCodec;
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
    pc = await createPeerConnection({
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });
    pc?.onIceCandidate = onicecandidate;
    pc?.onIceConnectionState = (state) {
      print('state: ${state.toString()}');
    };
    pc!.onTrack = (RTCTrackEvent event) => onTrack?.call(event);
    switch (mode) {
      case WhipMode.kSend:
        stream?.getTracks().forEach((track) async {
          await pc!.addTransceiver(
              track: track,
              kind: track.kind == 'audio'
                  ? RTCRtpMediaType.RTCRtpMediaTypeAudio
                  : RTCRtpMediaType.RTCRtpMediaTypeVideo,
              init: RTCRtpTransceiverInit(
                  direction: TransceiverDirection.SendOnly, streams: [stream]));
        });
        break;
      case WhipMode.kReceive:
        await pc!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
            init: RTCRtpTransceiverInit(
                direction: TransceiverDirection.RecvOnly));
        await pc!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(
                direction: TransceiverDirection.RecvOnly));
        break;
    }
    log.debug('Initlize whip connection: mode = $mode, stream = ${stream?.id}');
    setState(WhipState.kInitialized);
  }

  Future<void> connect() async {
    try {
      setState(WhipState.kConnecting);
      var desc = await pc!.createOffer({});

      if (mode == WhipMode.kSend && videoCodec != null) {
        setPreferredCodec(desc, videoCodec: videoCodec!);
      }

      await pc!.setLocalDescription(desc);

      var offer = await pc!.getLocalDescription();
      final sdp = offer!.sdp;
      log.debug('Sending offer: $sdp');
      var respose = await httpPost(Uri.parse(url),
          headers: {
            'Content-Type': 'application/sdp',
            if (headers != null) ...headers!
          },
          body: sdp);

      if (respose.statusCode != 200 && respose.statusCode != 201) {
        throw Exception('Failed to send offer: ${respose.statusCode}');
      }

      log.debug('Resource URL: $resourceURL');
      final answer = RTCSessionDescription(respose.body, 'answer');
      log.debug('Received answer: ${answer.sdp}');
      await pc!.setRemoteDescription(answer);
      setState(WhipState.kConnected);

      resourceURL = respose.headers['location'];
      if (resourceURL == null) {
        resourceURL = url;
        log.warn('Resource url not found, use $url as resource url!');
      } else {
        if (resourceURL!.startsWith('/')) {
          var uri = Uri.parse(url);
          resourceURL = '${uri.origin}$resourceURL';
        }
      }
    } catch (e) {
      log.error('connect error: $e');
      setState(WhipState.kFailure);
      lastError = e;
    }
  }

  void close() async {
    if (state == WhipState.kDisconnected) {
      return;
    }
    log.debug('Closing whip connection');
    await pc?.close();
    try {
      if (resourceURL == null) {
        throw 'Resource url not found!';
      }
      await httpDelete(Uri.parse(resourceURL ?? url));
    } catch (e) {
      log.error('connect error: $e');
      setState(WhipState.kFailure);
      lastError = e;
      return;
    }
    setState(WhipState.kDisconnected);
  }

  void onicecandidate(RTCIceCandidate? candidate) async {
    if (candidate == null || resourceURL == null) {
      return;
    }
    log.debug('Sending candidate: ${candidate.toMap().toString()}');
    try {
      var respose = await httpPatch(Uri.parse(resourceURL!),
          headers: {
            'Content-Type': 'application/trickle-ice-sdpfrag',
            if (headers != null) ...headers!
          },
          body: candidate.candidate);
      log.debug('Received Patch response: ${respose.body}');
      // TODO(cloudwebrtc): Add remote candidate to local pc.
    } catch (e) {
      log.error('connect error: $e');
      setState(WhipState.kFailure);
      lastError = e;
    }
  }

  void setState(WhipState newState) {
    onState?.call(newState);
    state = newState;
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
