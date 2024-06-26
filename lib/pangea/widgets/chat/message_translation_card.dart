import 'package:fluffychat/pangea/matrix_event_wrappers/pangea_message_event.dart';
import 'package:fluffychat/pangea/models/representation_content_model.dart';
import 'package:fluffychat/pangea/repo/full_text_translation_repo.dart';
import 'package:fluffychat/pangea/utils/bot_style.dart';
import 'package:fluffychat/pangea/utils/error_handler.dart';
import 'package:fluffychat/pangea/widgets/chat/message_text_selection.dart';
import 'package:fluffychat/pangea/widgets/chat/toolbar_content_loading_indicator.dart';
import 'package:fluffychat/pangea/widgets/igc/card_error_widget.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

class MessageTranslationCard extends StatefulWidget {
  final PangeaMessageEvent messageEvent;
  final bool immersionMode;
  final MessageTextSelection selection;

  const MessageTranslationCard({
    super.key,
    required this.messageEvent,
    required this.immersionMode,
    required this.selection,
  });

  @override
  MessageTranslationCardState createState() => MessageTranslationCardState();
}

class MessageTranslationCardState extends State<MessageTranslationCard> {
  PangeaRepresentation? repEvent;
  String? selectionTranslation;
  String? oldSelectedText;
  String? l1Code;
  String? l2Code;
  bool _fetchingRepresentation = false;

  String? translationLangCode() {
    if (widget.immersionMode) return l1Code;
    final String? originalWrittenCode =
        widget.messageEvent.originalWritten?.content.langCode;
    return l1Code == originalWrittenCode ? l2Code : l1Code;
  }

  Future<void> fetchRepresentation(BuildContext context) async {
    final String? langCode = translationLangCode();
    if (langCode == null) return;

    repEvent = widget.messageEvent
        .representationByLanguage(
          langCode,
        )
        ?.content;

    if (repEvent == null && mounted) {
      repEvent = await widget.messageEvent.representationByLanguageGlobal(
        langCode: langCode,
      );
    }
  }

  Future<void> translateSelection() async {
    final String? targetLang = translationLangCode();

    if (widget.selection.selectedText == null ||
        targetLang == null ||
        l1Code == null ||
        l2Code == null) {
      selectionTranslation = null;
      return;
    }

    oldSelectedText = widget.selection.selectedText;
    final String accessToken =
        await MatrixState.pangeaController.userController.accessToken;

    final resp = await FullTextTranslationRepo.translate(
      accessToken: accessToken,
      request: FullTextTranslationRequestModel(
        text: widget.selection.messageText,
        tgtLang: translationLangCode()!,
        userL1: l1Code!,
        userL2: l2Code!,
        srcLang: widget.messageEvent.messageDisplayLangCode,
        length: widget.selection.selectedText!.length,
        offset: widget.selection.offset,
      ),
    );

    if (mounted) {
      selectionTranslation = resp.bestTranslation;
    }
  }

  Future<void> loadTranslation(Future<void> Function() future) async {
    if (!mounted) return;
    setState(() => _fetchingRepresentation = true);
    try {
      await future();
    } catch (err) {
      ErrorHandler.logError(e: err);
    }

    if (mounted) {
      setState(() => _fetchingRepresentation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    l1Code = MatrixState.pangeaController.languageController.activeL1Code(
      roomID: widget.messageEvent.room.id,
    );
    l2Code = MatrixState.pangeaController.languageController.activeL2Code(
      roomID: widget.messageEvent.room.id,
    );
    if (mounted) {
      setState(() {});
    }

    loadTranslation(() async {
      if (widget.selection.selectedText != null) {
        await translateSelection();
      }
      await fetchRepresentation(context);
    });
  }

  @override
  void didUpdateWidget(covariant MessageTranslationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldSelectedText != widget.selection.selectedText) {
      loadTranslation(translateSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_fetchingRepresentation &&
        repEvent == null &&
        selectionTranslation == null) {
      return const CardErrorWidget();
    }

    return Container(
      child: _fetchingRepresentation
          ? const ToolbarContentLoadingIndicator()
          : selectionTranslation != null
              ? Text(
                  selectionTranslation!,
                  style: BotStyle.text(context),
                )
              : Text(
                  repEvent!.text,
                  style: BotStyle.text(context),
                ),
    );
  }
}
