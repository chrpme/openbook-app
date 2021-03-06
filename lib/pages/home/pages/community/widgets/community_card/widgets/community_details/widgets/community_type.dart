import 'package:Openbook/models/community.dart';
import 'package:Openbook/widgets/icon.dart';
import 'package:Openbook/widgets/theming/text.dart';
import 'package:flutter/material.dart';

class OBCommunityType extends StatelessWidget {
  final Community community;

  const OBCommunityType(this.community);

  @override
  Widget build(BuildContext context) {
    CommunityType type = community.type;

    if (type == null) {
      return const SizedBox();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        OBIcon(
          type == CommunityType.private ? OBIcons.privateCommunity : OBIcons.publicCommunity,
          customSize: 16,
        ),
        const SizedBox(
          width: 10,
        ),
        Flexible(
          child: OBText(
            type == CommunityType.private ? 'Private' : 'Public',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )
      ],
    );
  }
}
