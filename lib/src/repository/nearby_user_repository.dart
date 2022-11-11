import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:either_dart/either.dart';

abstract class NearbyUserRepository {
  /// list nearby masters
  /// [currentToken] current user token
  /// [rangeLimit] limit range of available should be meters
  // Future<List<MasterLocationModel>> listNearbyMastersList(
  //     String currentUserToken, int rangeLimit);
  Future<Either<NearbyUserError, List<MasterLocationModel>>>
      listNearbyMastersList(String currentUserToken, int rangeLimit);
  Future<List<HostLocationModel>> listNearbyHostsList(
      String currentUserToken, int rangeLimit);
}

class HttpRedisNearByUserRepository extends NearbyUserRepository {
  final Logger logger = Logger();
  late Dio dio;

  HttpRedisNearByUserRepository({required this.dio}) : super();

  @override
  Future<List<HostLocationModel>> listNearbyHostsList(
      String currentUserToken, int rangeLimit) {
    throw UnimplementedError();
  }

  @override
  Future<Either<NearbyUserError, List<MasterLocationModel>>>
      listNearbyMastersList(String currentUserToken, int rangeLimit) async {
    final Response response =
        await dio.get("nearby/master?rangeLimit=$rangeLimit");
    if (response.statusCode == 200) {
      switch (response.data["code"]) {
        case 200:
          final resultData = response.data['data'];
          if (resultData == null) {
            logger.w("listNearbyMastersList: resultData is null.");
            return const Left(NearbyUserError.nullResult);
          }
          if (resultData is! List) {
            logger.w("listNearbyMastersList: resultData is not List.");
            logger.v(resultData);
            return const Left(NearbyUserError.unvalidatedResult);
          }
          if (resultData.isEmpty) {
            logger.w("listNearbyMastersList: resultData is empty.");
            return const Left(NearbyUserError.empty);
          }
          logger
              .d("listNearbyMastersList: total ${resultData.length} masters.");
          List<MasterLocationModel> result = resultData
              .map((each) => _convertToMasterLocationModel(each))
              .toList();
          logger.v(json.encode(result));
          return Right(result);
        case 204:
          logger.w("listNearbyMastersList there is no nearby masters found.");
          return const Left(NearbyUserError.empty);
        case 404:
          logger.w("listNearbyMastersList could not found uid in geo service.");
          return const Left(NearbyUserError.uidNotFound);
        default:
          logger.w(
              "listNearbyMastersList unknown error msg: ${response.data['msg']}.");
          return const Left(NearbyUserError.unknown);
      }
    } else if (response.statusCode == 404) {
      logger
          .w("listNearbyMastersList REQUEST error with code:404 no api found.");
      return const Left(NearbyUserError.tryAgainLater);
    } else if (response.statusCode == 403) {
      logger
          .w("listNearbyMastersList REQUEST error with code:403 unauthorized.");
      return const Left(NearbyUserError.authError);
    } else {
      logger.w(
          "listNearbyMastersList REQUEST error with code:${response.statusCode} msg:${response.statusMessage}.");
      return const Left(NearbyUserError.tryAgainLater);
    }
  }

  MasterLocationModel _convertToMasterLocationModel(Map<String, dynamic> data) {
    return MasterLocationModel(
        uid: data['uid'],
        coordinate: RedisCoordinate(
            latitude: data['coordinates']['lat'],
            longitude: data['coordinates']['lng'],
            rangeDistanceUnit: 'm',
            rangeDistance: data['rangeDistance'] * 1000,
            geohash: data['geohash']));
  }
}

enum NearbyUserError {
  empty,
  unknown,
  uidNotFound,

  nullResult,
  unvalidatedResult,

  authError,
  tryAgainLater,
}
