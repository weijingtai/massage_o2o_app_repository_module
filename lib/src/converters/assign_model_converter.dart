


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:massage_o2o_app_models_module/models.dart';


/// current version only call "fromJson" method for AssignModel
/// convert AssignModel to Map<String,dynamic> for firestore
final FromFirestore<AssignModel?> AssignModelFromFirestoreFunction = (snapshot, options){
  if (snapshot.exists){
    return AssignModel.fromJson(snapshot.data()!);
  }
  return null;
};

/// current version only call 'toJson' method of AssignModel
/// convert Map<String,dynamic> to AssignModel from firestore
final ToFirestore<AssignModel?> AssignModelToFirestoreFunction = (model, options){
  if (model != null){
    return model.toJson();
  }
  else{
    return Map.of({});
  }
};