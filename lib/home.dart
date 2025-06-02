import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gkshare/file_picker.dart';
import 'package:gkshare/server.dart';
import 'package:gkshare/network_info.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class Home extends StatefulWidget {
  final String? initialSharedText;
  
  const Home({super.key, this.initialSharedText});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final Server _server = Server();
  bool _isServerRunning = false;
  String _serverUrl = '';
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  List<PlatformFile> _selectedFiles = [];

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      print('Requesting Android permissions...');
      
      // For Android 13+ (API level 33+)
      if (Platform.operatingSystemVersion.contains('13')) {
        print('Android 13+ detected, requesting media permissions...');
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        
        print('Media permission statuses: $statuses');
        
        // If any permission is permanently denied, show settings dialog
        if (statuses.values.any((status) => status.isPermanentlyDenied)) {
          if (mounted) {
            bool? shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Permissions Required'),
                  content: const Text('This app needs access to your media files to share them. Please enable all permissions in settings.'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text('Open Settings'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              },
            );
            
            if (shouldOpenSettings == true) {
              await openAppSettings();
            }
          }
        }
      } else {
        // For Android 12 and below
        print('Android 12 or below detected, requesting storage permission...');
        PermissionStatus status = await Permission.storage.request();
        print('Storage permission status: $status');
        
        if (status.isPermanentlyDenied) {
          if (mounted) {
            bool? shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Storage Permission Required'),
                  content: const Text('This app needs access to your storage to share files. Please enable storage permission in settings.'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text('Open Settings'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              },
            );
            
            if (shouldOpenSettings == true) {
              await openAppSettings();
            }
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Request permissions when app starts
    _requestPermissions();

    // Handle shared files
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        for (var file in value) {
          _handleSharedFile(file.path);
        }
      }
    });

    // Handle shared files while app is running
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      for (var file in value) {
        _handleSharedFile(file.path);
      }
    }, onError: (err) {
      print("Error receiving shared file: $err");
    });

    // Handle shared text
    // ReceiveSharingIntent.getInitialText().then((String? value) {
    //   // TODO: Text sharing is not supported in receive_sharing_intent 1.8.1
    // });

    // Handle shared text while app is running
    // ReceiveSharingIntent.getTextStream().listen((String value) {
    //   // TODO: Text sharing is not supported in receive_sharing_intent 1.8.1
    // });
  }

  void _handleSharedFile(String filePath) {
    print('Handling shared file: $filePath');
    final file = File(filePath);
    print('File exists: ${file.existsSync()}');
    print('File size: ${file.lengthSync()}');
    print('File path: ${file.path}');
    print('File absolute path: ${file.absolute.path}');
    
    if (file.existsSync()) {
      try {
        // Check if file is readable
        try {
          final fileHandle = file.openSync(mode: FileMode.read);
          fileHandle.closeSync();
          print('File is readable');
        } catch (e) {
          print('File is not readable: $e');
          throw e;
        }
        
        // Get the file's mime type
        final extension = p.extension(filePath).toLowerCase();
        print('File extension: $extension');
        
        setState(() {
          _selectedFiles.add(PlatformFile(
            path: file.absolute.path,  // Use absolute path
            name: p.basename(filePath),
            size: file.lengthSync(),
          ));
        });
        print('Added file to _selectedFiles. Total files: ${_selectedFiles.length}');
        _server.setFiles(_selectedFiles);
        if (!_isServerRunning) {
          print('Starting server for shared file...');
          _startServer();
        }
      } catch (e, stackTrace) {
        print('Error handling shared file: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error handling shared file: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('Shared file does not exist at path: $filePath');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared file not found'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleSharedText(String text) {
    // Handle shared text if needed
    print('Received shared text: $text');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      final ipAddress = await NetworkInfo.getLocalIpAddress();
      final port = await _server.start();
      setState(() {
        _isServerRunning = true;
        _serverUrl = 'http://$ipAddress:$port';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start server: $e')),
      );
    }
  }

  Future<void> _stopServer() async {
    await _server.stop();
    setState(() {
      _isServerRunning = false;
      _serverUrl = '';
      _selectedFiles = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isServerRunning ? Icons.cloud_done : Icons.cloud_upload,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'GkShare',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                        if (_isServerRunning) ...[
                    // Server Status
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                            'Server Running',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // QR Code
                          QrImageView(
                            data: _serverUrl,
                            version: QrVersions.auto,
                            size: 180.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Scan to access files',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: SelectableText(
                                  _serverUrl,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _serverUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('URL copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                tooltip: 'Copy URL',
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 20),
                                onPressed: () {
                                  final url = _serverUrl.startsWith('http://') ? _serverUrl : 'http://$_serverUrl';
                                  Share.share(url);
                                },
                                tooltip: 'Share URL',
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                    // Selected Files List
                    if (_selectedFiles.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Files',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.2,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
                                  return Dismissible(
                                    key: Key('${file.name}_${index}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 16),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) {
                                      setState(() {
                                        _selectedFiles.removeAt(index);
                                        _server.setFiles(_selectedFiles);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${file.name} removed'),
                                          duration: const Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
                                              setState(() {
                                                _selectedFiles.insert(index, file);
                                                _server.setFiles(_selectedFiles);
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.insert_drive_file),
                                      title: Text(
                                        file.name,
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        _formatFileSize(file.size),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _selectedFiles.removeAt(index);
                                            _server.setFiles(_selectedFiles);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${file.name} removed'),
                                              duration: const Duration(seconds: 2),
                                              action: SnackBarAction(
                                                label: 'Undo',
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedFiles.insert(index, file);
                                                    _server.setFiles(_selectedFiles);
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              print('Starting file pick process...');
                              final result = await FilePick(context);
                              print('File pick result received: $result');
                              
                              if (result != null && result.files.isNotEmpty) {
                                print('Setting files in server: ${result.files.length} files');
                                setState(() {
                                  _selectedFiles = result.files;
                                });
                                _server.setFiles(result.files);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${result.files.length} file(s) selected successfully'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
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
                              }
                            } catch (e, stackTrace) {
                              print('Error in file picking button: $e');
                              print('Stack trace: $stackTrace');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error selecting files: $e'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Select Files'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                          ElevatedButton.icon(
                            onPressed: _stopServer,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop Server'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                        ),
                      ],
                          ),
                        ] else ...[
                    // Initial State
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.cloud_upload,
                              size: 100,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Ready to Share',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _startServer,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Server'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
                ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
