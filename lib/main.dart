import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'server.dart';
import 'clipboard_sync.dart';

void main() {
  runApp(const ClipboardHostApp());
}

class ClipboardHostApp extends StatefulWidget {
  const ClipboardHostApp({super.key});
  @override
  State<ClipboardHostApp> createState() => _ClipboardHostState();
}

class _ClipboardHostState extends State<ClipboardHostApp> {
  late LanClipboardServer server;
  late ClipboardSync sync;
  String ip = "";
  final int port = 5555;
  final token = _rand();

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    // Attempt to find a valid LAN IP
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        // Skip common virtual/VPN interfaces if needed, but for now just grab the first non-loopback
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }
        if (ip.isNotEmpty) break;
      }
    } catch (e) {
      print("Error getting IP: $e");
    }

    if (ip.isEmpty) ip = "0.0.0.0";

    server = LanClipboardServer(port, token);
    await server.start();

    sync = ClipboardSync(server);
    sync.start();

    setState(() {});
  }

  static String _rand() {
    const chars = "ABCDEFG123456789";
    final r = Random();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final qr = {"mode": "lan", "endpoint": "ws://$ip:$port", "token": token};

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("LAN Clipboard Host")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("IP: $ip"),
              Text("Port: $port"),
              Text("Token: $token"),
              const SizedBox(height: 20),
              QrImageView(data: qr.toString(), size: 200),
            ],
          ),
        ),
      ),
    );
  }
}
