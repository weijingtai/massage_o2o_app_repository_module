import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/repository.dart';
import 'package:massage_o2o_app_repository_module/src/const_names.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  final fakeFirestore = FakeFirebaseFirestore();
  var testAssignRepository = AssignRepository(fakeFirestore);

  group("test get", () {
    test("test get",()async{
      var assignModel = generateAssignModel();
      testAssignRepository.add(assignModel);
      var result = await testAssignRepository.get(assignModel.guid);
      expect(result,assignModel);
    });
    test("test get null",()async{
      var result = await testAssignRepository.get(Uuid().v4());
      expect(result,null);
    });
  });

  group("test getAll",(){
    test("test getAll",()async{
      var assignModelList = List.generate(2, (index) => generateAssignModel());
      await testAssignRepository.addAll(assignModelList);
      var result = await testAssignRepository.getAll(assignModelList.map((e) => e.guid).toList());
      expect(result,assignModelList);
    });

  });

  group("test add",(){
    test('test add', () async {
      var newAssignModel = generateAssignModel();
      await testAssignRepository.add(newAssignModel);
      fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(newAssignModel.guid)
          .get()
          .then((value) {
        expect(value.data(), newAssignModel.toJson(),reason:"saved assignModel should be equal to newAssignModel");
      });
    });
    test("test addAll", ()async{
      // await fakeFirestore.clearPersistence();
      List<AssignModel> newAssignModels = List<AssignModel>.generate(2, (index) => generateAssignModel());
      await testAssignRepository.addAll(newAssignModels);
      var newQuerySnap = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .get();
      expect(newQuerySnap.size, 6,reason:"querySnap.size should be 6, after AssignRepository#addAll(newAssignModels)");
    });
  });

  group("test update",(){
    test("test update",()async{
      // await fakeFirestore.clearPersistence();
      var oldAssignModel = generateAssignModel();
      await testAssignRepository.add(oldAssignModel);
      var querySnapshot = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(oldAssignModel.guid)
          .get();
      expect(querySnapshot.exists, true,reason:"querySnapshot.exists should exits in firebase collection.");
      expect(querySnapshot.data(), oldAssignModel.toJson(),reason:"querySnapshot.data() should be equal to oldAssignModel.toJson()");

      // real test
      var newAssignModel = oldAssignModel;
      newAssignModel.state=AssignStateEnum.Assigning;
      await testAssignRepository.update(newAssignModel);
      var newQuerySnapshot = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(oldAssignModel.guid)
          .get();
      expect(newQuerySnapshot.exists, true,reason:"newQuerySnapshot.exists should exits in firebase collection.");
      expect(newQuerySnapshot.data(), newAssignModel.toJson(),reason:"newQuerySnapshot.data() should be equal to newAssignModel.toJson()");

    });
    test("test update with non-exits doc",()async{
      var oldAssignModel = generateAssignModel();
      // real test
      var newAssignModel = oldAssignModel;
      newAssignModel.state=AssignStateEnum.Assigning;
      await testAssignRepository.update(newAssignModel);
      var newQuerySnapshot = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(oldAssignModel.guid)
          .get();
      expect(newQuerySnapshot.exists, false,reason:"newQuerySnapshot.exists should exits in firebase collection.");
    });
  });

  group("test updateFields",(){
    test("test updateFields", ()async{
      var oldAssignModel = generateAssignModel();
      await testAssignRepository.add(oldAssignModel);
      var querySnapshot = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(oldAssignModel.guid)
          .get();
      expect(querySnapshot.exists, true,reason:"querySnapshot.exists should exits in firebase collection.");
      expect(querySnapshot.data(), oldAssignModel.toJson(),reason:"querySnapshot.data() should be equal to oldAssignModel.toJson()");

      var deliveredAt = DateTime.now();
      var newAssignModel = oldAssignModel;
      newAssignModel.state=AssignStateEnum.Assigning;
      newAssignModel.deliveredAt=deliveredAt;
      //real test
      await testAssignRepository.updateFields(oldAssignModel.guid, {
        "state":AssignStateEnum.Assigning.name,
        "deliveredAt": deliveredAt.toIso8601String(),
      });

      var newQuerySnapshot = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(oldAssignModel.guid)
          .get();

      expect(newQuerySnapshot.exists, true,reason:"newQuerySnapshot.exists should exits in firebase collection.");
      expect(newQuerySnapshot.data(), newAssignModel.toJson(),reason:"newQuerySnapshot.data() should be equal to oldAssignModel.toJson()");
    });
  });

  group("test updateAssignListFields",(){
    test("test updateAssignListFields with 2",()async{
      var oldAssignList = List.generate(2, (index) => generateAssignModel());
      await testAssignRepository.addAll(oldAssignList);

      var deliveredAt = DateTime.now();
      await testAssignRepository.updateAssignListFields(oldAssignList.map((e) => e.guid).toList(), {
        "deliveredAt": deliveredAt.toIso8601String(),
        "state": AssignStateEnum.Assigning.name,
      });

      var newData = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(oldAssignList.first.guid).get();
      expect(newData.exists, true);
      expect(newData["deliveredAt"], deliveredAt.toIso8601String());
      expect(newData["state"], AssignStateEnum.Assigning.name);

      newData = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(oldAssignList.last.guid).get();
      expect(newData.exists, true);
      expect(newData["deliveredAt"], deliveredAt.toIso8601String());
      expect(newData["state"], AssignStateEnum.Assigning.name);

    });
    test("test updateAssignListFields with 9",()async{
      var oldAssignList = List.generate(9, (index) => generateAssignModel());
      await testAssignRepository.addAll(oldAssignList);

      var deliveredAt = DateTime.now();
      var deliveredAtString = deliveredAt.toIso8601String();
      await testAssignRepository.updateAssignListFields(oldAssignList.map((e) => e.guid).toList(), {
        "deliveredAt": deliveredAtString,
        "state": AssignStateEnum.Assigning.name,
      });
      await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).where("guid", whereIn: oldAssignList.map((e) => e.guid).toList()).get().then((value) {
        expect(value.docs.length, oldAssignList.length,reason:"value.docs.length should be equal to oldAssignList.length");
        for(var i=0;i<value.docs.length;i++){
          var doc = value.docs[i];
          expect(doc.data()["deliveredAt"], deliveredAtString,reason:"doc.data() should be equal to assignModel.toJson()");
          expect(doc.data()["state"], AssignStateEnum.Assigning.name,reason:"doc.data() should be equal to assignModel.toJson()");
        }
      });

    });
    test("test updateAssignListFields with 10",()async{
      var oldAssignList = List.generate(10, (index) => generateAssignModel());
      await testAssignRepository.addAll(oldAssignList);

      var deliveredAt = DateTime.now();
      var deliveredAtString = deliveredAt.toIso8601String();
      await testAssignRepository.updateAssignListFields(oldAssignList.map((e) => e.guid).toList(), {
        "deliveredAt": deliveredAtString,
        "state": AssignStateEnum.Assigning.name,
      });
      await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).where("guid", whereIn: oldAssignList.map((e) => e.guid).toList()).get().then((value) {
        expect(value.docs.length, oldAssignList.length,reason:"value.docs.length should be equal to oldAssignList.length");
        for(var i=0;i<value.docs.length;i++){
          var doc = value.docs[i];
          expect(doc.data()["deliveredAt"], deliveredAtString,reason:"doc.data() should be equal to assignModel.toJson()");
          expect(doc.data()["state"], AssignStateEnum.Assigning.name,reason:"doc.data() should be equal to assignModel.toJson()");
        }
      });

    });
    test("test updateAssignListFields contains not exists",()async{
      var oldAssignList = List.generate(1, (index) => generateAssignModel());
      await testAssignRepository.addAll(oldAssignList);

      // not exist assignGuid
      var notExistAssignGuid = Uuid().v4();
      var updateAssignGuidList = oldAssignList.map((e) => e.guid).toList();
      updateAssignGuidList.add(notExistAssignGuid);

      var deliveredAt = DateTime.now();
      List<String>? notFoundAssignGuid = await testAssignRepository.updateAssignListFields(updateAssignGuidList, {
        "deliveredAt": deliveredAt.toIso8601String(),
        "state": AssignStateEnum.Assigning.name,
      });
      expect(notFoundAssignGuid != null, true);
      expect(notFoundAssignGuid!.length, 1);
      expect(notFoundAssignGuid.first,notExistAssignGuid);

      // check each assign model update success
      var newData = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(oldAssignList.first.guid).get();
      expect(newData.exists, true);
      expect(newData["deliveredAt"], deliveredAt.toIso8601String());
      expect(newData["state"], AssignStateEnum.Assigning.name);



    });
  });

  group("test delete",(){
    test("normal",()async{
      var newAssignModel = generateAssignModel();
      await testAssignRepository.add(newAssignModel);
      var querySnap = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(newAssignModel.guid).get();
      expect(querySnap.exists, true);
      var deletedAssign = await testAssignRepository.delete(newAssignModel.guid);
      var newQuerySnap = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(newAssignModel.guid).get();
      expect(newQuerySnap.exists, false);
      expect(deletedAssign, newAssignModel);

    });
    test("non-exists",() async {
      var notExistAssignGuid = Uuid().v4();
      var deletedAssign = await testAssignRepository.delete(notExistAssignGuid);
      expect(deletedAssign, null);
    });
  });

  group("test deleteAll",(){
    test("normal",()async{
      var newAssignModelList = List.generate(2, (index) => generateAssignModel());
      await testAssignRepository.addAll(newAssignModelList);
      var querySnap = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).where("guid",whereIn: newAssignModelList.map((e) => e.guid).toList()).get();
      expect(querySnap.size, 2);
      await testAssignRepository.deleteAll(newAssignModelList.map((e) => e.guid).toList());
    });
    test("1 not found",()async{
      var newAssignModelList = List.generate(2, (index) => generateAssignModel());
      var notExistAssignGuid = Uuid().v4();
      var exitsAssignGuidList = newAssignModelList.map((e) => e.guid).toList()..add(notExistAssignGuid);
      await testAssignRepository.addAll(newAssignModelList);
      var querySnap = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .where("guid",whereIn: exitsAssignGuidList).get();
      expect(querySnap.size, 2);
      List<AssignModel>? deletedAssignList = await testAssignRepository.deleteAll(newAssignModelList.map((e) => e.guid).toList());
      var newQuerySnap = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .where("guid",whereIn: exitsAssignGuidList)
          .get();
      expect(newQuerySnap.size, 0);
      expect(deletedAssignList!= null, true);
      expect(deletedAssignList!.map((e) => e.guid).toList().contains(notExistAssignGuid), false);

    });
  });

  group("test listAllByMasterUid",(){
    test("normal without param after",()async{
      var newAssignModelList = List.generate(2, (index) => generateAssignModel());
      // update createdAt
      var masterUid = Uuid().v4();
      newAssignModelList.first.createdAt = DateTime.now().subtract(Duration(days: 1));
      newAssignModelList.last.masterUid = masterUid;
      newAssignModelList.first.masterUid = masterUid;
      testAssignRepository.addAll(newAssignModelList);
      var result = await testAssignRepository.listAllByMasterUid(masterUid);
      expect(result.length, 2);
    });
    test("normal with param after as now",()async{
      var newAssignModelList = List.generate(2, (index) => generateAssignModel());
      // update createdAt
      var masterUid = Uuid().v4();
      var now = DateTime.now();
      newAssignModelList.first.createdAt = now.subtract(Duration(days: 1));
      newAssignModelList.first.masterUid = masterUid;
      newAssignModelList.last.masterUid = masterUid;
      newAssignModelList.last.createdAt = now;
      await testAssignRepository.addAll(newAssignModelList);
      var firstAssignInDB = await fakeFirestore.collection(ASSIGN_COLLECTION_NAME).doc(newAssignModelList.first.guid).get();
      // expect((firstAssignInDB.data() as Map<String,dynamic>)["createdAt"], "");
      var result = await testAssignRepository.listAllByMasterUid(masterUid,after: now.subtract(Duration(seconds: 5)));
      expect(result.length, 1);
    });
  });
}
AssignModel generateAssignModel() {
  var assignGuid = Uuid().v4();
  var masterUid = Uuid().v4();
  var orderGuid = Uuid().v4();
  var serviceGuid = Uuid().v4();
  var hostUid = Uuid().v4();
  var newAssignModel = AssignModel(assignGuid,
      masterUid: masterUid,
      serviceGuid: serviceGuid,
      orderGuid: orderGuid,
      hostUid: hostUid,
      assignTimeoutSeconds: 90,
      deliverTimeoutSeconds: 30,
      currentOrderStatus: OrderStatusEnum.Creating,
      senderUid: assignGuid,
      createdAt: DateTime.now());
  return newAssignModel;
}