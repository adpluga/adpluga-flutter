import 'dart:io';

import 'package:adpluga_flutter/src/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// The version the SDK reports drives the server's minimum-version gate, so it
// must be the version that was published. It once stayed at 0.7.1 while the
// package shipped as 0.7.2.
void main() {
  test('kSdkVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(kSdkVersion, version);
  });
}
