import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
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
import 'package:massage_o2o_app_repository_module/src/repository/nearby_user_repository.dart';
import 'package:uuid/uuid.dart';

import 'test_utils.dart';

Future<void> main() async {
  final String currentToken = "test_current_token";
  const String baseUrl = "http://192.168.0.130/api/";
  final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
  NearbyUserRepository nearbyUserRepository =
      HttpRedisNearByUserRepository(dio: dio);
  group('nearby master', () {
    test("get 10 range masters", () async {
      try {
        Either<NearbyUserError, List<MasterLocationModel>> result =
            await nearbyUserRepository.listNearbyMastersList(currentToken, 10);
        expect(result.isRight, isTrue);
        expect(result.isLeft, isFalse);
        expect(result.right.length, equals(10));
      } catch (e) {
        expect(e, isNull);
      }
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
