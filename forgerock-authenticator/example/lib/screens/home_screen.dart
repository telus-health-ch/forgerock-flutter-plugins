// ignore_for_file: body_might_complete_normally_catch_error

/*
 * Copyright (c) 2022-2023 ForgeRock. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import 'dart:async';
import 'dart:convert';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forgerock_authenticator/forgerock_push_connector.dart';
import 'package:forgerock_authenticator/models/push_notification.dart';
import 'package:forgerock_authenticator_example/providers/authenticator_provider.dart';
import 'package:forgerock_authenticator_example/widgets/account_list.dart';
import 'package:forgerock_authenticator_example/widgets/actions_menu.dart';
import 'package:forgerock_authenticator_example/widgets/alert_dialog.dart';
import 'package:forgerock_authenticator_example/widgets/app_bar.dart';
import 'package:forgerock_authenticator_example/widgets/notification_dialog.dart';
import 'package:provider/provider.dart';

/// This is the main screen of the app. It shows a list of accounts registered
/// with the SDK.
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ForgerockPushConnector pushConnector = ForgerockPushConnector();

  @override
  void initState() {
    _setupPushConnector();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scan(context);
        },
        backgroundColor: Colors.orange,
        child: const Icon(
          Icons.qr_code_scanner,
          size: 30,
          color: Colors.white,
        ),
      ),
      appBar: AuthenticatorAppBar(actions: [ActionsMenu()]),
      body: AccountList(),
    );
  }

  Future<void> _setupPushConnector() async {
    pushConnector.token.addListener(() {
      debugPrint('Token ${pushConnector.token.value}');
    });

    pushConnector.pendingNotification.addListener(() {
      _processPendingNotification(pushConnector.pendingNotification.value);
    });
  }

  Future<void> _processPendingNotification(dynamic pendingNotification) async {
    if (pendingNotification != null) {
      final PushNotification notification = PushNotification.fromJson(jsonDecode(pendingNotification));
      if (notification.pending == true && !notification.isExpired()) {
        debugPrint('Processing pending notification with id ${notification.messageId}');
        showDialog<Widget>(
          context: context,
          builder: (BuildContext context) {
            return NotificationDialog(
              pushNotification: notification,
            );
          },
        );
      }
    }
  }

  Future<void> _scan(BuildContext context) async {
    final BuildContext rootContext = context.findRootAncestorStateOfType<NavigatorState>()!.context;
    try {
      final ScanResult result = await BarcodeScanner.scan();
      final String qrResult = result.rawContent;
      if (qrResult != '') {
        Provider.of<AuthenticatorProvider>(context, listen: false).addAccount(qrResult).catchError(
          (Object error) {
            alert(rootContext, 'Error adding account via QRCode', error.toString());
          },
        );
      }
    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.cameraAccessDenied) {
        alert(context, 'Error', 'Camera Access was not granted');
      } else {
        alert(context, 'Error', e.toString());
      }
    } catch (e) {
      alert(context, 'Error', e.toString());
    }
  }
}
