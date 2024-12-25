import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../DevicesConfiguration/chainway_R5_RFID/chainwayR5Rfid.dart';
import '../DevicesConfiguration/chainway_R5_RFID/uhfManager.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../utils/app_color.dart';
import '../utils/app_config.dart';


class DeviceConfigurationPage extends StatefulWidget {
  const DeviceConfigurationPage({Key? key}) : super(key: key);

  @override
  _DeviceConfigurationPageState createState() => _DeviceConfigurationPageState();
}

class _DeviceConfigurationPageState extends State<DeviceConfigurationPage> {
  final TextEditingController _ipController = TextEditingController();
  FlutterSecureStorage storage = FlutterSecureStorage();
  String? selectedDevice = 'C5'; // Giá trị mặc định
  final UHFManager _uhfManager = UHFManager();
  List<Map<String, String>> bluetoothDevices = [];
  String? connectedDeviceName;
  String? connectedDeviceMac;


  @override
  void initState() {
    super.initState();
    _loadSelectedDevice().then((_) {
      _loadBLEDdDevices();
      if (connectedDeviceName != null && connectedDeviceMac != null) {
        setState(() {
          bluetoothDevices = bluetoothDevices.map((device) {
            device['isConnected'] = (device['name'] == connectedDeviceName &&
                device['address'] == connectedDeviceMac)
                ? 'true'
                : 'false';
            return device;
          }).toList();
        });
      }
    });

    // Đăng ký callback cho danh sách thiết bị
    _uhfManager.setDeviceListCallback((deviceList) {
      setState(() {
        bluetoothDevices = deviceList;
      });
    });
  }

  // Start scan device
  void startScanning() async {
    await UHFManager.scanDevices(true);
  }

