import 'package:fluffychat/pages/chat_details/chat_details.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';

class ClassNameButton extends StatelessWidget {
  final Room room;
  final ChatDetailsController controller;
  const ClassNameButton({
    Key? key,
    required this.room,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).textTheme.bodyLarge!.color;
    return Column(
      children: [
        ListTile(
          onTap: controller.setDisplaynameAction,
          title: Text(
            room.isSpace
              ? L10n.of(context)!
                  .changeTheNameOfTheClass
              : L10n.of(context)!
                  .changeTheNameOfTheChat,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: iconColor,
            child: const Icon(Icons.people_outline_outlined),
          ),
          subtitle: Text(
            room.getLocalizedDisplayname(
              MatrixLocals(L10n.of(context)!),
            ),
          ),
        ),
      ],
    );
  }
}