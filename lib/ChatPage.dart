import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

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

  void startListening() {
    _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'bn_BD',
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 5),
      onSoundLevelChange: soundLevelListener,
    );

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

    setState(() {});
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
              ? Text('Connecting to ' + serverName + '...')
              : isConnected
                  ? Text('Coonected with ' + serverName)
                  : Text('Disconnected ' + serverName))),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Flexible(
            //   child: ListView(
            //       padding: const EdgeInsets.all(12.0),
            //       controller: listScrollController,
            //       children: list),
            // ),
            Center(
              child: Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                        blurRadius: .5,
                        spreadRadius: level * 5,
                        color: Colors.blue.withOpacity(.05))
                  ],
                  color: Colors.white60,
                  borderRadius: const BorderRadius.all(Radius.circular(100)),
                ),
                child: IconButton(
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
                  iconSize: 80,
                ),
              ),
            ),
            Center(
              child: Text(
                isConnecting
                    ? 'Waiting for Connection...'
                    : isConnected
                        ? 'Tap the Mic'
                        : ' Disconnected',
                style: TextStyle(fontSize: 20),
              ),
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

    // // Create message if there is new line character
    // String dataString = String.fromCharCodes(buffer);
    // print('dataString: $dataString');
    // int index = buffer.indexOf(13);
    // if (~index != 0) {
    //   setState(() {
    //     messages.add(
    //       _Message(
    //         1,
    //         backspacesCounter > 0
    //             ? _messageBuffer.substring(
    //                 0, _messageBuffer.length - backspacesCounter)
    //             : _messageBuffer + dataString.substring(0, index),
    //       ),
    //     );
    //     _messageBuffer = dataString.substring(index);
    //   });
    // } else {
    //   _messageBuffer = (backspacesCounter > 0
    //       ? _messageBuffer.substring(
    //           0, _messageBuffer.length - backspacesCounter)
    //       : _messageBuffer + dataString);
    // }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    String textCommand = text;
// Define an array of Bengali phrases for each command group
    const LEDOnPhrases = [
      "সাদা বাতি জ্বালাও",
      "সাদা বাতি চালু কর",
      "সাদা বাতি চালু",
      "সাদা লাইট জ্বালাও",
      "সাদা লাইট চালু কর",
      "সাদা লাইট চালিয়ে দাও",
      "সাদা বাতি চালিয়ে দাও",
      "টার্ন অন এলইডি",
      "টার্ন অন এল ই ডি"
    ];
    const LEDOffPhrases = [
      "সাদা বাতি নিভাও",
      "সাদা বাতি বন্ধ",
      "সাদা বাতি বন্ধ কর",
      "সাদা লাইট নিভাও",
      "সাদা লাইট বন্ধ কর",
      "সাদা লাইট বন্ধ করো",
      "সাদা বাতি বন্ধ করো",
      "টার্ন অফ এলইডি",
      "টার্ন অফ এল ই ডি",
    ];
    const RGBOnPhrases = [
      "রঙিন বাতি জ্বালাও",
      "রঙিন বাতি চালু কর",
      "রঙিন বাতি চালু",
      "রঙিন লাইট জ্বালাও",
      "রঙিন লাইট চালু কর",
      "রঙিন লাইট চালিয়ে দাও",
      "রঙিন বাতি চালিয়ে দাও",
      "টার্ন অন আরজিবি",
      "টার্ন অন আর জি বি",
    ];
    const RGBOffPhrases = [
      "রঙিন বাতি নিভাও",
      "রঙিন বাতি বন্ধ কর",
      "রঙিন বাতি বন্ধ",
      "রঙ্গিন বাতি বন্ধ",
      "রঙিন লাইট নিভাও",
      "রঙিন লাইট বন্ধ কর",
      "রঙিন লাইট বন্ধ করো",
      "রঙিন বাতি বন্ধ করো",
      "টার্ন অফ আরজিবি",
      "টার্ন অফ আর জি বি",
    ];
    const fanOnPhrases = [
      "ফ্যান চালাও",
      "ফ্যান চালু",
      "পাখা চালাও",
      "পাখা চালু",
      "পাখা চালিয়ে দাও",
      "ফ্যান চালিয়ে দাও",
      "টার্ন অন ফ্যান",
    ];
    const fanOffPhrases = [
      "ফ্যান বন্ধ কর",
      "ফ্যান বন্ধ",
      "পাখা বন্ধ কর",
      "পাখা বন্ধ",
      "পাখা বন্ধ করো",
      "ফ্যান বন্ধ করো",
      "টার্ন অফ ফ্যান",
    ];
    const allOnPhrases = [
      "সব চালু",
      "সব চালু কর",
      "সব জ্বালাও",
      "সব চালাও",
      "সব চালিয়ে দাও",
      "সব চালিয়ে দাও",
      "টার্ন অন অল"
    ];
    const allOffPhrases = [
      "সব বন্ধ",
      "সব বন্ধ কর",
      "সব নিভাও",
      "সব বন্ধ করুন",
      "সব বন্ধ করো",
      "সব বন্ধ করোন",
      "টার্ন অফ অল",
      "টার্নও ফল"
    ];

// Check if textCommand matches any phrase in the array and assign the corresponding command
    if (LEDOnPhrases.contains(textCommand)) {
      textCommand = "turn on LED";
    } else if (LEDOffPhrases.contains(textCommand)) {
      textCommand = "turn off LED";
    } else if (RGBOnPhrases.contains(textCommand)) {
      textCommand = "turn on RGB";
    } else if (RGBOffPhrases.contains(textCommand)) {
      textCommand = "turn off RGB";
    } else if (fanOnPhrases.contains(textCommand)) {
      textCommand = "turn on fan";
    } else if (fanOffPhrases.contains(textCommand)) {
      textCommand = "turn off fan";
    } else if (allOnPhrases.contains(textCommand)) {
      textCommand = "turn on all";
    } else if (allOffPhrases.contains(textCommand)) {
      textCommand = "turn off all";
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
