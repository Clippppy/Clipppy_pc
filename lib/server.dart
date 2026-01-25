import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LanClipboardServer {
  final int port;
  final String token;
  final Set<WebSocketChannel> _clients = {};

  LanClipboardServer(this.port, this.token);

  Future<void> start() async {
    void handleWebSocket(WebSocketChannel channel, String? protocol) {
      _clients.add(channel);
      print("Device connected");

      channel.stream.listen(
        (msg) {
          final data = jsonDecode(msg);
          if (data['token'] != token) return;

          print("Received clipboard: ${data['text']}");

          _broadcast(data['text'], except: channel);
        },
        onDone: () {
          _clients.remove(channel);
        },
      );
    }

    final handler = webSocketHandler(handleWebSocket);

    await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print("LAN WebSocket running on $port");
  }

  void emit(String text) {
    for (final c in _clients) {
      c.sink.add(jsonEncode({"token": token, "text": text}));
    }
  }

  void _broadcast(String text, {WebSocketChannel? except}) {
    for (final c in _clients) {
      if (c != except) {
        c.sink.add(jsonEncode({"token": token, "text": text}));
      }
    }
  }
}
