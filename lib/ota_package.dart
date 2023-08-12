// ignore_for_file: annotate_overrides, avoid_print, prefer_const_constructors

/*
TODO: 
I suggest getting rid of methods that use external dependencies like http and file_picker.
The user can implement them himself, not limited to these libraries.
*/

/*
TODO: 
Add custom exceptions
*/

/*
TODO: 
Replace comments with documentation comments and remove and remove unnecessary ones
*/

/*
TODO: 
Replace "magic numbers" with constants
*/

/*
TODO: 
Write tests
*/

// Import necessary libraries
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/firmware_source.dart';

// Abstract class defining the structure of an OTA package
abstract class OtaPackage {
  // Method to update firmware
  Future<void> updateFirmware(
    BluetoothDevice device,
    FirmwareSource source,
    // TODO: Encapsulate FlutterBluePlus entities
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID,
  );

  // Property to track firmware update status
  //TODO: Replace with callback or state object
  bool firmwareupdate = false;

  // Stream to provide progress percentage
  //TODO: Replace with callback or state object
  Stream<int> get percentageStream;
}

// Class responsible for handling BLE repository operations
class BleRepository {
  // Write data to a Bluetooth characteristic
  Future<void> writeDataCharacteristic(
      BluetoothCharacteristic characteristic, Uint8List data) async {
    await characteristic.write(data);
  }

  // Read data from a Bluetooth characteristic
  Future<List<int>> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Request a specific MTU size from a Bluetooth device
  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }
}

// Implementation of OTA package for ESP32
class Esp32OtaPackage implements OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
  bool firmwareupdate = false;
  final StreamController<int> _percentageController =
      StreamController<int>.broadcast();
  @override
  Stream<int> get percentageStream => _percentageController.stream;

  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
  Future<void> updateFirmware(
    BluetoothDevice device,
    FirmwareSource source,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID,
  ) async {
    final bleRepo = BleRepository();

    // Get MTU size from the device
    int mtuSize = await device.mtu.first;

    // Prepare a byte list to write MTU size to controlCharacteristic
    Uint8List byteList = Uint8List(2);
    byteList[0] = mtuSize & 0xFF;
    byteList[1] = (mtuSize >> 8) & 0xFF;

    // Fetch chunks from firmware source
    List<Uint8List> binaryChunks = await source.getFirmwareChunks(mtuSize);

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);
    await bleRepo.writeDataCharacteristic(
        controlCharacteristic, Uint8List.fromList([1]));

    // Read value from controlCharacteristic
    List<int> value = await bleRepo
        .readCharacteristic(controlCharacteristic)
        .timeout(Duration(seconds: 10));
    print('value returned is this ------- ${value[0]}');

    int packageNumber = 0;
    for (Uint8List chunk in binaryChunks) {
      // Write firmware chunks to dataCharacteristic
      await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk);
      packageNumber++;

      double progress = (packageNumber / binaryChunks.length) * 100;
      int roundedProgress = progress.round(); // Rounded off progress value
      print(
          'Writing package number $packageNumber of ${binaryChunks.length} to ESP32');
      print('Progress: $roundedProgress%');
      _percentageController.add(roundedProgress);
    }

    // Write x04 to the controlCharacteristic to finish the update process
    await bleRepo.writeDataCharacteristic(
        controlCharacteristic, Uint8List.fromList([4]));

    // Check if controlCharacteristic reads 0x05, indicating OTA update finished
    value = await bleRepo
        .readCharacteristic(controlCharacteristic)
        .timeout(Duration(seconds: 600));
    print('value returned is this ------- ${value[0]}');

    if (value[0] == 5) {
      print('OTA update finished');
      firmwareupdate = true; // Firmware update was successful
    } else {
      print('OTA update failed');
      firmwareupdate = false; // Firmware update failed
    }
  }

  // TODO: Remove in future
  // Get firmware based on firmwareType
  Future<List<Uint8List>> getFirmware(FirmwareSource source, int mtuSize) {
    return source.getFirmwareChunks(mtuSize);
  }
}
