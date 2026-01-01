import 'dart:ui';

class WindowsInjector {
  static WindowsInjector get instance => _instance;
  static final WindowsInjector _instance = WindowsInjector._();
  bool _startInjectKeyData = false;
  WindowsInjector._();
  void injectKeyData() {
    Future.delayed(const Duration(seconds: 1), _injectkeyData);
  }

  void _injectkeyData() {
    final KeyDataCallback? callback = PlatformDispatcher.instance.onKeyData;
    if (callback == null) {
      return;
    }
    PlatformDispatcher.instance.onKeyData = (data) {
      if (!_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.down &&
          !data.synthesized) {
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.down,
          physical: 0x700e0,
          logical: 0x200000100,
          character: null,
          synthesized: false,
        );
        _startInjectKeyData = true;
      } else if (_startInjectKeyData &&
          data.physical == 0 &&
          data.logical == 0 &&
          data.type == KeyEventType.down &&
          !data.synthesized) {
        return true;
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.up &&
          !data.synthesized) {
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.down,
          physical: 0x70019,
          logical: 0x76,
          character: null,
          synthesized: false,
        );
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.down &&
          data.synthesized) {
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.up,
          physical: 0x70019,
          logical: 0x76,
          character: null,
          synthesized: false,
        );
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.up &&
          data.synthesized) {
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.up,
          physical: 0x700e0,
          logical: 0x200000100,
          character: null,
          synthesized: false,
        );
        _startInjectKeyData = false;
      } else {
        _startInjectKeyData = false;
      }
      return callback(data);
    };
  }
}
