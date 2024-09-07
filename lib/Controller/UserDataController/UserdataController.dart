import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

import '../../main.dart';

const String syncTask = "syncTask";
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == syncTask) {
      await Firebase.initializeApp();
      UserDataController userDataController = Get.put(UserDataController());
      await userDataController.syncAllToFirebase();
    }
    return Future.value(true);
  });
}

class UserDataController extends GetxController {
  Database? _database;
  var userData = <Map<String, dynamic>>[].obs;

  var name = ''.obs;
  var email = ''.obs;
  var phoneNumber = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initDatabase();
    Workmanager().initialize(callbackDispatcher); // Initialize WorkManager
  }

  // Initialize the SQLite database
  Future<void> initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_data.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT,
            phone TEXT,
            isSynced INTEGER
          )
        ''');
      },
    );

    fetchUserData(); // Load existing data on startup
  }

  // Add user data to the database and update the local list
  Future<void> addUserData() async {
    if (name.isNotEmpty && email.isNotEmpty && phoneNumber.isNotEmpty) {
      final List<Map<String, dynamic>> existingUser = await _database!.query(
        'users',
        where: 'email = ? AND phone = ?',
        whereArgs: [email.value, phoneNumber.value],
      );

      if (existingUser.isEmpty) {
        // Insert the data into the SQLite database
        int id = await _database!.insert('users', {
          "name": name.value,
          "email": email.value,
          "phone": phoneNumber.value,
          "isSynced": 0, // Not synced yet
        });

        // Add a 'loading' field to the new entry for UI purposes
        userData.add({
          "id": id,
          "name": name.value,
          "email": email.value,
          "phone": phoneNumber.value,
          "isSynced": false,  // Not synced yet
          "loading": true,    // Show loading icon initially
        });

        // Schedule a one-time background sync after 10 minutes
        scheduleSyncTask();
      }

      clearForm(); // Clear the form fields after adding data
    }
  }
  Future<void> deleteUser(int id) async {
    if (_database != null) {
      await _database!.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      fetchUserData();
    }
  }


  Future<void> fetchUserData() async {
    if (_database != null) {
      final List<Map<String, dynamic>> maps = await _database!.query('users');

      // Add the 'loading' field to each item for UI purposes
      userData.assignAll(maps.map((data) {
        return {
          "id": data['id'],
          "name": data['name'],
          "email": data['email'],
          "phone": data['phone'],
          "isSynced": data['isSynced'] == 1,
          "loading": false,  // By default, not loading unless newly added
        };
      }).toList());
    }
  }

  // Sync all unsynced data to Firebase
  Future<void> syncAllToFirebase() async {
    final List<Map<String, dynamic>> unsyncedData = await _database!.query(
      'users',
      where: 'isSynced = ?',
      whereArgs: [0], // Fetch records where isSynced = 0 (unsynced)
    );

    for (var data in unsyncedData) {
      try {
        await FirebaseFirestore.instance.collection('users').add({
          'name': data['name'],
          'email': data['email'],
          'phone': data['phone'],
        });

        // Update the sync status in the SQLite database
        await _database!.update(
          'users',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [data['id']],
        );

        // Update the user data list (remove loading state, mark as synced)
        int index = userData.indexWhere((item) => item['id'] == data['id']);
        if (index != -1) {
          userData[index]['isSynced'] = true;
          userData[index]['loading'] = false;  // Stop showing loading icon
          userData.refresh();
        }
      } catch (e) {
        print('Error syncing data: $e');
      }
    }
  }

  // Schedule a one-time background sync with WorkManager (after 10 minutes)
  void scheduleSyncTask() {
    Workmanager().registerOneOffTask(
      "syncTask", // Unique task name
      syncTask,   // Task ID
      initialDelay: Duration(minutes: 10), // Delay sync for 10 minutes
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when the device has internet
      ),
    );
  }

  // Clear form fields
  void clearForm() {
    name.value = '';
    email.value = '';
    phoneNumber.value = '';
  }
}
