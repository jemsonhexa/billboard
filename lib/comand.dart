import 'package:flutter/foundation.dart';

class CommandNotifier extends ChangeNotifier {
  String? _latestCommand;

  String? get latestCommand => _latestCommand;

  set latestCommand(String? value) {
    if (_latestCommand != value) {
      _latestCommand = value;
      notifyListeners(); //  notifies LocalPlayer
    }
  }
}