  void navigateToChainwayr5rfid(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Chainwayr5rfid()
      ),
    );
  }

  Future<void> _saveBLEDeviceToStorage(String name, String mac) async {
    String? savedDevicesJson = await storage.read(key: 'connected_devices');
    List<Map<String, String>> savedDevices = savedDevicesJson != null
        ? List<Map<String, String>>.from(
        jsonDecode(savedDevicesJson).map((device) => {
          "name": device["name"].toString(),
          "address": device["address"].toString(),
        }))
        : [];

    // Kiểm tra nếu thiết bị đã tồn tại
    bool deviceExists = savedDevices.any((device) =>
    device['name'] == name && device['address'] == mac);

    if (!deviceExists) {
      savedDevices.add({'name': name, 'address': mac});
      await storage.write(key: 'connected_devices', value: jsonEncode(savedDevices));
    }
  }

  Future<void> _loadBLEDdDevices() async {
    String? savedDevicesJson = await storage.read(key: 'connected_devices');
    if (savedDevicesJson != null) {
      try {
        List<dynamic> rawList = jsonDecode(savedDevicesJson);
        bluetoothDevices = rawList.map<Map<String, String>>((device) {
          return {
            "name": device["name"].toString(),
            "address": device["address"].toString(),
          };
        }).toList();
        setState(() {});
      } catch (e) {
        print("Error loading Bluetooth devices: $e");
      }
    }
  }

  Future<void> _saveConfiguration() async {
    // Lưu thiết bị được chọn
    if (selectedDevice != null) {
      await storage.write(key: 'selected_device', value: selectedDevice);
      AppConfig.device = selectedDevice;

      // Nếu thiết bị là R5 và đã kết nối, lưu tên và MAC
      if (selectedDevice == 'R5' && connectedDeviceName != null && connectedDeviceMac != null) {
        await storage.write(key: 'connected_device_name', value: connectedDeviceName);
        await storage.write(key: 'connected_device_mac', value: connectedDeviceMac);

        AppConfig.connectedDeviceName = connectedDeviceName;
        AppConfig.connectedDeviceMac = connectedDeviceMac;
      }
    }

    // Hiển thị thông báo lưu thành công
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Cấu hình đã được lưu thành công"),
        backgroundColor: Colors.green,
      ),
    );
    // Navigator.pop(context, true); // Quay lại trang trước
  }

  Future<void> _loadSelectedDevice() async {
    String? savedDevice = await storage.read(key: 'selected_device'); // Lấy thiết bị từ storage
    String? savedDeviceName = await storage.read(key: 'connected_device_name');
    String? savedDeviceMac = await storage.read(key: 'connected_device_mac');

    if (savedDeviceName != null && savedDeviceMac != null) {
      bool canReconnect = await _uhfManager.connect(savedDeviceMac);
      if (!canReconnect) {
        await storage.delete(key: 'connected_device_name');
        await storage.delete(key: 'connected_device_mac');
        savedDeviceName = null;
        savedDeviceMac = null;
      }
    }

    setState(() {
      selectedDevice = savedDevice ?? 'C5'; // Nếu không có, mặc định là 'C5'
      AppConfig.device = selectedDevice;

      connectedDeviceName = savedDeviceName;
      connectedDeviceMac = savedDeviceMac;
    });
  }

    // Connect to Device via Mac address
  Future<void> _connectRFID(String name, String mac) async {
    bool connectResult = await _uhfManager.connect(mac);
    if (!connectResult) {
      print("Connection failed");
    } else {
      _saveBLEDeviceToStorage(name, mac);
      setState(() {
        connectedDeviceName = name;
        connectedDeviceMac = mac;
      });
      print("Connected successfully");
    }
  }

  // UI The function connects to the device
  void _connectToDevice(String name, String mac) {
    Navigator.of(context).pop(); // Đóng dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đang kết nối',
            style: TextStyle(
              // fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColor.mainText,
            ),
          ),
          content: Text('Đang kết nối với $name ($mac)...',
            style: TextStyle(
              fontSize: 18,
              // fontWeight: FontWeight.bold,
              color: AppColor.mainText,
            ),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
              ),
              onPressed: () {
                _connectRFID(name, mac);
                Navigator.of(context).pop(); // Đóng thông báo kết nối
              },
              child: const Text('OK',
                style: TextStyle(
                    color: Colors.white
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show popup device list
  void _showBluetoothDevicesDialog() async {
    // Bắt đầu quét thiết bị
    startScanning();

    // Hiển thị popup chờ
    showDialog(
      context: context,
      barrierDismissible: false, // Không cho phép đóng khi nhấn ngoài
      builder: (BuildContext context) {
        return const AlertDialog(
          title: Text('Đang quét thiết bị...',
            style: TextStyle(
              // fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColor.mainText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColor.mainText,
              ),
              SizedBox(height: 10),
              Text('Vui lòng đợi...',
                style: TextStyle(
                  fontSize: 18,
                  // fontWeight: FontWeight.bold,
                  color: AppColor.mainText,
                ),
              ),
            ],
          ),
        );
      },
    );

    // Chờ 10 giây (thời gian quét)
    await Future.delayed(const Duration(seconds: 10));

    // Đóng popup chờ
    Navigator.of(context).pop();

    // Hiển thị danh sách thiết bị
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Danh sách thiết bị Bluetooth',
            style: TextStyle(
              // fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColor.mainText,
            ),
          ),
          content: SizedBox(
            // Đặt chiều cao cố định cho danh sách
            height: 250,
            width: double.maxFinite,
            child: bluetoothDevices.isEmpty
                ? const Center(
              child: Text('Không tìm thấy thiết bị nào',
                style: TextStyle(
                  fontSize: 18,
                  // fontWeight: FontWeight.bold,
                  color: AppColor.mainText,
                ),
              ),
            )
                : ListView.builder(
              itemCount: bluetoothDevices.length,
              itemBuilder: (context, index) {
                final device = bluetoothDevices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device['name'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      // fontWeight: FontWeight.bold,
                      color: AppColor.mainText,
                    ),
                  ),
                  subtitle: Text(device['address'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      // fontWeight: FontWeight.bold,
                      color: AppColor.mainText,
                    ),
                  ),
                  onTap: () {
                    _connectToDevice(device['name']!, device['address']!);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
              },
              child: const Text('Đóng',
                style: TextStyle(
                    color: Colors.white
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Chọn thiết bị',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColor.mainText,
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 150, // Chiều cao của dialog
                child: ListView(
                  children: [
                    ...['Camera', 'C5', 'R5'].map((item) {
                      return Column(
                        children: [
                          Theme(
                            data: ThemeData(
                              radioTheme: RadioThemeData(
                                fillColor: MaterialStateProperty.resolveWith<Color>(
                                      (states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return AppColor.activeColorRadio; // Màu khi được chọn
                                    }
                                    return AppColor.mainText; // Màu khi chưa được chọn
                                  },
                                ),
                              ),
                            ),
                            child: RadioListTile<String>(
                              value: item,
                              groupValue: selectedDevice,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedDevice = value; // Cập nhật trong dialog
                                });
                              },
                              title: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: selectedDevice == item
                                      ? AppColor.mainText // Màu chữ khi được chọn
                                      : AppColor.borderInputColor, // Màu chữ khi chưa được chọn
                                ),
                              ),
                              activeColor: AppColor.activeColorRadio,
                            ),
                          ),

                          // if (item != 'R5') // Thêm đường viền nếu không phải mục cuối cùng
                          //   Padding(
                          //     padding: EdgeInsets.symmetric(horizontal: 16.0),
                          //     child: Divider(
                          //       color: AppColor.mainText.withOpacity(0.5),
                          //       thickness: 1,
                          //       height: 1,
                          //     ),
                          //   ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
          actions: [
            // TextButton(
            //   onPressed: () {
            //     Navigator.of(context).pop(); // Đóng dialog
            //   },
            //   child: Text(
            //     'Đóng',
            //     style: TextStyle(color: AppColor.mainText),
            //   ),
            // ),
            ElevatedButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColor.mainText,
                padding: EdgeInsets.symmetric(horizontal: 10 , vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // minimumSize: Size(screenWidth * 0., 0),
              ),
              onPressed: () {
                setState(() {
                  AppConfig.device = selectedDevice; // Lưu thiết bị được chọn
                });
                Navigator.of(context).pop(); // Đóng dialog
              },
              child: Text(
                'Chọn',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: screenHeight * 0.12, // Chiều cao thanh công cụ
        backgroundColor: const Color(0xFFE9EBF1),
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.5),
        // leading: Padding(
        //   padding: EdgeInsets.only(left: screenWidth * 0.03), // Khoảng cách từ mép trái
        //   child: Container(
        //     width: screenWidth * 0.2, // Chiều rộng logo
        //     height: screenHeight * 0.15, // Chiều cao logo
        //     child: Image.asset(
        //       'assets/image/logoJVF_RFID.png',
        //       fit: BoxFit.contain,
        //     ),
        //   ),
        // ),
        title: Text(
          'Cấu hình thiết bị',
          style: TextStyle(
            fontSize: screenWidth * 0.07, // Kích thước chữ
            fontWeight: FontWeight.bold,
            color: AppColor.mainText,
          ),
        ),
        actions: [],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: screenHeight *0.05, left: screenWidth * 0.05, right: screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn thiết bị',
              style: TextStyle(
                fontSize: 26,
                color: AppColor.mainText,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            // Container(
            //   padding: EdgeInsets.symmetric(horizontal: 12.0),
            //   decoration: BoxDecoration(
            //     color: Color(0xFFEBEDEC),
            //     borderRadius: BorderRadius.circular(12.0),
            //     border: Border.all(color: Color(0xFFEBEDEC)),
            //   ),
            //   child: DropdownButton<String>(
            //     value: selectedDevice, // Giá trị đang chọn
            //     isExpanded: true, // Để DropdownButton chiếm toàn bộ chiều ngang
            //     underline: SizedBox(), // Xóa đường gạch chân mặc định
            //     items: [
            //       DropdownMenuItem(
            //         value: 'Camera',
            //         child: Text(
            //           'Camera',
            //           style: TextStyle(fontSize: 18, color: AppColor.mainText),
            //         ),
            //       ),
            //       DropdownMenuItem(
            //         value: 'C5',
            //         child: Text(
            //           'C5',
            //           style: TextStyle(fontSize: 18, color: AppColor.mainText),
            //         ),
            //       ),
            //       DropdownMenuItem(
            //         value: 'R5',
            //         child: Text(
            //           'R5',
            //           style: TextStyle(fontSize: 18, color: AppColor.mainText),
            //         ),
            //       ),
            //     ],
            //     onChanged: (String? value) {
            //       setState(() {
            //         selectedDevice = value; // Cập nhật giá trị đã chọn
            //         AppConfig.device = selectedDevice;
            //
            //         // if (selectedDevice == 'R5') {
            //         //   _showBluetoothDevicesDialog(); // Gọi quét Bluetooth nếu chọn R5
            //         // }
            //       });
            //     },
            //   ),
            // ),
            Container(
              child: GestureDetector(
                onTap: () => _showDeviceSelectionDialog(context), // Gọi dialog khi nhấn vào container
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppColor.mainText), // Viền mặc định
                    color: Color(0xFFEBEDEC), // Màu nền
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDevice ?? 'Chọn thiết bị', // Hiển thị thiết bị được chọn hoặc thông báo
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColor.mainText,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: AppColor.mainText), // Icon chỉ định dropdown
                    ],
                  ),
                ),
              ),
            ),

            // Container(
            //   child: DropdownSearch<String>(
            //     selectedItem: selectedDevice, // Giá trị đang chọn
            //     items: ['Camera', 'C5', 'R5'], // Danh sách các thiết bị
            //     dropdownDecoratorProps: DropDownDecoratorProps(
            //       dropdownSearchDecoration: InputDecoration(
            //         contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            //         border: OutlineInputBorder(
            //           borderRadius: BorderRadius.circular(12.0),
            //           borderSide: BorderSide(color: AppColor.mainText), // Viền mặc định
            //         ),
            //         focusedBorder: OutlineInputBorder(
            //           borderRadius: BorderRadius.circular(12.0),
            //           borderSide: BorderSide(color: AppColor.mainText, width: 2.0), // Viền khi focus
            //         ),
            //         enabledBorder: OutlineInputBorder(
            //           borderRadius: BorderRadius.circular(12.0),
            //           borderSide: BorderSide(color: AppColor.mainText), // Viền khi không focus
            //         ),
            //         filled: true,
            //         fillColor: Color(0xFFEBEDEC),
            //         // hintText: 'Chọn thiết bị',
            //         hintStyle: TextStyle(
            //           color: AppColor.mainText,
            //           fontSize: 18,
            //         ),
            //       ),
            //       baseStyle: TextStyle(
            //         color: AppColor.mainText, // Màu chữ của giá trị đã chọn
            //         fontSize: 18,
            //       ),
            //     ),
            //     popupProps: PopupProps.menu(
            //       showSearchBox: false, // Tắt ô tìm kiếm
            //       constraints: BoxConstraints(maxHeight: screenHeight*0.3), // Giới hạn chiều cao của popup
            //       itemBuilder: (context, String item, isSelected) {
            //         final isLastItem = item == 'R5'; // Điều kiện để xác định mục cuối cùng
            //         return Column(
            //           children: [
            //             ListTile(
            //               title: Text(
            //                 item,
            //                 style: TextStyle(
            //                   fontSize: 18,
            //                   color: isSelected ? AppColor.mainText : AppColor.borderInputColor,
            //                 ),
            //               ),
            //             ),
            //             if (!isLastItem)
            //               Padding(
            //                 padding: EdgeInsets.symmetric(horizontal: screenWidth*0.02), // Padding hai bên Divider
            //                 child: Divider(
            //                   color: AppColor.mainText.withOpacity(0.5), // Đường viền ngang
            //                   thickness: 1, // Độ dày đường viền
            //                   height: 1, // Khoảng cách giữa các đường viền
            //                 ),
            //               ),
            //           ],
            //         );
            //       },
            //     ),
            //     onChanged: (String? newValue) {
            //       setState(() {
            //         selectedDevice = newValue; // Cập nhật giá trị khi chọn
            //         AppConfig.device = selectedDevice;
            //       });
            //     },
            //   ),
            // ),
            SizedBox(height: 20),
            if (selectedDevice == 'R5') ...[
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    ElevatedButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColor.mainText,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth*0.05 , vertical: screenHeight * 0.013),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.04),
                        ),
                        // minimumSize: Size(screenWidth * 0., 0),
                      ),
                      onPressed:(){
                        _showBluetoothDevicesDialog();
                      },
                      child: Text("Kết nối",
                        style: TextStyle(fontSize: screenWidth*0.05, color: Colors.white),
                      ),
                    ),
                    if (connectedDeviceName != null && connectedDeviceMac != null) ...[
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        'Thiết bị đang kết nối:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColor.mainText,
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true, // Đảm bảo ListView không chiếm toàn bộ chiều cao
                        itemCount: 1, // Chỉ hiển thị thiết bị được kết nối
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: AppColor.mainText,
                            ),
                            title: Text(
                              '$connectedDeviceName ($connectedDeviceMac)',
                              style: TextStyle(
                                fontSize: 16,
                                // fontWeight: FontWeight.bold,
                                color: AppColor.mainText,
                              ),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Đang kết nối đến \n$connectedDeviceName ($connectedDeviceMac)",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              print("Thiết bị đã được kết nối.");
                            },
                          );
                        },
                      )
                    ] else ...[
                      Text(
                        'Chưa có thiết bị nào được kết nối.',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                    ],

                  ],
                ),
              )
            ]
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(
          style: TextButton.styleFrom(
            backgroundColor: AppColor.mainText,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.2, vertical: screenHeight * 0.022),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.048),
            ),
            minimumSize: Size(screenWidth * 0.8, 0),
          ),
          onPressed:(){
            // _saveIPToStorage
            _saveConfiguration();
          },
          child: Text("Lưu Cấu Hình",
            style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.06, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
