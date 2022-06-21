
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/config.dart';
import 'package:quiver/iterables.dart';

class UserRepository{
  // logger
  static Logger logger = Logger();

  CollectionReference<Map<String, dynamic>> _userCollection = FirebaseFirestore.instance.collection('Users');
  RepositoryConfig repositoryConfig;
  UserRepository({required this.repositoryConfig});

  Future<UserModel?> getUserByUid(String uid) async {
    logger.i("UserRepository#getUserByUid: uid: $uid");
    var snap = await _userCollection.doc(uid).get();
    // when snap is not exists return null
    // otherwise get role from data,
    // when role is 'MASTER' create MasterUserModel and return it
    // when role is 'HOST' create HostUserModel and return it

    if(snap.exists){
      var role = (snap.data()!['role'] as String).toUpperCase();
      logger.d("UserRepository#getUserByUid: role: $role");
      if(role == 'MASTER'){
        return MasterUserModel.fromJson(snap.data()!);
      }else if(role == 'HOST'){
        return HostUserModel.fromJson(snap.data()!);
      }
    }
    logger.w("UserRepository#getUserByUid: User with uid: $uid not found");
    return null;
  }
  Future<List<UserModel>> getAllUserByUids(List<String> uids) async {
    logger.i("UserRepository#getAllUserByUids: uids: $uids");
    // check if uids is empty
    if(uids.isEmpty){
      logger.w("UserRepository#getAllUserByUids: uids is empty");
      return [];
    }
    logger.v(uids);
    // if uids.length greater than repository InWhereLimit,
    // split uids into multiple list and get host user from each list
    if(uids.length > repositoryConfig.whereInLimit) {
      logger.d(
          "getAllUserByUids: uids.length greater than repository InWhereLimit.");
      Iterable<List<String>> partintionUids = partition(uids, repositoryConfig.whereInLimit);
      var queryFutureList = partintionUids.map((e) => _userCollection.where("uid",whereIn: e).get());
      var querySnapList = await Future.wait(queryFutureList);
      var allUser = querySnapList.map((e) => e.docs
          .where((doc) => doc.exists)
          .map((doc)=> doc.data())
          .map((doc){
            if (doc['role'] == 'MASTER') {
              return MasterUserModel.fromJson(doc);
              // } else if (doc['role'] == 'HOST') {
            }
            else {
              return HostUserModel.fromJson(doc);
            }
          }))
          .expand((e) => e).toList();
      logger.d("getAllUserByUids: uids.length with total: ${allUser.length} result found.");
      return allUser;
    }
    else{
      var querySnapshot = await _userCollection.where("uid",whereIn: uids).get();
      if (querySnapshot.size < 1){
        logger.d("getAllUserByUids: uids.length with empty result found.");
        return [];
      }else{
        var allHostUser = querySnapshot.docs
            .where((doc) => doc.exists)
            .map((doc)=> doc.data())
            .map((doc){
          if (doc['role'] == 'MASTER') {
            return MasterUserModel.fromJson(doc);
            // } else if (doc['role'] == 'HOST') {
          }
          else {
            return HostUserModel.fromJson(doc);
          }
            })
            .toList();
        logger.d("getAllUserByUids: uids.length with total: ${allHostUser.length} result found.");
        return allHostUser;

      }

    }

  }
  Future<MasterUserModel?> getMasterUser(String uid) async {
    logger.i("UserRepository#getMasterUser: uid: $uid");
    var snap = await _userCollection.doc(uid)
        .get();
    // when snap is not exists return null
    // otherwise get role from data,
    // when role is 'MASTER' create MasterUserModel and return it
    // when role is 'HOST' create HostUserModel and return it

    if(snap.exists){
      var role = (snap.data()!['role'] as String).toUpperCase();
      if(role == 'MASTER'){
        logger.v(snap.data()!);
        return MasterUserModel.fromJson(snap.data()!);
      }else{
        logger.w("UserRepository#getMasterUser: uid: $uid is not a MASTER role.");
      }
    }
    logger.w("UserRepository#getMasterUser: User with uid: $uid not found");
    return null;
  }
  Future<List<MasterUserModel>> getAllMasterUser(List<String> uids) async{
    logger.i("UserRepository#getAllMasterUser: uids: $uids");
    // check if uids is empty
    if(uids.isEmpty){
      logger.w("UserRepository#getAllMasterUser: uids is empty");
      return [];
    }
    logger.v(uids);
    // if uids.length greater than repository InWhereLimit,
    // split uids into multiple list and get host user from each list
    if(uids.length > repositoryConfig.whereInLimit) {
      logger.d(
          "getAllMasterUser: uids.length greater than repository InWhereLimit.");
      Iterable<List<String>> partintionUids = partition(uids, repositoryConfig.whereInLimit);
      var queryFutureList = partintionUids.map((e) => _userCollection.where("role",isEqualTo:"MASTER").where("uid",whereIn: e).get());
      var querySnapList = await Future.wait(queryFutureList);
      var allHostUser = querySnapList.map((e) => e.docs.where((doc) => doc.exists).map((doc) => MasterUserModel.fromJson(doc.data()))).expand((e) => e).toList();
      logger.d("getAllMasterUser: uids.length with total: ${allHostUser.length} result found.");
      return allHostUser;
    }
    else{
      var querySnapshot = await _userCollection.where("role",isEqualTo:"MASTER").where("uid",whereIn: uids).get();
      if (querySnapshot.size < 1){
        logger.d("getAllMasterUser: uids.length with empty result found.");
        return [];
      }else{
        var allHostUser = querySnapshot.docs.where((doc) => doc.exists).map((doc) => MasterUserModel.fromJson(doc.data())).toList();
        logger.d("getAllMasterUser: uids.length with total: ${allHostUser.length} result found.");
        return allHostUser;

      }

    }

  }
  Future<HostUserModel?> getHostUser(String uid) async {
    logger.i("UserRepository#getHostUser: uid: $uid");
    var snap = await _userCollection.doc(uid)
        .get();
    // when snap is not exists return null
    // otherwise get role from data,
    // when role is 'MASTER' create MasterUserModel and return it
    // when role is 'HOST' create HostUserModel and return it

    if(snap.exists){
      var role = (snap.data()!['role'] as String).toUpperCase();
      if(role == 'HOST'){
        logger.v(snap.data()!);
        return HostUserModel.fromJson(snap.data()!);
      }else{
        logger.w("UserRepository#getMasterUser: uid: $uid is not a MASTER role.");
      }
    }
    logger.w("UserRepository#getMasterUser: User with uid: $uid not found");
    return null;
  }
  Future<List<HostUserModel>> getAllHostUser(List<String> uids) async{
    // get all host user from uids list
    logger.i("getAllHostUser: with total: ${uids.length}.");
    // check if uids is empty
    if(uids.isEmpty){
      logger.w("getAllHostUser: uids is empty.");
      return [];
    }
    logger.v(uids);
    // if uids.length greater than repository InWhereLimit,
    // split uids into multiple list and get host user from each list
    if(uids.length > repositoryConfig.whereInLimit) {
      logger.d(
          "getAllHostUser: uids.length greater than repository InWhereLimit.");
      Iterable<List<String>> partintionUids = partition(uids, repositoryConfig.whereInLimit);
      var queryFutureList = partintionUids.map((e) => _userCollection.where("role",isEqualTo:"HOST").where("uid",whereIn: e).get());
      var querySnapList = await Future.wait(queryFutureList);
      var allHostUser = querySnapList.map((e) => e.docs.where((doc) => doc.exists).map((doc) => HostUserModel.fromJson(doc.data()))).expand((e) => e).toList();
      logger.d("getAllHostUser: uids.length with total: ${allHostUser.length} result found.");
      return allHostUser;
    }
    else{
      var querySnapshot = await _userCollection.where("role",isEqualTo:"HOST").where("uid",whereIn: uids).get();
      if (querySnapshot.size < 1){
        logger.d("getAllHostUser: uids.length with empty result found.");
        return [];
      }else{
        var allHostUser = querySnapshot.docs.where((doc) => doc.exists).map((doc) => HostUserModel.fromJson(doc.data())).toList();
        logger.d("getAllHostUser: uids.length with total: ${allHostUser.length} result found.");
        return allHostUser;

      }

    }
  }
}