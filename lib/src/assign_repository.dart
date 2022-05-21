import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:massage_o2o_app_models_module/models.dart';

import 'const_names.dart';

class AssignRepository {
  AssignRepository();

  CollectionReference orderCollection = FirebaseFirestore.instance.collection(ORDER_COLLECTION_NAME);
  /// add each assign '/Order/<CURRENT_LOGGED_IN_HOST_UID>/<PREPARING_COLLECTION_NAME>/<ORDER_GUID>/assigns/<ASSIGN_GUID>'
  Future<void> _remoteCreateAssigns(OrderModel order,List<AssignModel> assignList){
    var orderDocumentRef = orderCollection.doc(order.hostUid).collection(ORDER_COLLECTION_NAME_PREPARING).doc(order.guid);
    // when assignList is not null or empty, create a new document for each assign
    if (assignList.isNotEmpty) {
      // create new document for each assign, only if assignList is not null and not empty
      var orderServiceAssignDocumentRef = orderDocumentRef.collection(SERVICE_ASSIGN_COLLECTION_NAME);
      return Future.wait(assignList.map((e) => orderServiceAssignDocumentRef.doc(e.guid).set(e.toJson(),SetOptions(merge: true))));
    }
    return Future.value();
  }
}