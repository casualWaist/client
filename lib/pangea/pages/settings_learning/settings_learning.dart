import 'dart:async';

import 'package:fluffychat/pangea/controllers/pangea_controller.dart';
import 'package:fluffychat/pangea/pages/settings_learning/settings_learning_view.dart';
import 'package:fluffychat/pangea/widgets/user_settings/p_language_dialog.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

class SettingsLearning extends StatefulWidget {
  const SettingsLearning({super.key});

  @override
  SettingsLearningController createState() => SettingsLearningController();
}

class SettingsLearningController extends State<SettingsLearning> {
  late StreamSubscription _userSubscription;
  PangeaController pangeaController = MatrixState.pangeaController;

  setPublicProfile(bool b) async {
    await pangeaController.userController.updateUserProfile(publicProfile: b);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _userSubscription =
        pangeaController.userController.stateStream.listen((event) {
      setState(() {});
    });
  }

  Future<void> changeLanguage() async {
    await pLanguageDialog(context, () {});
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _userSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsLearningView(this);
  }
}
