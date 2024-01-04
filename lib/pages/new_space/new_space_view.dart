import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pangea/constants/class_default_values.dart';
import 'package:fluffychat/pangea/extensions/client_extension.dart';
import 'package:fluffychat/pangea/pages/class_settings/p_class_widgets/room_rules_editor.dart';
import 'package:fluffychat/pangea/widgets/class/add_class_and_invite.dart';
import 'package:fluffychat/pangea/widgets/class/add_space_toggles.dart';
import 'package:fluffychat/pangea/widgets/space/class_settings.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import 'new_space.dart';

class NewSpaceView extends StatelessWidget {
  final NewSpaceController controller;

  const NewSpaceView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    // #Pangea
    final activeColor = Theme.of(context).brightness == Brightness.dark
        ? AppConfig.primaryColorLight
        : AppConfig.primaryColor;
    // Pangea#
    return Scaffold(
      appBar: AppBar(
        // #Pangea
        centerTitle: true,
        title: Text(
          controller.newClassMode
              ? L10n.of(context)!.createNewClass
              : L10n.of(context)!.newExchange,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.class_outlined),
            selectedIcon: const Icon(Icons.class_),
            color: controller.newClassMode ? activeColor : null,
            isSelected: controller.newClassMode,
            onPressed: () => context.go('/rooms/newspace'),
          ),
          IconButton(
            icon: const Icon(Icons.connecting_airports),
            selectedIcon: const Icon(Icons.connecting_airports),
            color: !controller.newClassMode ? activeColor : null,
            isSelected: !controller.newClassMode,
            onPressed: () => context.go('/rooms/newspace/exchange'),
          ),
        ],
        // title: Text(L10n.of(context)!.createNewSpace),
        // Pangea#
      ),
      body: MaxWidthBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                // #Pangea
                maxLength: ClassDefaultValues.maxClassName,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                // Pangea#
                controller: controller.controller,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.go,
                onSubmitted: controller.submitAction,
                decoration: InputDecoration(
                  labelText: L10n.of(context)!.spaceName,
                  prefixIcon: const Icon(Icons.people_outlined),
                  hintText: L10n.of(context)!.enterASpacepName,
                ),
              ),
            ),
            // #Pangea
            if (controller.newClassMode)
              ClassSettings(
                key: controller.classSettingsKey,
                roomId: null,
                startOpen: true,
                initialSettings:
                    Matrix.of(context).client.lastUpdatedClassSettings,
              ),
            if (!controller.newClassMode)
              AddToSpaceToggles(
                key: controller.addToSpaceKey,
                startOpen: false,
                mode: !controller.newClassMode
                    ? AddToClassMode.exchange
                    : AddToClassMode.chat,
              ),
            RoomRulesEditor(
              key: controller.rulesEditorKey,
              roomId: null,
              startOpen: false,
              initialRules: Matrix.of(context).client.lastUpdatedRoomRules,
            ),
            // SwitchListTile.adaptive(
            //   title: Text(L10n.of(context)!.spaceIsPublic),
            //   value: controller.publicGroup,
            //   onChanged: controller.setPublicGroup,
            // ),
            // ListTile(
            //   trailing: const Padding(
            //     padding: EdgeInsets.symmetric(horizontal: 16.0),
            //     child: Icon(Icons.info_outlined),
            //   ),
            //   subtitle: Text(L10n.of(context)!.newSpaceDescription),
            // ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: controller.submitAction,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.newClassMode
                              ? L10n.of(context)!.createClass
                              : L10n.of(context)!.createExchange,
                        ),
                      ),
                      Icon(Icons.adaptive.arrow_forward_outlined),
                    ],
                  ),
                ),
              ),
            ),
            // Pangea#
          ],
        ),
      ),
      // #Pangea
      // floatingActionButton: FloatingActionButton(
      //   onPressed: controller.submitAction,
      //   child: const Icon(Icons.arrow_forward_outlined),
      // ),
      // Pangea#
    );
  }
}
