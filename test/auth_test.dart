import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/repository.dart';
import 'package:massage_o2o_app_repository_module/src/config/repository_config.dart';
import 'package:massage_o2o_app_repository_module/src/const_names.dart';
import 'package:uuid/uuid.dart';

import 'test_utils.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp app = await Firebase.initializeApp(
      name: 'test',
      options: const FirebaseOptions(
          apiKey: "AIzaSyChrR4o7EbNbgwHQvDj6m1l_o_V-ziJSwE",
          authDomain: "massage-o2o-dev.firebaseapp.com",
          databaseURL: "https://massage-o2o-dev-default-rtdb.firebaseio.com",
          projectId: "massage-o2o-dev",
          storageBucket: "massage-o2o-dev.appspot.com",
          messagingSenderId: "29898572537",
          appId: "1:29898572537:web:6fe86830dd91e9dd981828",
          measurementId: "G-0F4WQBS14X"));
  final FirebaseAuth firebaseAuth = FirebaseAuth.instanceFor(app: app);
  firebaseAuth.useAuthEmulator('192.168.0.10', 9099);
  final UserCredential userCredential = await firebaseAuth
      .signInWithEmailAndPassword(email: "wjt@wjt.io", password: "wjt19951215");
  expect(userCredential.user, isNotNull);
  final token = await userCredential.user?.getIdToken();
  group('somking', () {
    test("somking", () {
      expect(token, isNotNull);
    });
  });

  // FirebaseFirestore firebaseFirestore = FirebaseFirestore.instanceFor(app:app);
  // firebaseFirestore.useFirestoreEmulator("192.168.0.64", 8080);
  // var remoteAssignRepository = AssignRepository(firebaseFirestore);
  // WidgetsFlutterBinding.ensureInitialized();

  // var repositoryConfig = await loadRepositoryConfig();
  // final fakeFirestore = FakeFirebaseFirestore();
  // String ASSIGN_COLLECTION_NAME =
  //     repositoryConfig.assignRepositoryConfig.collectionName;
  // var testAssignRepository = AssignRepository(
  //     firestore: fakeFirestore, repositoryConfig: repositoryConfig);

  // group("test get", () {
  //   test("test get", () async {
  //     var assignModel = generateAssignModel();
  //     testAssignRepository.add(assignModel);
  //     var result = await testAssignRepository.get(assignModel.guid);
  //     expect(result, assignModel);
  //   });
  //   test("test get null", () async {
  //     var result = await testAssignRepository.get(Uuid().v4());
  //     expect(result, null);
  //   });
  // });
}
