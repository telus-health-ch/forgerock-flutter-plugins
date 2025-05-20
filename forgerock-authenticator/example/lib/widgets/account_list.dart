/*
 * Copyright (c) 2022 ForgeRock. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import 'package:flutter/material.dart';
import 'package:forgerock_authenticator_example/providers/authenticator_provider.dart';
import 'package:forgerock_authenticator_example/widgets/account_card.dart';
import 'package:forgerock_authenticator_example/widgets/account_list_empty.dart';
import 'package:provider/provider.dart';

/// The [AccountList] widget list all accounts registered with the SDK.
class AccountList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticatorProvider>(
      builder: (context, authenticatorProvider, child) {
        if (authenticatorProvider.accounts.isNotEmpty) {
          return ListView.builder(
            itemCount: authenticatorProvider.accounts.length,
            itemBuilder: (context, index) {
              return AccountCard(
                authenticatorProvider.accounts[index],
                false,
                key: ValueKey(authenticatorProvider.accounts[index].id),
              );
            },
          );
        } else {
          return AccountEmptyList();
        }
      },
    );
  }
}
