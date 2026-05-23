import 'dart:io';
import 'package:archive/archive.dart';

Future<bool> isZipEncrypted(File zipFile) async {
  try {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.isNotEmpty) {
      final _ = archive.files.first.content;
    }
    return false;
  } catch (e) {
    print('Exception caught: $e');
    return true;
  }
}

void main() async {
  final archive = Archive();
  archive.addFile(ArchiveFile('test.txt', 12, 'Hello World!'.codeUnits));
  final zipBytes = ZipEncoder(password: '123').encode(archive);
  
  File('test_enc.zip').writeAsBytesSync(zipBytes!);
  
  bool enc = await isZipEncrypted(File('test_enc.zip'));
  print('Encrypted: $enc');
}
