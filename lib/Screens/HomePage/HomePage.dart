import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controller/UserDataController/UserdataController.dart';

class HomePage extends StatelessWidget {
 HomePage({super.key});

  final userDataController=Get.put(UserDataController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Data with Individual Loading Icon'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form Section
            TextFormField(
              decoration: InputDecoration(labelText: 'Name'),
              onChanged: (value) => userDataController.name.value = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (value) => userDataController.email.value = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              onChanged: (value) => userDataController.phoneNumber.value = value,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => userDataController.addUserData(),
              child: Text('Add User Data'),
            ),
            ElevatedButton(
              onPressed: () => userDataController.syncAllToFirebase,
              child: Text('SyncAll data'),
            ),
            SizedBox(height: 20),

            // ListView Section
            Expanded(
              child: Obx(() {
                return ListView.builder(
                  itemCount: userDataController.userData.length,
                  itemBuilder: (context, index) {
                    final data = userDataController.userData[index];
                    return ListTile(
                      title: Text(data['name']),
                      subtitle: Text('${data['email']} \n${data['phone']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show loading icon for the record that is being synced
                          data['loading']
                              ? Icon(Icons.hourglass_top, color: Colors.blue)
                              : Icon(
                            data['isSynced']
                                ? Icons.cloud_done
                                : Icons.cloud_upload,
                            color:
                            data['isSynced'] ? Colors.green : Colors.blue,
                          ),
                          // Delete Button for each record
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              userDataController.deleteUser(data['id']);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
