// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? connection;

  int? _deviceState;
  bool isDisconnecting = false;

  bool? get isConnected => connection?.isConnected;

  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral
    enableBluetooth();

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected != null) {
      isDisconnecting = true;
      connection?.dispose();
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<bool> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print('Error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devicesList = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Flutter Bluetooth'),
          backgroundColor: Colors.deepPurple,
          actions: <Widget>[
            ElevatedButton.icon(
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              onPressed: () async {
                await getPairedDevices().then((_) {
                  print('Device list refreshed');
                });
              },
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Visibility(
              visible: _isButtonUnavailable &&
                  _bluetoothState == BluetoothState.STATE_ON,
              child: const LinearProgressIndicator(
                backgroundColor: Colors.yellow,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Enable Bluetooth',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Switch(
                    value: _bluetoothState.isEnabled,
                    onChanged: (value) {
                      Future<void> future() async {
                        if (value) {
                          await FlutterBluetoothSerial.instance.requestEnable();
                        } else {
                          await FlutterBluetoothSerial.instance
                              .requestDisable();
                        }

                        await getPairedDevices();
                        _isButtonUnavailable = false;

                        if (_connected) {
                          _disconnect();
                        }
                      }

                      future().then((_) {
                        setState(() {});
                      });
                    },
                  )
                ],
              ),
            ),
            Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'PAIRED DEVICES',
                        style: TextStyle(fontSize: 24, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Device:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DropdownButton(
                            items: _getDeviceItems(),
                            onChanged: (value) => setState(
                              () => _device = value as BluetoothDevice,
                            ),
                            value: _devicesList.isNotEmpty ? _device : null,
                          ),
                          ElevatedButton(
                            onPressed: _isButtonUnavailable
                                ? null
                                : _connected
                                    ? _disconnect
                                    : _connect,
                            child: Text(_connected ? 'Disconnect' : 'Connect'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Card(
                            elevation: _deviceState == 0 ? 4 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'ROOMS ',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: _deviceState == 0
                                            ? Colors.blue
                                            : _deviceState == 1
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomOneMessageToBluetooth
                                          : null,
                                      child: const Text('ROOM 1'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomTwoMessageToBluetooth
                                          : null,
                                      child: const Text('ROOM 2'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomThreeMessageToBluetooth
                                          : null,
                                      child: const Text('ROOM 3'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            elevation: _deviceState == 0 ? 4 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'FAN SPEED',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: _deviceState == 0
                                            ? Colors.blue
                                            : _deviceState == 1
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomFanLowMessageToBluetooth
                                          : null,
                                      child: const Text('LOW'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomFanMidMessageToBluetooth
                                          : null,
                                      child: const Text('MID'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomFanHighMessageToBluetooth
                                          : null,
                                      child: const Text('HIGH'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomFanAutoMessageToBluetooth
                                          : null,
                                      child: const Text('AUTO'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            elevation: _deviceState == 0 ? 4 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'SECURITY SYSTEM',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: _deviceState == 0
                                            ? Colors.blue
                                            : _deviceState == 1
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomSecurityOnMessageToBluetooth
                                          : null,
                                      child: const Text('ON'),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: _connected
                                          ? _sendRoomSecurityOffMessageToBluetooth
                                          : null,
                                      child: const Text('OFF'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            elevation: _deviceState == 0 ? 4 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: const <Widget>[
                                  Expanded(
                                    child: Text(
                                      'TEMPERATURE',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      '5',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  color: Colors.blue,
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        'NOTE: If you cannot find the device in the list, please pair the device by going to the bluetooth settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        child: const Text('Bluetooth Settings'),
                        onPressed: () {
                          FlutterBluetoothSerial.instance.openSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    final List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(
        const DropdownMenuItem(
          child: Text('NONE'),
        ),
      );
    } else {
      for (final device in _devicesList) {
        items.add(
          DropdownMenuItem(
            value: device,
            child: Text(device.name.toString()),
          ),
        );
      }
    }
    return items;
  }

  Future<void> _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });

    await BluetoothConnection.toAddress(_device?.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        _connected = true;
      });
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
    setState(() => _isButtonUnavailable = false);
  }

  Future<void> _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection?.close();

    if (!connection!.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  Future<void> _sendRoomOneMessageToBluetooth() async {
    connection?.output.add(ascii.encode('1' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = 1; // device on
    });
  }

  Future<void> _sendRoomTwoMessageToBluetooth() async {
    connection?.output.add(ascii.encode('2' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = 1; // device on
    });
  }

  Future<void> _sendRoomThreeMessageToBluetooth() async {
    connection?.output.add(ascii.encode('3' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = 1; // device on
    });
  }

  Future<void> _sendRoomFanLowMessageToBluetooth() async {
    connection?.output.add(ascii.encode('4' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = -1; // device off
    });
  }

  Future<void> _sendRoomFanMidMessageToBluetooth() async {
    connection?.output.add(ascii.encode('5' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = -1; // device off
    });
  }

  Future<void> _sendRoomFanHighMessageToBluetooth() async {
    connection?.output.add(ascii.encode('6' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = -1; // device off
    });
  }

  Future<void> _sendRoomFanAutoMessageToBluetooth() async {
    connection?.output.add(ascii.encode('7' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = -1; // device off
    });
  }

  Future<void> _sendRoomSecurityOnMessageToBluetooth() async {
    connection?.output.add(ascii.encode('8' '\r\n'));
    await connection?.output.allSent;
  }

  Future<void> _sendRoomSecurityOffMessageToBluetooth() async {
    connection?.output.add(ascii.encode('9' '\r\n'));
    await connection?.output.allSent;

    setState(() {
      _deviceState = -1; // device off
    });
  }
}
