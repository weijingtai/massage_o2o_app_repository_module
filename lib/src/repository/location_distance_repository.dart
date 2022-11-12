import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:quiver/iterables.dart';

abstract class LocationDistanceRepository {
  Future<Either<LocationDistanceError, Map<String, DistanceModel>>>
      getAllDistance(Coordinate current, List<MasterLocationModel> others);
}

class HttpLocationDistanceRepository extends LocationDistanceRepository {
  int maxPointsEachRequest = 9;
  final Logger logger = Logger();
  late Dio dio;

  HttpLocationDistanceRepository(
      {required this.dio, required this.maxPointsEachRequest})
      : super();
  @override
  Future<Either<LocationDistanceError, Map<String, DistanceModel>>>
      getAllDistance(
          Coordinate current, List<MasterLocationModel> others) async {
    if (others.isEmpty) {
      return const Left(LocationDistanceError.empty);
    }

    // check others lenght should lower than maxPointsEachRequest
    // otherwise split into multiple requests
    Map<String, DistanceModel> result = {};
    logger.d("getAllDistance request point is ${others.length}");
    if (others.length > maxPointsEachRequest) {
      var lists = partition(others, maxPointsEachRequest);
      var allResult =
          await Future.wait(lists.map((each) => _makeRequest(current, each)));

      // convert multiple result to single list
      allResult.where((e) => e.isRight).map((e) => e.right).forEach((e) {
        logger.v(jsonEncode(e));
        result.addAll(e);
      });
    } else {
      var requestResult = await _makeRequest(current, others);
      if (requestResult.isRight) {
        result = requestResult.right;
      } else {
        return requestResult;
      }
    }
    logger.i("getAllDistance: total ${result.length} result.");
    logger.v(json.encode(result));
    return Right(result);
  }

  Future<Either<LocationDistanceError, Map<String, DistanceModel>>>
      _makeRequest(Coordinate current, List<MasterLocationModel> others) async {
    // convert to mapper
    Map<String, MasterLocationModel> mapper = {for (var v in others) v.uid: v};
    // convert MasterLocationModel to Map<String, dynamic>
    final List<Map<String, dynamic>> othersMap = others
        .map((e) => {
              "uid": e.uid,
              "lat": e.coordinate.latitude,
              "lng": e.coordinate.longitude,
            })
        .toList();
    var resultMap = <String, DistanceModel>{};
    try {
      var requestJsonBody = jsonEncode({
        "current": {"lat": current.latitude, "lng": current.longitude},
        "others": othersMap
      });
      logger.v(requestJsonBody);
      final Response response = await dio.post("distance",
          options: Options(headers: {
            HttpHeaders.contentTypeHeader: "application/json",
          }),
          data: requestJsonBody);
      if (response.statusCode == 200) {
        switch (response.data["code"]) {
          case 200:
            var now = DateTime.now();
            final resultData = response.data['data'];
            if (resultData == null) {
              logger.w("_makeRequest: resultData is null.");
              return const Left(LocationDistanceError.nullResult);
            }
            if (resultData is! List) {
              logger.w("_makeRequest: resultData is not List.");
              logger.v(resultData);
              return const Left(LocationDistanceError.unvalidatedResult);
            }
            if (resultData.isEmpty) {
              logger.w("_makeRequest: resultData is empty.");
              return const Left(LocationDistanceError.empty);
            }
            logger.d("_makeRequest: total ${resultData.length} masters.");
            // setup result list
            for (var each in resultData) {
              MasterLocationModel master = mapper[each['uid']]!;
              double? rangeDistance;
              String? rangeDistanceUnit;

              if (master.coordinate is RedisCoordinate) {
                RedisCoordinate redisCoordinate =
                    master.coordinate as RedisCoordinate;
                rangeDistance = redisCoordinate.rangeDistance;
                rangeDistanceUnit = redisCoordinate.rangeDistanceUnit;
              }

              resultMap[each['uid']] = DistanceModel(master.coordinate,
                  rangeDistance: rangeDistance,
                  rangeDistanceUnit: rangeDistanceUnit,
                  travelDistance: each['distance'],
                  travelDistanceUnit: each['distanceUnit'],
                  elapsedTime: each['duration'],
                  elapsedTimeUnit: each['elapsedTimeUnit'],
                  calculateAt: now);
            }
            logger.v(json.encode(resultMap));
            return Right(resultMap);
          case 204:
            logger.w("_makeRequest: no result.");
            return const Left(LocationDistanceError.empty);
          default:
            logger.w("_makeRequest: unknown error.");
            logger.v(response.data);
            return const Left(LocationDistanceError.unknown);
        }
      } else if (response.statusCode == 404) {
        logger.w(
            "listNearbyMastersList REQUEST error with code:404 no api found.");
        return const Left(LocationDistanceError.tryAgainLater);
      } else if (response.statusCode == 403) {
        logger.w(
            "listNearbyMastersList REQUEST error with code:403 unauthorized.");
        return const Left(LocationDistanceError.authError);
      } else {
        logger.w(
            "listNearbyMastersList REQUEST error with code:${response.statusCode} msg:${response.statusMessage}.");
        return const Left(LocationDistanceError.tryAgainLater);
      }
    } catch (e) {
      return const Left(LocationDistanceError.tryAgainLater);
    }
  }
}

enum LocationDistanceError {
  empty,
  unknown,
  uidNotFound,

  nullResult,
  unvalidatedResult,

  authError,
  tryAgainLater,
}
