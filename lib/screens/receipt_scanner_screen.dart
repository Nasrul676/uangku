import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/receipt_parser.dart';
import '../models/parsed_receipt_item.dart';
import 'receipt_review_screen.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessing = false;
  String _statusMessage = 'Memilih gambar...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showImageSourceDialog();
    });
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Pilih Sumber Gambar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      _processImage(source);
    } else {
      Navigator.pop(context); // Go back if user cancelled
    }
  }

  /// Membuka cropper agar user bisa memotong bagian struk yang relevan.
  /// Mengembalikan path hasil crop, atau null jika user membatalkan.
  Future<String?> _cropImage(String imagePath) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Struk',
          toolbarColor: isDark ? const Color(0xFF1E1E2E) : theme.colorScheme.primary,
          toolbarWidgetColor: Colors.white,

          backgroundColor: isDark ? const Color(0xFF121212) : Colors.black,
          activeControlsWidgetColor: theme.colorScheme.primary,
          dimmedLayerColor: Colors.black54,
          cropFrameColor: theme.colorScheme.primary,
          cropGridColor: theme.colorScheme.primary.withAlpha(80),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Struk',
          doneButtonTitle: 'Selesai',
          cancelButtonTitle: 'Batal',
          resetAspectRatioEnabled: true,
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: true,
        ),
      ],
    );

    return croppedFile?.path;
  }

  Future<void> _processImage(ImageSource source) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Mengambil gambar...';
    });

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        if (mounted) Navigator.pop(context); // User cancelled picking
        return;
      }

      // Beri kesempatan user untuk crop area struk yang relevan
      setState(() {
        _isProcessing = false; // Sembunyikan loading saat cropper terbuka
        _statusMessage = 'Memotong gambar...';
      });

      final croppedPath = await _cropImage(image.path);
      if (croppedPath == null) {
        // User batal crop — kembali ke dialog pilih sumber gambar
        if (mounted) {
          _showImageSourceDialog();
        }
        return;
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Mengekstrak teks...';
      });

      final inputImage = InputImage.fromFilePath(croppedPath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _statusMessage = 'Menganalisis item...';
      });

      final List<ParsedReceiptItem> items = ReceiptParser.parse(recognizedText);

      if (!mounted) return;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada item atau harga yang terbaca dari struk.')),
        );
        Navigator.pop(context);
        return;
      }

      // Navigate to Review screen — gunakan croppedPath sebagai gambar preview
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptReviewScreen(
            items: items,
            imagePath: croppedPath,
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scan Struk'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: const TextStyle(fontSize: 16)),
                ],
              )
            : const SizedBox(),
      ),
    );
  }
}
