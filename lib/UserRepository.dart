
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:massage_o2o_app_models_module/models.dart';

class UserRepository{
  // logger
  static Logger logger = Logger();
  Future<UserModel?> getUserByUid(String uid) async {
    logger.i("UserRepository#getUserByUid: uid: $uid");
    var snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
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
}