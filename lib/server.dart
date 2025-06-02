import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class Server {
  HttpServer? _server;
  List<PlatformFile> _files = [];
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<int> start() async {
    if (_isRunning) {
      throw Exception('Server is already running');
    }

    final address = InternetAddress.anyIPv4;
    _server = await HttpServer.bind(address, 0); // Use port 0 to get a random available port
    _isRunning = true;

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      
      if (path == '/') {
        request.response.headers.contentType = ContentType.html;
        final fileList = _files.map((file) => 
          '''
          <div class="file-item">
            <a href="/${file.name}" class="file-link">
              <span class="file-icon">📄</span>
              <span class="file-name">${file.name}</span>
              <span class="file-size">${_formatFileSize(file.size)}</span>
            </a>
          </div>
          '''
        ).join('');
        
        request.response.write('''
          <!DOCTYPE html>
          <html>
            <head>
              <title>GkShare - File Transfer</title>
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                  margin: 0;
                  padding: 20px;
                  background: #f5f5f5;
                  min-height: 100vh;
                }
                .container {
                  max-width: 800px;
                  margin: 0 auto;
                  background: white;
                  padding: 20px;
                  border-radius: 12px;
                  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 {
                  color: #333;
                  margin-bottom: 20px;
                  text-align: center;
                  font-size: 24px;
                }
                .file-item {
                  margin: 10px 0;
                  padding: 15px;
                  border-radius: 8px;
                  background: #f8f9fa;
                  transition: all 0.2s ease;
                  border: 1px solid #e9ecef;
                }
                .file-item:hover {
                  background: #e9ecef;
                  transform: translateY(-2px);
                  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
                }
                .file-link {
                  display: flex;
                  align-items: center;
                  text-decoration: none;
                  color: #333;
                  gap: 12px;
                }
                .shareT {
                  color: #2563eb;
                  font-size: 48px;
                  font-weight: 600;
                  text-align: center;
                  margin: 20px 0;
                  text-shadow: 1px 1px 2px rgba(0,0,0,0.1);
                }
                .file-icon {
                  font-size: 24px;
                  width: 40px;
                  height: 40px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  background: #e0e7ff;
                  border-radius: 8px;
                  color: #4f46e5;
                }
                .file-name {
                  flex: 1;
                  font-weight: 500;
                  font-size: 16px;
                }
                .file-size {
                  color: #666;
                  font-size: 0.9em;
                  margin-top: 4px;
                }
                @media (max-width: 600px) {
                  body {
                    padding: 10px;
                  }
                  .container {
                    padding: 15px;
                  }
                  .shareT {
                    font-size: 36px;
                  }
                  .file-item {
                    padding: 12px;
                  }
                }
              </style>
            </head>
            <body>
              <p class="shareT">GkShare</p>
              <div class="container">
                <h1>Available Files</h1>
                $fileList
              </div>
            </body>
          </html>
        ''');
        await request.response.close();
        return;
      }

      final requestedFile = _files.firstWhere(
        (file) => '/${file.name}' == path,
        orElse: () => throw Exception('File not found'),
      );

      try {
        print('Attempting to serve file: ${requestedFile.name}');
        print('File path: ${requestedFile.path}');
        print('File size: ${requestedFile.size}');
        
        final fileData = File(requestedFile.path!);
        if (!await fileData.exists()) {
          print('Error: File does not exist at path: ${requestedFile.path}');
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('File not found');
          await request.response.close();
          return;
        }

        // Check if we can read the file
        try {
          final fileSize = await fileData.length();
          print('File size from disk: $fileSize bytes');
          
          // Set content length header
          request.response.headers.contentLength = fileSize;
          
          // Set appropriate content type based on file extension
          final extension = p.extension(requestedFile.name).toLowerCase();
          String mimeType = 'application/octet-stream';
          
          switch (extension) {
            case '.jpg':
            case '.jpeg':
              mimeType = 'image/jpeg';
              break;
            case '.png':
              mimeType = 'image/png';
              break;
            case '.gif':
              mimeType = 'image/gif';
              break;
            case '.pdf':
              mimeType = 'application/pdf';
              break;
            case '.txt':
              mimeType = 'text/plain';
              break;
            // Add more mime types as needed
          }
          
          request.response.headers.contentType = ContentType.parse(mimeType);
          request.response.headers.add('Content-Disposition', 'attachment; filename="${requestedFile.name}"');
          
          print('Starting file stream...');
          print('Content-Type: ${request.response.headers.contentType}');
          print('Content-Length: ${request.response.headers.contentLength}');
          
          try {
            final stream = fileData.openRead();
            await request.response.addStream(stream);
            print('File stream completed successfully');
          } catch (e) {
            print('Error during file stream: $e');
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('Error streaming file: $e');
          }
        } catch (e) {
          print('Error reading file: $e');
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write('Cannot read file: $e');
        }
      } catch (e, stackTrace) {
        print('Error serving file: $e');
        print('Stack trace: $stackTrace');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error serving file: $e');
      } finally {
        await request.response.close();
      }
    });

    return _server!.port;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      throw Exception('Server is not running');
    }

    await _server?.close();
    _server = null;
    _isRunning = false;
  }

  void setFiles(List<PlatformFile> files) {
    print('Setting files in server:');
    for (var file in files) {
      print('File: ${file.name}, Path: ${file.path}, Size: ${file.size}');
    }
    _files = files;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
