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
import 'package:massage_o2o_app_repository_module/src/repository/location_distance_repository.dart';
import 'package:massage_o2o_app_repository_module/src/repository/nearby_user_repository.dart';
import 'package:uuid/uuid.dart';

import 'test_utils.dart';

Future<void> main() async {
  final String currentToken = "test_current_token";
  const String baseUrl = "http://192.168.0.130/api/";
  final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
  LocationDistanceRepository locationDistanceRepository =
      HttpLocationDistanceRepository(dio: dio, maxPointsEachRequest: 9);
  String queryJsonStr =
      "[{\"coordinate\":{\"latitude\":36.14030395988896,\"longitude\":-115.20121246576309,\"coordinateType\":\"redis\",\"geohash\":1367523531900294,\"rangeDistance\":1855.8,\"rangeDistanceUnit\":\"m\"},\"uid\":\"vwA1k8oua2poSxelYCopCq1Zdp4z\"},{\"coordinate\":{\"latitude\":36.16953436429846,\"longitude\":-115.21605581045151,\"coordinateType\":\"redis\",\"geohash\":1367523584397276,\"rangeDistance\":5365.400000000001,\"rangeDistanceUnit\":\"m\"},\"uid\":\"8miEZ7U29Qc17sqx9x9NW47943Uy\"},{\"coordinate\":{\"latitude\":36.156903848761466,\"longitude\":-115.14468759298325,\"coordinateType\":\"redis\",\"geohash\":1367523740686877,\"rangeDistance\":5788.0,\"rangeDistanceUnit\":\"m\"},\"uid\":\"NDuCQPami4UlqUGvMjl0Vi1tp7NB\"},{\"coordinate\":{\"latitude\":36.12010730169134,\"longitude\":-115.26330024003983,\"coordinateType\":\"redis\",\"geohash\":1367522369266446,\"rangeDistance\":6154.8,\"rangeDistanceUnit\":\"m\"},\"uid\":\"eeuNyv03nHAN00dEeK7pstPpXeZa\"},{\"coordinate\":{\"latitude\":36.145059096783875,\"longitude\":-115.1251557469368,\"coordinateType\":\"redis\",\"geohash\":1367525129791646,\"rangeDistance\":6682.0,\"rangeDistanceUnit\":\"m\"},\"uid\":\"MU2wo2mJLwcklpwEaFsqYWpdpp0l\"},{\"coordinate\":{\"latitude\":36.18091779702505,\"longitude\":-115.16037315130234,\"coordinateType\":\"redis\",\"geohash\":1367523911839849,\"rangeDistance\":7014.3,\"rangeDistanceUnit\":\"m\"},\"uid\":\"iRVFEcszRidRsLSlhKQwZPSMgvSr\"},{\"coordinate\":{\"latitude\":36.09953803948331,\"longitude\":-115.11080592870712,\"coordinateType\":\"redis\",\"geohash\":1367524348851197,\"rangeDistance\":8054.6,\"rangeDistanceUnit\":\"m\"},\"uid\":\"k6VydH6Zl1tTZNhvnWu2SiQPWRp2\"},{\"coordinate\":{\"latitude\":36.171673668956934,\"longitude\":-115.12393802404404,\"coordinateType\":\"redis\",\"geohash\":1367525380202732,\"rangeDistance\":8270.0,\"rangeDistanceUnit\":\"m\"},\"uid\":\"d5qKEywcPsEUCwIn988zjD28T48p\"},{\"coordinate\":{\"latitude\":36.053020836767125,\"longitude\":-115.23863464593887,\"coordinateType\":\"redis\",\"geohash\":1367522056316119,\"rangeDistance\":8854.2,\"rangeDistanceUnit\":\"m\"},\"uid\":\"5ygQAAibms6RDjR0Dbt8VQMGXxjt\"},{\"coordinate\":{\"latitude\":36.17349866819166,\"longitude\":-115.27481228113174,\"coordinateType\":\"redis\",\"geohash\":1367523267083078,\"rangeDistance\":9012.1,\"rangeDistanceUnit\":\"m\"},\"uid\":\"0aavxtXDiDc0aXqfVAQFT6fcgoP2\"}]";
  List<MasterLocationModel> allRequestList = [];
  jsonDecode(queryJsonStr).forEach((element) {
    var elementMap = element as Map<String, dynamic>;
    var coordinateJson = elementMap["coordinate"] as Map<String, dynamic>;
    allRequestList.add(MasterLocationModel(
        uid: elementMap["uid"],
        coordinate: RedisCoordinate.fromJson(coordinateJson)));
  });

  var current = Coordinate(
      latitude: 36.12439098045063446, longitude: -115.19500046968460083);

  group('distance master', () {
    test("get 2 master poistion", () async {
      try {
        var first9 = allRequestList.getRange(0, 2);
        expect(first9.length, 2);

        Either<LocationDistanceError, Map<String, DistanceModel>> result =
            await locationDistanceRepository.getAllDistance(
                current, first9.toList());
        expect(result.isRight, isTrue);
        expect(result.isLeft, isFalse);
        expect(result.right.length, equals(2));
      } catch (e) {
        print(e);
        // expect(e, isNull);
      }
    });
    test("get 9 master poistion", () async {
      try {
        var first9 = allRequestList.getRange(0, 9);
        expect(first9.length, 9);

        Either<LocationDistanceError, Map<String, DistanceModel>> result =
            await locationDistanceRepository.getAllDistance(
                current, first9.toList());
        expect(result.isRight, isTrue);
        expect(result.isLeft, isFalse);
        expect(result.right.length, equals(9));
      } catch (e) {
        print(e);
        // expect(e, isNull);
      }
    });
    test("get 10 master poistion", () async {
      try {
        Either<LocationDistanceError, Map<String, DistanceModel>> result =
            await locationDistanceRepository.getAllDistance(
                current, allRequestList.toList());
        expect(result.isRight, isTrue);
        expect(result.isLeft, isFalse);
        expect(result.right.length, equals(10));
      } catch (e) {
        print(e);
        // expect(e, isNull);
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
