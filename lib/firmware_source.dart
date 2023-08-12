// Firmware source abstract class
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'other.dart';

abstract class FirmwareSource {
  const FirmwareSource();

  Future<List<Uint8List>> getFirmwareChunks(int mtuSize);
}

// Concrete firmware sources

class FileFirmwareSource extends FirmwareSource {
  final String filePath;

  const FileFirmwareSource(this.filePath);

  @override
  Future<List<Uint8List>> getFirmwareChunks(int mtuSize) async {
    // read file and split into chunks
    final fileBytes = await File(filePath).readAsBytes();

    return splitIntoChunks(fileBytes, mtuSize);
  }
}

class UrlFirmwareSource extends FirmwareSource {
  final String url;

  const UrlFirmwareSource(this.url);

  @override
  Future<List<Uint8List>> getFirmwareChunks(int mtuSize) async {
    // fetch and split into chunks
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;

    return splitIntoChunks(bytes, mtuSize);
  }
}
