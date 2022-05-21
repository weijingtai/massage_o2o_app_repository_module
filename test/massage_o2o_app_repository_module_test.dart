import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:massage_o2o_app_repository_module/massage_o2o_app_repository_module.dart';

Future<void> main() async {
  test('smoking test', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection("Service").doc("ok").set({
      'message': 'Hello world!',
      'created_at': FieldValue.serverTimestamp(),
    });
    var snap = await firestore.collection("Service").doc("ok").get();
    expect(snap.exists, true);
    expect(snap.data()!['message'], 'Hello world!');
  });
}
