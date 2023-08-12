// Firmware source abstract class
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

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
    const timeout = Duration(seconds: 10);
    late final Response response;

    // fetch and split into chunks
    try {
      response = await http.get(Uri.parse(url)).timeout(timeout);
    } catch (e) {
      // Handle other errors (e.g., timeout, network connectivity issues)
      throw 'Error fetching firmware from URL: $e';
    }

    // Handle HTTP error (e.g., status code is not 200)
    if (response.statusCode != 200) {
      throw 'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}';
    }

    final bytes = response.bodyBytes;

    return splitIntoChunks(bytes, mtuSize);
  }
}
