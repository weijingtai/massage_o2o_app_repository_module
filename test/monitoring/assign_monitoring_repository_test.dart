import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:massage_o2o_app_models_module/enums.dart';
import 'package:massage_o2o_app_models_module/models.dart';
import 'package:massage_o2o_app_repository_module/monitoring.dart';
import 'package:massage_o2o_app_repository_module/repository.dart';
import 'package:massage_o2o_app_repository_module/src/enums/assign_model_change_type_enum.dart';
import 'package:quiver/testing/src/time/time.dart';
import 'package:quiver/time.dart';
import 'package:uuid/uuid.dart';

import '../test_utils.dart';

Future<void> main() async {
  var repositoryConfig = await loadRepositoryConfig();

  String ASSIGN_COLLECTION_NAME =
      repositoryConfig.assignRepositoryConfig.collectionName;
  group("monitoring assign by orderGuid", () {
    test("normal", () async {
      var fakeFirestore = FakeFirebaseFirestore();
      var testAssignMonitoringRepository = AssignMonitoringRepository(
          firestore: fakeFirestore, repositoryConfig: repositoryConfig);
      String orderGuid = Uuid().v4();
      var addedAssignModel = generateAssignModel();
      addedAssignModel.orderGuid = orderGuid;
      testAssignMonitoringRepository.monitorActivatedByOrderGuid(orderGuid);
      testAssignMonitoringRepository.assignStream.listen((event) {
        expect(event.item1, AssignModelChangeType.Added);
        expect(event.item2, addedAssignModel);
        testAssignMonitoringRepository.assignStreamController.close();
        // });
      }, onDone: () async {
        expect(testAssignMonitoringRepository.monitoringAssignMap.length, 1,
            reason: "monitoringAssignMap length should be 1");
        expect(testAssignMonitoringRepository.monitoringOrderGuidMap.length, 1,
            reason: "monitoringOrderGuidMap length should be 1");
        expect(
            testAssignMonitoringRepository.monitoringOrderGuidMap[orderGuid], 1,
            reason: "monitoringOrderGuidMap[orderGuid] should be 1");
      });
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(addedAssignModel.guid)
          .set(addedAssignModel.toJson());
    });
    test("with ignore", () async {
      var fakeFirestore = FakeFirebaseFirestore();
      var testAssignMonitoringRepository = AssignMonitoringRepository(
          firestore: fakeFirestore, repositoryConfig: repositoryConfig);
      String orderGuid = const Uuid().v4();
      var eventList = [];
      var addedAssignModel = generateAssignModel();
      addedAssignModel.createdAt = DateTime.now().subtract(Duration(days: 1));
      addedAssignModel.orderGuid = orderGuid;
      testAssignMonitoringRepository.monitorActivatedByOrderGuid(orderGuid,
          ignoreBeforeCreatedAtWhenAdded: DateTime.now());
      testAssignMonitoringRepository.assignStream.listen((event) {
        eventList.add(event);
        testAssignMonitoringRepository.assignStreamController.close();
      }, onDone: () {
        expect(eventList.length, 0, reason: "eventList length should be 0");
      });
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(addedAssignModel.guid)
          .set(addedAssignModel.toJson());
      // expect(testAssignMonitoringRepository.monitoringAssignMap.length,1,reason: "monitoringAssignMap length should be 1");
      // expect(testAssignMonitoringRepository.monitoringOrderGuidMap.length, 1,reason: "monitoringOrderGuidMap length should be 1");
      // expect(testAssignMonitoringRepository.monitoringOrderGuidMap[orderGuid],1,reason: "monitoringOrderGuidMap[orderGuid] should be 1");
    });
  });
  group("monitoring assign by masterUid", () {
    test("add Preparing state assign nothing happens.", () async {
      var fakeFirestore = FakeFirebaseFirestore();
      var testAssignMonitoringRepository = AssignMonitoringRepository(
          firestore: fakeFirestore, repositoryConfig: repositoryConfig);
      String masterUid = Uuid().v4();
      var addedAssignModel = generateAssignModel();
      addedAssignModel.masterUid = masterUid;
      // addedAssignModel.assign();
      testAssignMonitoringRepository.monitorAssigningByMasterUid(masterUid);
      testAssignMonitoringRepository.assignStream.listen((event) {
        // expect(event.item1, AssignModelChangeType.Added);
        // expect(event.item2, addedAssignModel);
        // testAssignMonitoringRepository.assignStreamController.close();
      }).onDone(() {
        expect(testAssignMonitoringRepository.monitoringAssignMap.length, 0);
      });
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(addedAssignModel.guid)
          .set(addedAssignModel.toJson());
      testAssignMonitoringRepository.assignStreamController.close();
      // Future.delayed(aSecond * 3);
    });
    test("updated with AssignModel#assign() ", () async {
      var fakeFirestore = FakeFirebaseFirestore();
      var testAssignMonitoringRepository = AssignMonitoringRepository(
          firestore: fakeFirestore, repositoryConfig: repositoryConfig);
      String masterUid = Uuid().v4();
      var addedAssignModel = generateAssignModel();
      addedAssignModel.masterUid = masterUid;
      addedAssignModel.createdAt = DateTime.now().subtract(aSecond * 10);
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(addedAssignModel.guid)
          .set(addedAssignModel.toJson());

      var updateAssignModel = AssignModel.fromJson(addedAssignModel.toJson());
      updateAssignModel.assign();
      expect(addedAssignModel.guid, updateAssignModel.guid);

      testAssignMonitoringRepository.monitorAssigningByMasterUid(masterUid);
      testAssignMonitoringRepository.assignStream.listen((event) {
        expect(event.item1, AssignModelChangeType.Added);
        expect(event.item2.assignAt != null, true);
        expect(event.item2.state, AssignStateEnum.Delivering);
        testAssignMonitoringRepository.assignStreamController.close();
      }).onDone(() {
        expect(testAssignMonitoringRepository.monitoringAssignMap.length, 1);
      });
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(updateAssignModel.guid)
          .set(updateAssignModel.toJson(), SetOptions(merge: true));

      // Future.delayed(aSecond * 3);
    });
    test("updated with AssignModel#accept() ", () async {
      var fakeFirestore = FakeFirebaseFirestore();
      var testAssignMonitoringRepository = AssignMonitoringRepository(
          firestore: fakeFirestore, repositoryConfig: repositoryConfig);
      String masterUid = Uuid().v4();
      var addedAssignModel = generateAssignModel();
      addedAssignModel.masterUid = masterUid;
      addedAssignModel.assign();
      addedAssignModel.deliver();
      testAssignMonitoringRepository.monitorAssigningByMasterUid(masterUid);
      testAssignMonitoringRepository.assignStream.listen((event) {
        expect(event.item1, AssignModelChangeType.Added);
        expect(event.item2.state, AssignStateEnum.Assigning);
        // testAssignMonitoringRepository.assignStreamController.close();
      }).onDone(() {
        expect(testAssignMonitoringRepository.monitoringAssignMap.length, 1);
      });
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(addedAssignModel.guid)
          .set(addedAssignModel.toJson());

      var updateAssignModel = AssignModel.fromJson(addedAssignModel.toJson());
      updateAssignModel.accept();
      expect(addedAssignModel.guid, updateAssignModel.guid);
      await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(updateAssignModel.guid)
          .set(updateAssignModel.toJson(), SetOptions(merge: true));
      // .update({
      // "respondedAt": updateAssignModel.respondedAt!.toUtc().toIso8601String(),
      // "state": updateAssignModel.state.name,
      // });
      var snap = await fakeFirestore
          .collection(ASSIGN_COLLECTION_NAME)
          .doc(updateAssignModel.guid)
          .get();
      expect(snap.data()!["state"], AssignStateEnum.Accepted.name);

      // Future.delayed(aSecond * 3);
    },
        skip:
            "FakeFirebaseFirestore is not working well when doc is not matching the query for DocumentChangeType.removed");
  });
}
