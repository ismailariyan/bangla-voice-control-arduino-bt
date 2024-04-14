# voice_arduino
This project demonstrates how to use the `flutter_bluetooth_serial_ble` plugin to establish a Bluetooth connection between a Flutter application and an Arduino device. The application uses speech-to-text functionality to send voice commands to the Arduino device.

# Project Structure
The project is divided into two main parts:

1. The Flutter application, located in the lib/ directory.
2. The Arduino code, located in the arduino/ directory.
# Flutter Application
The Flutter application is responsible for establishing a Bluetooth connection with the Arduino device and sending voice commands. It uses the `flutter_bluetooth_serial_ble` plugin to handle Bluetooth functionality, and the `speech_to_text` plugin for speech recognition.

The main files in the Flutter application are:

- `BackgroundCollectedPage.dart`: This file handles the UI for the page that displays the collected data.
- `BackgroundCollectingTask.dart`: This file manages the task of collecting data in the background.
- `BluetoothDeviceListEntry.dart`: This file defines the UI for a list entry representing a Bluetooth device.

# Building the Project
To build the Flutter application, you can use the following command:
```
flutter build apk
```
To upload the Arduino code to your Arduino device, you can use the Arduino IDE and select the appropriate board and port.

## Running the Tests
To run the integration tests for the Flutter application, you can use the following command:
```
flutter test integration_test
```
## Dependencies
This project uses the following dependencies:

- flutter_bluetooth_serial_ble
- scoped_model
- cupertino_icons
- speech_to_text
- avatar_glow
Please refer to the `pubspec.yaml` file for more details.
