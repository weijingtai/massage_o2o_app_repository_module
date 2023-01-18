import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';

class OnlineUsersRepository {
  static Logger logger = Logger();
  static String ONLINE_MASTERS_COLLECTION_NAME = "OnlineMaster";
  static String ONLINE_HOSTS_COLLECTION_NAME = "OnlineHost";

  Future<List<OnlineHostUserModel>> loadOnlineHostByUidList(
      List<String> hostUidList) async {
    if (hostUidList.isEmpty) {
      logger.w("loadOnlineHostByUidList could not query emtpy uid list.");
      return Future.value(<OnlineHostUserModel>[]);
    }
    var allUids = hostUidList.toSet().toList();
    if (allUids.isEmpty) {
      logger.w("loadOnlineHostByUidList could not query emtpy uid list.");
      return Future.value(<OnlineHostUserModel>[]);
    }

    logger.i("fetchOnlineHost by uid list.");
    var remoteOnlineHostUserModelList = await fetchOnlineHost(allUids);
    if (remoteOnlineHostUserModelList.isEmpty) {
      logger.i("there are no host users online. for current user.");
      return Future.value(<OnlineHostUserModel>[]);
    }
    return remoteOnlineHostUserModelList;
  }

  Future<List<OnlineHostUserModel>> fetchOnlineHost(List<String> uids) async {
    var queryTimes = uids.length ~/ 10;
    if (uids.length % 10 != 0) {
      queryTimes++;
    }
    logger.d(
        "load total ${uids.length} hosts' uid. query with $queryTimes times.");
    List<DocumentSnapshot<Map<String, dynamic>>> allOnlineHostsSnapshotList;
    if (queryTimes == 1) {
      var futureQueryList = await FirebaseFirestore.instance
          .collection(ONLINE_HOSTS_COLLECTION_NAME)
          .where("uid", whereIn: uids)
          .get();
      logger.v(
          "collectionName $ONLINE_HOSTS_COLLECTION_NAME,futureQueryList ${futureQueryList.size}");
      allOnlineHostsSnapshotList =
          futureQueryList.docs.where((element) => element.exists).toList();
    } else {
      var futureQueryList = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < queryTimes; i++) {
        var queryUidList = <String>[];
        if (i == queryTimes - 1) {
          queryUidList = uids.sublist(i * 10);
        } else {
          queryUidList = uids.sublist(i * 10, (i + 1) * 10);
        }
        futureQueryList.add(FirebaseFirestore.instance
            .collection(ONLINE_HOSTS_COLLECTION_NAME)
            .where("uid", whereIn: queryUidList)
            .get());
      }
      var allQueryResultList = await Future.wait(futureQueryList);
      allOnlineHostsSnapshotList = allQueryResultList
          .expand((eachResult) => eachResult.docs)
          .where((snapshot) => snapshot.exists)
          .toList();
    }
    // foreach logging reuslt only when verbose logging.
    if (Logger.level == Level.verbose) {
      allOnlineHostsSnapshotList.forEach((snapshot) {
        logger.v("snapshot ${snapshot.data()}");
      });
    }
    logger
        .d("allOnlineHostsSnapshotList: ${allOnlineHostsSnapshotList.length}");
    return allOnlineHostsSnapshotList
        .where((e) => e.exists)
        .map((snapshot) => OnlineHostUserModel.fromJson(snapshot.data()!))
        .toList();
  }

  Future<List<OnlineMasterUserModel>> loadOnlineMastersByUidList(
      List<SubscribeUserModel> friendsList) async {
    Map<String, SubscribeUserModel> uidSubMapper =
        <String, SubscribeUserModel>{};
    friendsList.forEach((friend) {
      uidSubMapper[friend.uid] = friend;
    });

    logger.i("fetchOnlineMaster by uid list.");
    var remoteOnlineMasterUserModelList =
        await fetchOnlineMaster(uidSubMapper.keys.toList());
    if (remoteOnlineMasterUserModelList.isEmpty) {
      logger.i("there are no master users online. for current user.");
      return Future.value(<OnlineMasterUserModel>[]);
    }
    return remoteOnlineMasterUserModelList;
  }

  // Future<List<OnlineH>>
  Future<List<OnlineMasterUserModel>> fetchOnlineMaster(
      List<String> uids) async {
    logger.d("load total ${uids.length} friends' uid.");
    var queryTimes = uids.length ~/ 10;
    if (uids.length % 10 != 0) {
      queryTimes++;
    }
    logger.d(
        "load total ${uids.length} friends' uid. query with $queryTimes times.");
    List<DocumentSnapshot<Map<String, dynamic>>> allOnlineFriendsSnapshotList;
    if (queryTimes == 1) {
      var futureQueryList = await FirebaseFirestore.instance
          .collection(ONLINE_MASTERS_COLLECTION_NAME)
          .where("uid", whereIn: uids)
          .get();
      logger.v(
          "collectionName $ONLINE_MASTERS_COLLECTION_NAME,futureQueryList ${futureQueryList.size}");
      allOnlineFriendsSnapshotList =
          futureQueryList.docs.where((element) => element.exists).toList();
    } else {
      var futureQueryList = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < queryTimes; i++) {
        var queryUidList = <String>[];
        if (i == queryTimes - 1) {
          queryUidList = uids.sublist(i * 10);
        } else {
          queryUidList = uids.sublist(i * 10, (i + 1) * 10);
        }
        futureQueryList.add(FirebaseFirestore.instance
            .collection(ONLINE_MASTERS_COLLECTION_NAME)
            .where("uid", whereIn: queryUidList)
            .get());
      }
      var allQueryResultList = await Future.wait(futureQueryList);
      allOnlineFriendsSnapshotList = allQueryResultList
          .expand((eachResult) => eachResult.docs)
          .where((snapshot) => snapshot.exists)
          .toList();
    }
    // foreach logging reuslt only when verbose logging.
    if (Logger.level == Level.verbose) {
      allOnlineFriendsSnapshotList.forEach((snapshot) {
        logger.v("snapshot ${snapshot.data()}");
      });
    }
    logger.d(
        "allOnlineFriendsSnapshotList: ${allOnlineFriendsSnapshotList.length}");
    return allOnlineFriendsSnapshotList
        .where((e) => e.exists)
        .map((snapshot) => OnlineMasterUserModel.fromJson(snapshot.data()!))
        .toList();
  }
}
