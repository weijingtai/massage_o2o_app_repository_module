import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';

class FriendsRepository {
  static Logger logger = Logger();
  Future<List<SubscribeUserModel>> loadByLoggedInUserUid(String loggedInUid,
      {bool withHostUser = false}) async {
    var roleFilter = ["MASTER"];
    if (withHostUser) {
      roleFilter.add("HOST");
    }
    var allResult = await Future.wait([
      FirebaseFirestore.instance
          .collection("Subscribe")
          .doc(loggedInUid)
          .collection("FollowedList")
          .where("baseInfo.role", whereIn: roleFilter)
          .get(),
      FirebaseFirestore.instance
          .collection("Subscribe")
          .doc(loggedInUid)
          .collection("FollowerList")
          .where("baseInfo.role", whereIn: roleFilter)
          .get(),
    ]);
    var followedListSnapshot = allResult[0];
    var followerListSnapshot = allResult[1];

    var followedSet = <SubscribeUserModel>{};
    var followerSet = <SubscribeUserModel>{};
    if (followedListSnapshot.size > 0) {
      logger.d("user's followedSet with total ${followedListSnapshot.size}.");
      followedSet = followedListSnapshot.docs
          .where((e) => e.exists)
          .map((e) => SubscribeUserModel.fromJson(e.data()["baseInfo"])
            ..subscribeStateEnum = SubscribeStateEnum.IS_FOLLOWED)
          .toSet();
    } else {
      logger.d("user's followedSet is empty.");
    }
    if (followerListSnapshot.size > 0) {
      followerSet = followerListSnapshot.docs.where((e) => e.exists).map((e) {
        logger.v("${e.data()}");
        return SubscribeUserModel.fromJson(e.data()["baseInfo"])
          ..subscribeStateEnum = SubscribeStateEnum.IS_FOLLOWER;
      }).toSet();
    } else {
      logger.d("user's followerSet is empty.");
    }
    var resultSubscribeUserModelSet = <SubscribeUserModel>{};
    if (followerSet.isNotEmpty && followedSet.isNotEmpty) {
      logger.d(
          "both followerSet and followerSet is not empty. handle BI_FOLLOW.");
      var intersectionSet = getIntersectionSet(followerSet, followedSet);
      logger.d("BI_FOLLOW total ${intersectionSet.length}.");
      logger.v("update subscribeUserModel's subscribeStateEnum to BI_FOLLOW.");
      resultSubscribeUserModelSet = intersectionSet
          .map((e) => e..subscribeStateEnum = SubscribeStateEnum.BI_FOLLOW)
          .toSet();
      // var onlyFollowedSet = getDifferenceSet(followedSet, intersectionSet);
      // var onlyFollowerSet = getDifferenceSet(followerSet, intersectionSet);
      logger.d("union subscribeUser in followerList to result.");
      resultSubscribeUserModelSet.union(followerSet);
      logger.d("union subscribeUser in followedList to result.");
      resultSubscribeUserModelSet.union(followedSet);
    } else if (followerSet.isNotEmpty) {
      logger.d("only has followerSet.");
      resultSubscribeUserModelSet = followerSet;
    } else if (followedSet.isNotEmpty) {
      logger.d("only has followedSet.");
      resultSubscribeUserModelSet = followedSet;
    }

    return resultSubscribeUserModelSet.toList();
  }

  Future<List<String>> loadAllFriendsUid(String loggedInUid,
      {bool withHostUser = false}) async {
    var allFriends =
        await loadByLoggedInUserUid(loggedInUid, withHostUser: withHostUser);
    return allFriends.map((e) => e.uid).toSet().toList();
  }

  Set<SubscribeUserModel> getIntersectionSet(
      Set<SubscribeUserModel> first, Set<SubscribeUserModel> second) {
    return first.intersection(second);
  }

  Set<SubscribeUserModel> getDifferenceSet(
      Set<SubscribeUserModel> first, Set<SubscribeUserModel> second) {
    return first.difference(second);
  }
  // Future<FriendsListState> searchUserBy(String searchContent) async {
  //   if (userDataList.isEmpty){
  //     return EmptyFriendsListState();
  //   }else{
  //     if (searchContent.isEmpty){
  //       return SearchFriendsListSuccessState(searchContent,userDataList);
  //     } else{
  //       var searchContentUpper = searchContent.toUpperCase();
  //       // users.takeWhile((value) => false)
  //       var resultList = userDataList
  //           .where((user){
  //         if (user.subscribeUserModel.alphabetName.toUpperCase().contains(searchContentUpper)){
  //           return true;
  //         }
  //         var remarkAlphabetName = user.subscribeUserModel.remarkAlphabetName;
  //         if (remarkAlphabetName != null &&remarkAlphabetName.isNotEmpty && remarkAlphabetName.toUpperCase().contains(searchContentUpper)){
  //           return true;
  //         }
  //         if (user.subscribeUserModel.displayName.toUpperCase().contains(searchContentUpper)){
  //           return true;
  //         }
  //         if (user.subscribeUserModel.remarkName != null && user.subscribeUserModel.remarkName!.toUpperCase().contains(searchContentUpper)){
  //           return true;
  //         }
  //         return false;
  //       }).toList();
  //
  //       if (resultList.isEmpty){
  //         logger.i("not found user by search content ${searchContentUpper}");
  //         return SearchFriendsListEmptyState(searchContent);
  //       }else{
  //         logger.i("found \"${resultList.length}\" user by search content ${searchContentUpper}");
  //         return SearchFriendsListSuccessState(searchContentUpper,resultList);
  //       }
  //     }
  //   }
  // }

}
