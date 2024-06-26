import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fluffychat/pangea/constants/model_keys.dart';
import 'package:fluffychat/pangea/controllers/text_to_speech_controller.dart';
import 'package:fluffychat/pangea/enum/audio_encoding_enum.dart';
import 'package:fluffychat/pangea/extensions/pangea_room_extension/pangea_room_extension.dart';
import 'package:fluffychat/pangea/matrix_event_wrappers/pangea_representation_event.dart';
import 'package:fluffychat/pangea/models/choreo_record.dart';
import 'package:fluffychat/pangea/models/class_model.dart';
import 'package:fluffychat/pangea/models/pangea_match_model.dart';
import 'package:fluffychat/pangea/models/representation_content_model.dart';
import 'package:fluffychat/pangea/models/speech_to_text_models.dart';
import 'package:fluffychat/pangea/models/tokens_event_content_model.dart';
import 'package:fluffychat/pangea/utils/bot_name.dart';
import 'package:fluffychat/pangea/widgets/chat/message_audio_card.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../widgets/matrix.dart';
import '../constants/language_keys.dart';
import '../constants/pangea_event_types.dart';
import '../enum/use_type.dart';
import '../utils/error_handler.dart';

class PangeaMessageEvent {
  late Event _event;
  final Timeline timeline;
  final bool ownMessage;
  bool _isValidPangeaMessageEvent = true;

  PangeaMessageEvent({
    required Event event,
    required this.timeline,
    required this.ownMessage,
  }) {
    if (event.type != EventTypes.Message) {
      _isValidPangeaMessageEvent = false;
      ErrorHandler.logError(
        m: "${event.type} should not be used to make a PangeaMessageEvent",
      );
    }
    _event = event;
  }

  //the timeline filters the edits and uses the original events
  //so this event will always be the original and the sdk getter body
  //handles getting the latest text from the aggregated events
  Event get event => _event;

  String get body => _event.body;

  String get senderId => _event.senderId;

  DateTime get originServerTs => _event.originServerTs;

  String get eventId => _event.eventId;

  Room get room => _event.room;

  bool get isAudioMessage => _event.messageType == MessageTypes.Audio;

  Event? _latestEditCache;
  Event get _latestEdit => _latestEditCache ??= _event
          .aggregatedEvents(
            timeline,
            RelationshipTypes.edit,
          )
          //sort by event.originServerTs to get the most recent first
          .sorted(
            (a, b) => b.originServerTs.compareTo(a.originServerTs),
          )
          .firstOrNull ??
      _event;

  Event updateLatestEdit() {
    _latestEditCache = null;
    _representations = null;
    return _latestEdit;
  }

  Future<PangeaAudioFile> getMatrixAudioFile(
    String langCode,
    BuildContext context,
  ) async {
    final String text = (await representationByLanguageGlobal(
          langCode: langCode,
        ))
            ?.text ??
        body;
    final TextToSpeechRequest params = TextToSpeechRequest(
      text: text,
      langCode: langCode,
    );

    final TextToSpeechResponse response =
        await MatrixState.pangeaController.textToSpeech.get(
      params,
    );

    final audioBytes = base64.decode(response.audioContent);
    final eventIdParam = _event.eventId;
    final fileName =
        "audio_for_${eventIdParam}_$langCode.${response.fileExtension}";

    final file = PangeaAudioFile(
      bytes: audioBytes,
      name: fileName,
      mimeType: response.mimeType,
      duration: response.durationMillis,
      waveform: response.waveform,
    );

    sendAudioEvent(file, response, text, langCode);

    return file;
  }

  Future<Event?> sendAudioEvent(
    PangeaAudioFile file,
    TextToSpeechResponse response,
    String text,
    String langCode,
  ) async {
    final String? eventId = await room.sendFileEvent(
      file,
      inReplyTo: _event,
      extraContent: {
        'info': {
          ...file.info,
          'duration': response.durationMillis,
        },
        'org.matrix.msc3245.voice': {},
        'org.matrix.msc1767.audio': {
          'duration': response.durationMillis,
          'waveform': response.waveform,
        },
        ModelKey.transcription: {
          ModelKey.text: text,
          ModelKey.langCode: langCode,
        },
      },
    );

    debugPrint("eventId in getTextToSpeechGlobal $eventId");
    final Event? audioEvent =
        eventId != null ? await room.getEventById(eventId) : null;

    if (audioEvent == null) {
      return null;
    }
    allAudio.add(audioEvent);
    return audioEvent;
  }

