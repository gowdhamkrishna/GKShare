import 'dart:io';

Future<String> getIp() async { 
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 &&
          !addr.isLoopback &&
          !addr.address.startsWith('127.')) {
        return addr.address;
      }
    }
  }
  return 'Unknown';
}
