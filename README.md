# GKShare - Simple File Sharing App

GKShare is a lightweight, easy-to-use file sharing application that allows you to quickly share files between devices on the same network. Built with Flutter, it provides a modern and intuitive interface for file sharing.

## Features

- 🚀 **Quick File Sharing**: Share files instantly over your local network
- 📱 **Cross-Platform**: Works on Android and Linux
- 🔄 **Real-time Transfer**: Direct file transfer between devices
- 📱 **QR Code Support**: Easy connection via QR code scanning
- 📁 **Multiple File Support**: Share multiple files simultaneously
- 🎨 **Modern UI**: Clean and intuitive user interface
- 🔒 **Local Network Only**: Files stay within your local network for security

## Installation

### Linux (AppImage)

1. Download the latest GKShare AppImage from the releases page
2. Make the AppImage executable:
   ```bash
   chmod +x GKShare-*.AppImage
   ```
3. Run the application:
   ```bash
   ./GKShare-*.AppImage
   ```

### Android

1. Download the APK from the releases page
2. Install the APK on your Android device
3. Grant necessary permissions when prompted

## Usage

### Sharing Files

1. Launch GKShare on your device
2. Click "Start Server" to begin sharing
3. Select files using the "Select Files" button
4. Share the displayed URL or QR code with other devices on the same network
5. Recipients can access and download the files through their web browser

### Receiving Files

1. Ensure you're connected to the same network as the sender
2. Open the shared URL in your web browser or scan the QR code
3. Click on the files you want to download
4. Files will download to your device's default download location

## Permissions

### Android

- Storage access for reading and sharing files
- Network access for file transfer
- Camera access for QR code scanning (optional)

### Linux

- Network access for file transfer
- File system access for reading and sharing files

## Troubleshooting

### Common Issues

1. **Cannot connect to server**
   - Ensure both devices are on the same network
   - Check if any firewall is blocking the connection
   - Verify the server is running on the sender's device

2. **Files not showing up**
   - Check if the files were successfully selected
   - Verify file permissions
   - Try restarting the server

3. **Download issues**
   - Check available storage space
   - Verify network connection
   - Try using a different web browser

## Security Considerations

- GKShare operates only on your local network
- No files are uploaded to external servers
- All transfers are direct between devices
- Consider using a VPN for additional security on public networks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

If you encounter any issues or have questions, please:
1. Check the troubleshooting section
2. Open an issue on the GitHub repository
3. Contact the development team

---

Made with ❤️ for easy file sharing 