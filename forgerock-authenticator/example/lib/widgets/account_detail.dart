/*
 * Copyright (c) 2022 ForgeRock. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import 'package:flutter/material.dart';
import 'package:forgerock_authenticator/models/account.dart';
import 'package:forgerock_authenticator/models/oath_mechanism.dart';
import 'package:forgerock_authenticator/models/oath_token_code.dart';
import 'package:forgerock_authenticator_example/providers/authenticator_provider.dart';
import 'package:forgerock_authenticator_example/widgets/count_down_timer.dart';
import 'package:provider/provider.dart';

/// This widget is used with OATH accounts to display an [OathTokenCode].
class AccountDetail extends StatefulWidget {
  final Account account;

  const AccountDetail(this.account);

  @override
  _AccountDetailState createState() => _AccountDetailState();
}

class _AccountDetailState extends State<AccountDetail> {
  late Future<OathTokenCode?> _oathTokenCode;
  late int _duration;

  Account get account => widget.account;

  @override
  void initState() {
    super.initState();
    _oathTokenCode = _getNextOathTokenCode();
    _duration = 0;
  }

  void refresh() {
    setState(() {
      _oathTokenCode = _getNextOathTokenCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _oathTokenCode,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (_duration == 0) {
              _duration = _getDuration(snapshot.data!);
            }
            return Row(
              children: [
                Column(
                  children: [
                    Text(_formartCode(snapshot.data!), style: const TextStyle(fontSize: 32, color: Colors.black))
                  ],
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                      child: _displayOTPAction(context, snapshot.data!),
                    )
                  ],
                )
              ],
            );
          } else {
            return const SizedBox(
              height: 0,
              width: 0,
            );
          }
        });
  }

  Widget _displayOTPAction(BuildContext context, OathTokenCode oathTokenCode) {
    if (oathTokenCode.oathType == TokenType.TOTP) {
      return Container(
          padding: const EdgeInsets.fromLTRB(6, 0, 0, 0),
          child: CountDownTimer(
              timeTotal: _getDuration(oathTokenCode),
              timeRemaining: _getSecondsLeft(oathTokenCode),
              width: 38,
              height: 38,
              onComplete: refresh));
    } else {
      return SizedBox(
          height: 38.0,
          width: 38.0,
          child: IconButton(
            padding: const EdgeInsets.all(0.0),
            color: Colors.grey,
            icon: const Icon(Icons.refresh, size: 42.0),
            onPressed: refresh,
          ));
    }
  }

  Future<OathTokenCode?> _getNextOathTokenCode() async {
    if (account.getOathMechanism()?.id case final id?) {
      return await Provider.of<AuthenticatorProvider>(context, listen: false).getOathTokenCode(id);
    } else {
      return null;
    }
  }

  String _formartCode(OathTokenCode oathTokenCode) {
    final String code = oathTokenCode.code ?? '';
    final int half = code.length ~/ 2;
    return "${code.substring(0, half)} ${code.substring(half, code.length)}";
  }

  int _getSecondsLeft(OathTokenCode oathTokenCode) {
    final int cur = DateTime.now().millisecondsSinceEpoch;
    final int total = (oathTokenCode.until ?? 0) - (oathTokenCode.start ?? 0);
    final int state = cur - (oathTokenCode.start ?? 0);
    final int secondsLeft = ((total - state) ~/ 1000) + 1;

    if (0 <= secondsLeft) {
      return secondsLeft;
    } else {
      return 1;
    }
  }

  int _getDuration(OathTokenCode oathTokenCode) {
    return ((oathTokenCode.until ?? 0) - (oathTokenCode.start ?? 0)) ~/ 1000;
  }
}
