import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_ble/flutter_bluetooth_serial_ble.dart';
import './BackgroundCollectedPage.dart';
import './BackgroundCollectingTask.dart';
import './ChatPage.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  List<BluetoothDevice> _pairedDevices = [];
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();

    _getPairedDevices();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (state == BluetoothState.STATE_ON) {
          _getPairedDevices();
        }
      });
    });
  }

  Future<void> _getPairedDevices() async {
    final List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _pairedDevices = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bondhu App',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          Icon(
            Icons.bluetooth,
            color: Colors.white,
          ),
          Switch(
            value: _bluetoothState.isEnabled,
            onChanged: (bool value) {
              if (value) {
                FlutterBluetoothSerial.instance.requestEnable();
              } else {
                FlutterBluetoothSerial.instance.requestDisable();
              }
            },
            activeTrackColor: Colors.blue,
          ),
          SizedBox(width: 10),
        ],
      ),
      body: _bluetoothState.isEnabled
          ? Column(
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    itemCount: _pairedDevices.length,
                    itemBuilder: (context, index) {
                      final device = _pairedDevices[index];
                      return ListTile(
                        title: Text(
                          device.name ?? '',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          device.address ??
                              '', // You can display additional info like address
                          style: TextStyle(fontSize: 14),
                        ),
                        leading:
                            Icon(Icons.bluetooth_connected, color: Colors.blue),
                        trailing: Icon(Icons.arrow_forward),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return ChatPage(server: device);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                'TURN ON BLUETOOTH',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900], // Making text red in color
                ),
              ),
            ),
    );
  }
}
