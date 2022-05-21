import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';


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
