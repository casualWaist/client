import 'dart:developer';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pangea/models/bot_options_model.dart';
import 'package:fluffychat/pangea/utils/bot_name.dart';
import 'package:fluffychat/pangea/widgets/space/language_level_dropdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:matrix/matrix.dart';

import '../../../widgets/matrix.dart';
import '../../constants/pangea_event_types.dart';
import '../../extensions/pangea_room_extension.dart';
import '../../utils/error_handler.dart';

class ConversationBotSettings extends StatefulWidget {
  final Room? room;
  final bool startOpen;
  // final ClassSettingsModel? initialSettings;

  const ConversationBotSettings({
    super.key,
    this.room,
    this.startOpen = false,
    // this.initialSettings,
  });

  @override
  ConversationBotSettingsState createState() => ConversationBotSettingsState();
}

class ConversationBotSettingsState extends State<ConversationBotSettings> {
  late BotOptionsModel botOptions;
  late bool isOpen;
  bool addBot = false;

  ConversationBotSettingsState({Key? key});

  @override
  void initState() {
    super.initState();
    isOpen = widget.startOpen;
    botOptions = widget.room?.botOptions ?? BotOptionsModel();
    widget.room?.isBotRoom.then((bool isBotRoom) {
      setState(() {
        addBot = isBotRoom;
      });
    });
  }

  Future<void> updateBotOption(void Function() makeLocalChange) async {
    makeLocalChange();
    await showFutureLoadingDialog(
      context: context,
      future: () async {
        try {
          await setBotOption();
        } catch (err, stack) {
          debugger(when: kDebugMode);
          ErrorHandler.logError(e: err, s: stack);
        }
        setState(() {});
      },
    );
  }

  Future<void> setBotOption() async {
    if (widget.room == null) return;
    try {
      await Matrix.of(context).client.setRoomStateWithKey(
            widget.room!.id,
            PangeaEventTypes.botOptions,
            '',
            botOptions.toJson(),
          );
    } catch (err, stack) {
      debugger(when: kDebugMode);
      ErrorHandler.logError(e: err, s: stack);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            title: Text(
              L10n.of(context)!.convoBotSettingsTitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(L10n.of(context)!.convoBotSettingsDescription),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).textTheme.bodyLarge!.color,
              child: const Icon(Icons.psychology_outlined),
            ),
            trailing: Icon(
              isOpen
                  ? Icons.keyboard_arrow_down_outlined
                  : Icons.keyboard_arrow_right_outlined,
            ),
            onTap: () => setState(() => isOpen = !isOpen),
          ),
          if (isOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOpen ? null : 0,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    title: Text(
                      L10n.of(context)!.addConversationBot,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(L10n.of(context)!.addConversationBotDesc),
                    secondary: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      foregroundColor:
                          Theme.of(context).textTheme.bodyLarge!.color,
                      child: const Icon(Icons.sms_outlined),
                    ),
                    activeColor: AppConfig.activeToggleColor,
                    value: addBot,
                    onChanged: (bool add) {
                      setState(() => addBot = add);
                      add
                          ? widget.room?.invite(BotName.byEnvironment)
                          : widget.room?.kick(BotName.byEnvironment);
                    },
                  ),
                  if (addBot) ...[
                    ListTile(
                      onTap: () async {
                        final topic = await showTextInputDialog(
                          context: context,
                          textFields: [
                            DialogTextField(
                              initialText: botOptions.topic.isEmpty
                                  ? ""
                                  : botOptions.topic,
                              hintText:
                                  L10n.of(context)!.enterAConversationTopic,
                            ),
                          ],
                          title: L10n.of(context)!.conversationTopic,
                        );
                        if (topic == null) return;
                        updateBotOption(() {
                          botOptions.topic = topic.single;
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        foregroundColor:
                            Theme.of(context).textTheme.bodyLarge!.color,
                        child: const Icon(Icons.topic_outlined),
                      ),
                      subtitle: Text(
                        botOptions.topic.isEmpty
                            ? L10n.of(context)!.enterAConversationTopic
                            : botOptions.topic,
                      ),
                      title: Text(
                        L10n.of(context)!.conversationTopic,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      title: Text(
                        L10n.of(context)!.enableModeration,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(L10n.of(context)!.enableModerationDesc),
                      secondary: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        foregroundColor:
                            Theme.of(context).textTheme.bodyLarge!.color,
                        child: const Icon(Icons.shield_outlined),
                      ),
                      activeColor: AppConfig.activeToggleColor,
                      value: botOptions.safetyModeration,
                      onChanged: (bool newValue) => updateBotOption(() {
                        botOptions.safetyModeration = newValue;
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                      child: Text(
                        L10n.of(context)!.conversationLanguageLevel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    LanguageLevelDropdown(
                      initialLevel: botOptions.languageLevel,
                      onChanged: (int? newValue) => updateBotOption(() {
                        botOptions.languageLevel = newValue!;
                      }),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
}
