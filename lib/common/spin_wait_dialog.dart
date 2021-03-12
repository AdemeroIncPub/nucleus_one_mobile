import 'package:flutter/material.dart';

class SpinWaitDialog extends StatefulWidget {
  const SpinWaitDialog();
  
  @override
  _SpinWaitDialogState createState() => _SpinWaitDialogState();
}

class _SpinWaitDialogState extends State<SpinWaitDialog> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
