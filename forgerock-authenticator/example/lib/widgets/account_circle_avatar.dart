/*
 * Copyright (c) 2022 ForgeRock. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import 'package:flutter/material.dart';

/// This widget creates a [CircleAvatar] to represent the [Account].
class AccountCircleAvatar extends StatelessWidget {

  final String text;

  const AccountCircleAvatar({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.grey,
      child: Text(text.substring(0,1),
        style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold
        ),
      ),
    );
  }

}