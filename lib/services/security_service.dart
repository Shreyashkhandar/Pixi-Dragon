import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// adroid flag secure start here

class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.example.pixi_dragon/security');
  static int _secureScreenCount = 0;

  static Future<void> pushSecure() async {
    _secureScreenCount++;
    debugPrint('🔒 [SecurityService] pushSecure: Count = $_secureScreenCount');
    if (_secureScreenCount == 1) {
      try {
        await _channel.invokeMethod('setSecure', {'secure': true});
        debugPrint('🔒 [SecurityService] FLAG_SECURE Enabled');
      } on PlatformException catch (e) {
        debugPrint('⚠️ [SecurityService] Failed to enable FLAG_SECURE: $e');
      }
    }
  }

  static Future<void> popSecure() async {
    _secureScreenCount = max(0, _secureScreenCount - 1);
    debugPrint('🔒 [SecurityService] popSecure: Count = $_secureScreenCount');
    if (_secureScreenCount == 0) {
      try {
        await _channel.invokeMethod('setSecure', {'secure': false});
        debugPrint('🔓 [SecurityService] FLAG_SECURE Disabled');
      } on PlatformException catch (e) {
        debugPrint('⚠️ [SecurityService] Failed to disable FLAG_SECURE: $e');
      }
    }
  }
}

class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecurityService.pushSecure();
  }

  @override
  void dispose() {
    SecurityService.popSecure();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// android flag secure ends here
