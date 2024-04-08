import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
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
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult, localeId: 'bn_BD');
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      // Only process the final result
      setState(() {
        words = "${result.recognizedWords}";
      });
      // Once you have the recognized text, you may want to send it through the Bluetooth connection
      print(words);
      _sendMessage(words);
    }
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Row> list = messages.map((_message) {
      return Row(
        children: <Widget>[
          Container(
            child: Text(
                (text) {
                  return text == '/shrug' ? '¯\\_(ツ)_/¯' : text;
                }(_message.text.trim()),
                style: TextStyle(color: Colors.white)),
            padding: EdgeInsets.all(12.0),
            margin: EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
            width: 222.0,
            decoration: BoxDecoration(
                color:
                    _message.whom == clientID ? Colors.blueAccent : Colors.grey,
                borderRadius: BorderRadius.circular(7.0)),
          ),
        ],
        mainAxisAlignment: _message.whom == clientID
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
      );
    }).toList();

    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting chat to ' + serverName + '...')
              : isConnected
                  ? Text('Live with ' + serverName)
                  : Text('Command History ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              child: ListView(
                  padding: const EdgeInsets.all(12.0),
                  controller: listScrollController,
                  children: list),
            ),
            IconButton(
              icon: _speechToText.isListening
                  ? Icon(
                      Icons.mic,
                      color: Colors.blue,
                    )
                  : Icon(
                      Icons.mic_off,
                      color: Colors.grey,
                    ),
              onPressed: isConnected
                  ? () {
                      if (_speechEnabled) {
                        startListening();
                      }
                    }
                  : null,
              iconSize: 100,
            ),
            Text(
              isConnecting
                  ? 'সংযুক্ত হওয়ার জন্য অপেক্ষা করুন...'
                  : isConnected
                      ? 'কথা বলুন'
                      : ' সংযোগ বিচ্ছিন্ন',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(
              height: 20,
            )
          ],
        ),
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    String textCommand = text;
    if (textCommand == "সাদা বাতি জ্বালাও") {
      textCommand = "turn on LED";
    }
    if (textCommand == "সাদা বাতি নিভাও") {
      textCommand = "turn off LED";
    }
    if (textCommand == "রঙিন বাতি জ্বালাও") {
      textCommand = "turn on RGB";
    }
    if (textCommand == "রঙিন বাতি নিভাও") {
      textCommand = "turn off RGB";
    }
    if (textCommand == "ফ্যান চালাও") {
      textCommand = "turn on fan";
    }
    if (textCommand == "ফ্যান চালু") {
      textCommand = "turn on fan";
    }
    if (textCommand == "ফ্যান বন্ধ কর") {
      textCommand = "turn off fan";
    }
    if (textCommand == "ফ্যান বন্ধ") {
      textCommand = "turn off fan";
    }
    if (textCommand == "সব বন্ধ") {
      textCommand = "turn off all";
    }
    if (textCommand == "সব চালু") {
      textCommand = "turn on all";
    }if (textCommand == "সব বন্ধ কর") {
      textCommand = "turn off all";
    }
    if (textCommand == "সব চালু কর") {
      textCommand = "turn on all";
    }
    textCommand = textCommand.trim();

    if (textCommand.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(textCommand)));
        await connection!.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