  //get audio for text and language
  //if no audio exists, create it
  //if audio exists, return it
  Future<Event?> getTextToSpeechGlobal(String langCode) async {
    final String text = representationByLanguage(langCode)?.text ?? body;

    final local = getTextToSpeechLocal(langCode, text);

    if (local != null) return Future.value(local);

    final TextToSpeechRequest params = TextToSpeechRequest(
      text: text,
      langCode: langCode,
    );

    final TextToSpeechResponse response =
        await MatrixState.pangeaController.textToSpeech.get(
      params,
    );

    final audioBytes = base64.decode(response.audioContent);

    // if (!TextToSpeechController.isOggFile(audioBytes)) {
    //   throw Exception("File is not a valid OGG format");
    // } else {
    //   debugPrint("File is a valid OGG format");
    // }

    // from text, trim whitespace, remove special characters, and limit to 20 characters
    // final fileName =
    //     text.trim().replaceAll(RegExp('[^A-Za-z0-9]'), '').substring(0, 20);
    final eventIdParam = _event.eventId;
    final fileName =
        "audio_for_${eventIdParam}_$langCode.${response.fileExtension}";

    final file = MatrixAudioFile(
      bytes: audioBytes,
      name: fileName,
      mimeType: response.mimeType,
    );

    // try {
    final String? eventId = await room.sendFileEvent(
      file,
      inReplyTo: _event,
      extraContent: {
        'info': {
          ...file.info,
          'duration': response.durationMillis,
        },
        'org.matrix.msc3245.voice': {},
        'org.matrix.msc1767.audio': {
          'duration': response.durationMillis,
          'waveform': response.waveform,
        },
        ModelKey.transcription: {
          ModelKey.text: text,
          ModelKey.langCode: langCode,
        },
      },
    );
    // .timeout(
    //   Durations.long4,
    //   onTimeout: () {
    //     debugPrint("timeout in getTextToSpeechGlobal");
    //     return null;
    //   },
    // );

    debugPrint("eventId in getTextToSpeechGlobal $eventId");
    return eventId != null ? room.getEventById(eventId) : null;
  }

  Event? getTextToSpeechLocal(String langCode, String text) {
    return allAudio.firstWhereOrNull(
      (element) {
        // Safely access the transcription map
        final transcription = element.content.tryGetMap(ModelKey.transcription);

        // return transcription != null;
        if (transcription == null) {
          // If transcription is null, this element does not match.
          return false;
        }

        // Safely get language code and text from the transcription
        final elementLangCode = transcription[ModelKey.langCode];
        final elementText = transcription[ModelKey.text];

        // Check if both language code and text matsch
        return elementLangCode == langCode && elementText == text;
      },
    );
  }

  // get audio events that are related to this event
  Set<Event> get allAudio => _latestEdit
          .aggregatedEvents(
        timeline,
        RelationshipTypes.reply,
      )
          .where((element) {
        return element.content.tryGet<Map<String, dynamic>>(
              ModelKey.transcription,
            ) !=
            null;
      }).toSet();

