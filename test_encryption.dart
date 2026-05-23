import 'dart:io';
import 'package:archive/archive.dart';

void main() async {
  final archive = Archive();
  archive.addFile(ArchiveFile('test.txt', 12, 'Hello World!'.codeUnits));
  final zipBytes = ZipEncoder(password: '123').encode(archive);
  
  try {
    ZipDecoder().decodeBytes(zipBytes!);
    print('Decoded without password! (no error)');
  } catch (e) {
    print('Error caught: $e');
  }
}
