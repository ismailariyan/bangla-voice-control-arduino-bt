import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_ble/flutter_bluetooth_serial_ble.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String words = '';

  @override
  void initState() {
    super.initState();
    initSpeech();

    // Your existing Bluetooth connection setup code remains unchanged
    // ...
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      words = "${result.recognizedWords}";
    });
    // Once you have the recognized text, you may want to send it through the Bluetooth connection
    _sendMessage(words);
  }

  @override
  Widget build(BuildContext context) {
    // Your existing build method remains mostly unchanged
    // Only the FloatingActionButton will be updated to start listening for speech input
    // ...

    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting chat to ' + serverName + '...')
              : isConnected
                  ? Text('Live chat with ' + serverName)
                  : Text('Chat log with ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              child: ListView(
                  padding: const EdgeInsets.all(12.0),
                  controller: listScrollController,
                  children: list),
            ),
            Row(
              children: <Widget>[
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16.0),
                    child: TextField(
                      style: const TextStyle(fontSize: 15.0),
                      controller: textEditingController,
                      decoration: InputDecoration.collapsed(
                        hintText: isConnecting
                            ? 'Wait until connected...'
                            : isConnected
                                ? 'Type your message...'
                                : 'Chat got disconnected',
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                      enabled: isConnected,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon:
                        _speechEnabled ? Icon(Icons.mic) : Icon(Icons.mic_off),
                    onPressed: isConnected
                        ? () {
                            if (_speechEnabled) {
                              startListening();
                            }
                          }
                        : null,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: isConnected
                        ? () => _sendMessage(textEditingController.text)
                        : null,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Your existing methods _onDataReceived and _sendMessage remain unchanged
  // ...
}