  Future<SpeechToTextModel?> getSpeechToText(
    String l1Code,
    String l2Code,
  ) async {
    if (!isAudioMessage) {
      ErrorHandler.logError(
        e: 'Calling getSpeechToText on non-audio message',
        s: StackTrace.current,
        data: {
          "content": _event.content,
          "eventId": _event.eventId,
          "roomId": _event.roomId,
          "userId": _event.room.client.userID,
          "account_data": _event.room.client.accountData,
        },
      );
      return null;
    }

    final SpeechToTextModel? speechToTextLocal = representations
        .firstWhereOrNull(
          (element) => element.content.speechToText != null,
        )
        ?.content
        .speechToText;

    if (speechToTextLocal != null) return speechToTextLocal;

    final matrixFile = await _event.downloadAndDecryptAttachment();
    // Pangea#
    // File? file;

    // TODO: Test on mobile and see if we need this case, doeesn't seem so
    // if (!kIsWeb) {
    //   final tempDir = await getTemporaryDirectory();
    //   final fileName = Uri.encodeComponent(
    //     // #Pangea
    //     // widget.event.attachmentOrThumbnailMxcUrl()!.pathSegments.last,
    //     widget.messageEvent.event
    //         .attachmentOrThumbnailMxcUrl()!
    //         .pathSegments
    //         .last,
    //     // Pangea#
    //   );
    //   file = File('${tempDir.path}/${fileName}_${matrixFile.name}');
    //   await file.writeAsBytes(matrixFile.bytes);
    // }

    // audioFile = file;

    debugPrint("mimeType ${matrixFile.mimeType}");
    debugPrint("encoding ${mimeTypeToAudioEncoding(matrixFile.mimeType)}");

    final SpeechToTextModel response =
        await MatrixState.pangeaController.speechToText.get(
      SpeechToTextRequestModel(
        audioContent: matrixFile.bytes,
        audioEvent: _event,
        config: SpeechToTextAudioConfigModel(
          encoding: mimeTypeToAudioEncoding(matrixFile.mimeType),
          //this is the default in the RecordConfig in record package
          //TODO: check if this is the correct value and make it a constant somewhere
          sampleRateHertz: 22050,
          userL1: l1Code,
          userL2: l2Code,
        ),
      ),
    );

    _representations?.add(
      RepresentationEvent(
        timeline: timeline,
        content: PangeaRepresentation(
          langCode: response.langCode,
          text: response.transcript.text,
          originalSent: false,
          originalWritten: false,
          speechToText: response,
        ),
      ),
    );

    return response;
  }

