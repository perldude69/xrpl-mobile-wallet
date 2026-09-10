import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/swipe_to_sign.dart';

WidgetbookUseCase swipeSignUseCase() {
  return WidgetbookUseCase(
    name: 'Slide to sign',
    builder: (context) {
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Confirm send',
      );
      final message = context.knobs.string(
        label: 'Message',
        initialValue: 'Slide to sign and submit this payment.',
      );
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SwipeToSignPanel(
          title: title,
          message: message,
          actionLabel: 'Slide to sign',
          onComplete: () {},
        ),
      );
    },
  );
}
