import 'dart:io';

import 'package:fluffychat/pangea/utils/error_handler.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/flutter_hive_collections_database.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_html/html.dart' as html;

import 'cipher.dart';
import 'sqlcipher_stub.dart'
    if (dart.library.io) 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

Future<DatabaseApi> flutterMatrixSdkDatabaseBuilder(Client client) async {
  MatrixSdkDatabase? database;
  try {
    database = await _constructDatabase(client);
    await database.open();
    return database;
    // #Pangea
    // } catch (e) {
  } catch (e, s) {
    ErrorHandler.logError(
      e: e,
      s: s,
      m: "Failed to open matrix sdk database. Openning fallback database.",
    );
    // Pangea#
    // Try to delete database so that it can created again on next init:
    database?.delete().catchError(
        // #Pangea
        // (e, s) => Logs().w(
        //   'Unable to delete database, after failed construction',
        //   e,
        //   s,
        // ),
        (e, s) {
      Logs().w(
        'Unable to delete database, after failed construction',
        e,
        s,
      );
      ErrorHandler.logError(
        e: e,
        s: s,
        m: "Failed to delete matrix database after failed construction.",
      );
    }
        // Pangea#
        );

    // Send error notification:
    // #Pangea
    // final l10n = lookupL10n(PlatformDispatcher.instance.locale);
    // ClientManager.sendInitNotification(
    //   l10n.initAppError,
    //   l10n.databaseBuildErrorBody(
    //     AppConfig.newIssueUrl.toString(),
    //     e.toString(),
    //   ),
    // );
    // Pangea#

    return FlutterHiveCollectionsDatabase.databaseBuilder(client);
  }
}

Future<MatrixSdkDatabase> _constructDatabase(Client client) async {
  if (kIsWeb) {
    html.window.navigator.storage?.persist();
    return MatrixSdkDatabase(client.clientName);
  }

  final cipher = await getDatabaseCipher();

  final fileStoragePath = PlatformInfos.isIOS || PlatformInfos.isMacOS
      ? await getLibraryDirectory()
      : await getApplicationSupportDirectory();

  final path = join(fileStoragePath.path, '${client.clientName}.sqlite');

  // fix dlopen for old Android
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  // import the SQLite / SQLCipher shared objects / dynamic libraries
  final factory =
      createDatabaseFactoryFfi(ffiInit: SQfLiteEncryptionHelper.ffiInit);

  // migrate from potential previous SQLite database path to current one
  await _migrateLegacyLocation(path, client.clientName);

  // required for [getDatabasesPath]
  databaseFactory = factory;

  // in case we got a cipher, we use the encryption helper
  // to manage SQLite encryption
  final helper = SQfLiteEncryptionHelper(
    factory: factory,
    path: path,
    cipher: cipher,
  );

  // check whether the DB is already encrypted and otherwise do so
  await helper.ensureDatabaseFileEncrypted();

  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      // most important : apply encryption when opening the DB
      onConfigure: helper.applyPragmaKey,
    ),
  );

  return MatrixSdkDatabase(
    client.clientName,
    database: database,
    maxFileSize: 1024 * 1024 * 10,
    fileStoragePath: fileStoragePath,
    deleteFilesAfterDuration: const Duration(days: 30),
  );
}

Future<void> _migrateLegacyLocation(
  String sqlFilePath,
  String clientName,
) async {
  final oldPath = PlatformInfos.isDesktop
      ? (await getApplicationSupportDirectory()).path
      : await getDatabasesPath();

  final oldFilePath = join(oldPath, clientName);
  if (oldFilePath == sqlFilePath) return;

  final maybeOldFile = File(oldFilePath);
  if (await maybeOldFile.exists()) {
    Logs().i(
      'Migrate legacy location for database from "$oldFilePath" to "$sqlFilePath"',
    );
    await maybeOldFile.copy(sqlFilePath);
    await maybeOldFile.delete();
  }
}