  List<RepresentationEvent>? _representations;
  List<RepresentationEvent> get representations {
    if (_representations != null) return _representations!;
    _representations = [];

    if (_latestEdit.content[ModelKey.originalSent] != null) {
      try {
        final RepresentationEvent sent = RepresentationEvent(
          content: PangeaRepresentation.fromJson(
            _latestEdit.content[ModelKey.originalSent] as Map<String, dynamic>,
          ),
          tokens: _latestEdit.content[ModelKey.tokensSent] != null
              ? PangeaMessageTokens.fromJson(
                  _latestEdit.content[ModelKey.tokensSent]
                      as Map<String, dynamic>,
                )
              : null,
          choreo: _latestEdit.content[ModelKey.choreoRecord] != null
              ? ChoreoRecord.fromJson(
                  _latestEdit.content[ModelKey.choreoRecord]
                      as Map<String, dynamic>,
                )
              : null,
          timeline: timeline,
        );
        if (_latestEdit.content[ModelKey.choreoRecord] == null) {
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: "originalSent created without _event or _choreo",
              data: {
                "eventId": _latestEdit.eventId,
                "room": _latestEdit.room.id,
                "sender": _latestEdit.senderId,
              },
            ),
          );
        }
        _representations!.add(sent);
      } catch (err, s) {
        ErrorHandler.logError(
          m: "error parsing originalSent",
          e: err,
          s: s,
        );
      }
    }

    if (_latestEdit.content[ModelKey.originalWritten] != null) {
      try {
        _representations!.add(
          RepresentationEvent(
            content: PangeaRepresentation.fromJson(
              _latestEdit.content[ModelKey.originalWritten]
                  as Map<String, dynamic>,
            ),
            tokens: _latestEdit.content[ModelKey.tokensWritten] != null
                ? PangeaMessageTokens.fromJson(
                    _latestEdit.content[ModelKey.tokensWritten]
                        as Map<String, dynamic>,
                  )
                : null,
            timeline: timeline,
          ),
        );
      } catch (err, s) {
        ErrorHandler.logError(
          m: "error parsing originalWritten",
          e: err,
          s: s,
        );
      }
    }

    _representations!.addAll(
      _latestEdit
          .aggregatedEvents(
            timeline,
            PangeaEventTypes.representation,
          )
          .map(
            (e) => RepresentationEvent(event: e, timeline: timeline),
          )
          .sorted(
        (a, b) {
          //TODO - test with edited events to make sure this is working
          if (a.event == null) return -1;
          if (b.event == null) return 1;
          return b.event!.originServerTs.compareTo(a.event!.originServerTs);
        },
      ).toList(),
    );

    return _representations!;
  }

  RepresentationEvent? representationByLanguage(String langCode) =>
      representations.firstWhereOrNull(
        (element) => element.langCode == langCode,
      );

  int translationIndex(String langCode) => representations.indexWhere(
        (element) => element.langCode == langCode,
      );

  String translationTextSafe(String langCode) {
    return representationByLanguage(langCode)?.text ?? body;
  }

  bool get isNew =>
      DateTime.now().difference(originServerTs.toLocal()).inSeconds < 8;

  Future<RepresentationEvent?> _repLocal(String langCode) async {
    int tries = 0;

    RepresentationEvent? rep = representationByLanguage(langCode);

    while ((isNew || eventId.contains("web")) && tries < 20) {
      if (rep != null) return rep;
      await Future.delayed(const Duration(milliseconds: 500));
      rep = representationByLanguage(langCode);
      tries += 1;
    }
    return rep;
  }

  Future<PangeaRepresentation?> representationByLanguageGlobal({
    required String langCode,
  }) async {
    // try {
    final RepresentationEvent? repLocal = await _repLocal(langCode);

    if (repLocal != null ||
        langCode == LanguageKeys.unknownLanguage ||
        langCode == LanguageKeys.mixedLanguage ||
        langCode == LanguageKeys.multiLanguage) return repLocal?.content;

    if (eventId.contains("web")) return null;

    // should this just be the original event body?
    // worth a conversation with the team
    final PangeaRepresentation? basis =
        (originalWritten ?? originalSent)?.content;

    final PangeaRepresentation? pangeaRep =
        await MatrixState.pangeaController.messageData.getPangeaRepresentation(
      text: basis?.text ?? _latestEdit.body,
      source: basis?.langCode,
      target: langCode,
      room: _latestEdit.room,
    );

    if (pangeaRep == null ||
        await _latestEdit.room.getEventById(_latestEdit.eventId) == null) {
      return null;
    }

    MatrixState.pangeaController.messageData
        .sendRepresentationMatrixEvent(
      representation: pangeaRep,
      messageEventId: _latestEdit.eventId,
      room: _latestEdit.room,
      target: langCode,
    )
        .then(
      (value) {
        representations.add(
          RepresentationEvent(
            event: value,
            timeline: timeline,
          ),
        );
      },
    ).onError(
      (error, stackTrace) => ErrorHandler.logError(e: error, s: stackTrace),
    );

    return pangeaRep;
  }

  RepresentationEvent? get originalSent => representations
      .firstWhereOrNull((element) => element.content.originalSent);

  RepresentationEvent? get originalWritten => representations
      .firstWhereOrNull((element) => element.content.originalWritten);

  PangeaRepresentation get defaultRepresentation => PangeaRepresentation(
        langCode: LanguageKeys.unknownLanguage,
        text: body,
        originalSent: false,
        originalWritten: false,
      );

  UseType get useType => useTypeCalculator(originalSent?.choreo);

  bool get showUseType =>
      !ownMessage &&
      _event.room.isSpaceAdmin &&
      _event.senderId != BotName.byEnvironment &&
      !room.isUserSpaceAdmin(_event.senderId) &&
      _event.messageType != PangeaEventTypes.report &&
      _event.messageType == MessageTypes.Text;

  String get messageDisplayLangCode {
    final bool immersionMode = MatrixState
        .pangeaController.permissionsController
        .isToolEnabled(ToolSetting.immersionMode, room);
    final String? l2Code = MatrixState.pangeaController.languageController
        .activeL2Code(roomID: room.id);
    final String? originalLangCode =
        (originalWritten ?? originalSent)?.langCode;

    final String? langCode = immersionMode ? l2Code : originalLangCode;
    return langCode ?? LanguageKeys.unknownLanguage;
  }

  List<PangeaMatch>? errorSteps(String lemma) {
    final RepresentationEvent? repEvent = originalSent ?? originalWritten;
    if (repEvent?.choreo == null) return null;

    final List<PangeaMatch> steps = repEvent!.choreo!.choreoSteps
        .where(
          (choreoStep) =>
              choreoStep.acceptedOrIgnoredMatch != null &&
              choreoStep.acceptedOrIgnoredMatch?.match.shortMessage == lemma,
        )
        .map((element) => element.acceptedOrIgnoredMatch)
        .cast<PangeaMatch>()
        .toList();
    return steps;
  }

  // List<SpanData> get activities =>
  //each match is turned into an activity that other students can access
  //they're not told the answer but have to find it themselves
  //the message has a blank piece which they fill in themselves

  // replication of logic from message_content.dart
  // bool get isHtml =>
  //     AppConfig.renderHtml && !_event.redacted && _event.isRichMessage;
}

class URLFinder {
  static Iterable<Match> getMatches(String text) {
    final RegExp exp =
        RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
    return exp.allMatches(text);
  }
}
