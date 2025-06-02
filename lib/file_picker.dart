// file_picker.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

Future<dynamic> FilePick(BuildContext context) async {
  try {
    print('Opening file picker...');
    
    // First try to pick images
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      // If no images selected, try to pick any file
      print('No images selected, trying to pick any file...');
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
    }

    print('File picker result: $result');
    
    if (result != null && result.files.isNotEmpty) {
      print('Files selected: ${result.files.length}');
      for (var file in result.files) {
        print('Selected file: ${file.name}, size: ${file.size}, path: ${file.path}');
      }
    return result;
    } else {
      print('No files selected or selection cancelled');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files were selected'),
            duration: Duration(seconds: 2),
          ),
        );
    }
    return null;
    }
  } catch (e, stackTrace) {
    print('Error picking files: $e');
    print('Stack trace: $stackTrace');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return null;
  }
}
