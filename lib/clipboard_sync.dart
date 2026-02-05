import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/services.dart';
class ClipboardSync with ClipboardListener {
  final void Function(String text) send;
  String _last = "";

  ClipboardSync(this.send);

  void start() {
    ClipboardWatcher.instance.addListener(this);
    ClipboardWatcher.instance.start();
  }

  @override
  void onClipboardChanged() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text != _last) {
      _last = data.text!;
      send(_last);
      print("Sent clipboard: $_last");
    }
  }

  void applyRemote(String text) async {
    if (text != _last) {
      _last = text;
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
