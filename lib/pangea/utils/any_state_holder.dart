import 'package:fluffychat/pangea/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class PangeaAnyState {
  final Map<String, LayerLinkAndKey> _layerLinkAndKeys = {};
  OverlayEntry? overlay;

  dispose() {
    closeOverlay();
    _layerLinkAndKeys.clear();
  }

  LayerLinkAndKey layerLinkAndKey(
    String transformTargetId, [
    throwErrorIfNotThere = false,
  ]) {
    if (_layerLinkAndKeys[transformTargetId] == null) {
      if (throwErrorIfNotThere) {
        Sentry.addBreadcrumb(Breadcrumb.fromJson(_layerLinkAndKeys));
        throw Exception("layerLinkAndKey with null for $transformTargetId");
      } else {
        _layerLinkAndKeys[transformTargetId] =
            LayerLinkAndKey(transformTargetId);
      }
    }

    return _layerLinkAndKeys[transformTargetId]!;
  }

  void disposeByWidgetKey(String transformTargetId) {
    _layerLinkAndKeys.remove(transformTargetId);
  }

  void openOverlay(OverlayEntry entry, BuildContext context) {
    closeOverlay();
    overlay = entry;
    Overlay.of(context).insert(overlay!);
  }

  void closeOverlay() {
    if (overlay != null) {
      try {
        overlay?.remove();
      } catch (err, s) {
        ErrorHandler.logError(
          e: err,
          s: s,
          data: {
            "overlay": overlay,
          },
        );
      }
      overlay = null;
    }
  }

  LayerLinkAndKey messageLinkAndKey(String eventId) => layerLinkAndKey(eventId);

  // String chatViewTargetKey(String? roomId) => "chatViewKey$roomId";
  // LayerLinkAndKey chatViewLinkAndKey(String? roomId) =>
  //     layerLinkAndKey(chatViewTargetKey(roomId));
}

class LayerLinkAndKey {
  late LabeledGlobalKey key;
  late LayerLink link;
  String transformTargetId;

  LayerLinkAndKey(this.transformTargetId) {
    key = LabeledGlobalKey(transformTargetId);
    link = LayerLink();
  }

  Map<String, dynamic> toJson() => {
        "key": key.toString(),
        "link": link.toString(),
        "transformTargetId": transformTargetId,
      };
}
