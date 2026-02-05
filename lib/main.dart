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
  LanClipboardClient? client;
  late void Function(String text) send;
  String ip = "";
  final int port = 5555;
  final token = _rand();
  final TextEditingController hostIpController = TextEditingController();
  String clientStatus = "Not connected";

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

    sync = ClipboardSync((text) => send(text));
    server = LanClipboardServer(
      port,
      token,
      onRemote: (text) => sync.applyRemote(text),
    );
    await server.start();

    send = (text) {
      server.emit(text);
      client?.send(text);
    };
    sync.start();

    setState(() {});
  }

  static String _rand() {
    const chars = "ABCDEFG123456789";
    final r = Random();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> connectToHost(String hostIp) async {
    if (hostIp.trim().isEmpty) return;
    final endpoint = "ws://$hostIp:$port";
    client?.dispose();
    setState(() {
      clientStatus = "Connecting to $endpoint";
    });

    final newClient = LanClipboardClient(
      endpoint: endpoint,
      token: token,
      onRemote: (text) => sync.applyRemote(text),
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          clientStatus = status == "Connected"
              ? "Connected to $endpoint"
              : status;
        });
      },
    );

    try {
      await newClient.connect();
      setState(() {
        client = newClient;
        clientStatus = "Connected to $endpoint";
      });
    } catch (e) {
      newClient.dispose();
      if (!mounted) return;
      setState(() {
        clientStatus = "Failed to connect: $e";
      });
    }
  }

  void disconnectFromHost() {
    client?.dispose();
    setState(() {
      client = null;
      clientStatus = "Not connected";
    });
  }

  @override
  void dispose() {
    hostIpController.dispose();
    client?.dispose();
    super.dispose();
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
              const SizedBox(height: 24),
              const Text("Connect to host"),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: hostIpController,
                  decoration: const InputDecoration(
                    labelText: "Host IP",
                    hintText: "e.g. 192.168.1.10",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: client == null
                    ? () => connectToHost(hostIpController.text)
                    : disconnectFromHost,
                child: Text(client == null ? "Connect" : "Disconnect"),
              ),
              const SizedBox(height: 8),
              Text(clientStatus),
            ],
          ),
        ),
      ),
    );
  }
}
