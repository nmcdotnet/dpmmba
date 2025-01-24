import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rfid_c72_plugin_example/Home/login_database.dart';
import 'package:rfid_c72_plugin_example/Recall_Management/recall_surplus_goods.dart';
import 'package:rfid_c72_plugin_example/Recall_Management/recall_to_cancel.dart';
import 'package:rfid_c72_plugin_example/Sling/sling_export.dart';
import 'package:rfid_c72_plugin_example/utils/app_color.dart';
import '../Configuration/device_configuration.dart';
import '../Distribution_Module/offline_distribution.dart';
import '../Check_Inventory/check_inventory.dart';
import '../Assign_Packing_Information/information_package.dart';
import '../Recall_Management/recall_manage.dart';
import '../Check_Goods_Infor_Module/goods_information.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../Recall_Replacement/recall_replacement_offline_list.dart';
import '../UserDatatypes/user_datatype.dart';
import '../main.dart';
import '../utils/app_config.dart';
import 'package:marquee/marquee.dart';

import '../Configuration/configuration_page.dart';

class HomePage extends StatefulWidget {
  final String taiKhoan;

  const HomePage({
    Key? key,
    required this.taiKhoan,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> licenseCode = [];
  final _storageAcountCode = const FlutterSecureStorage();
  final storage = const FlutterSecureStorage();
  String? connectedDeviceName;
  String? connectedDeviceMac;
  String? selectedDevice;

  final ScrollController _scrollController = ScrollController();
  bool _showArrowUp = false;
  bool _showArrowDown = false;

  @override
  void initState() {
    super.initState();

    Timer? _debounce; // delay for call setState avoid lag
    _scrollController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        setState(() {
          _showArrowUp = _scrollController.offset > 0;
          _showArrowDown = _scrollController.offset <
              _scrollController.position.maxScrollExtent;
        });
      });
    });

    _loadSelectedDevice();
    _initCodes(); // Hàm lấy cả mã quyền và mã chức năng
  }

  // Đọc mã quyền và mã chức năng từ Secure Storage
  // Future<void> _initCodes() async {
  //   licenseCode = await _storageAcountCode.read(key: 'maQuyen');
  //   print('License Code: $licenseCode');
  //   setState(() {});
  // }

  // Future<void> _initCodes() async {
  //   licenseCode = await _storageAcountCode.read(key: 'maCN');
  //   print('License Code: $licenseCode');
  //   setState(() {});
  // }
  Future<void> _initCodes() async {
    // Đọc danh sách mã chức năng từ Secure Storage
    String? maCNListString = await _storageAcountCode.read(key: 'maCNList');
    if (maCNListString != null) {
      // Chuyển chuỗi thành danh sách các mã chức năng
      List<String> maCNList = maCNListString.split(',');
      print('Danh sách mã chức năng: $maCNList');

      // Giữ danh sách mã chức năng vào state
      setState(() {
        licenseCode = maCNList; // Bạn có thể điều chỉnh nếu muốn xử lý nhiều mã
        print('danh sách: $licenseCode');
      });
    }
  }

  Future<void> _loadSelectedDevice() async {
    String? savedDevice =
        await storage.read(key: 'selected_device'); // Lấy thiết bị từ storage
    String? savedDeviceName = await storage.read(key: 'connected_device_name');
    String? savedDeviceMac = await storage.read(key: 'connected_device_mac');

    // Reconnect the R5 device if it was previously saved
    if (savedDeviceName != null &&
        savedDeviceMac != null &&
        savedDevice == 'R5') {
      if (!(await UHFBlePlugin.getConnectionStatus())) {
        await UHFBlePlugin.connect(savedDeviceMac);
      }
    }

    setState(() {
      selectedDevice = savedDevice ?? 'C5'; // Nếu không có, mặc định là 'C5'
      connectedDeviceName = savedDeviceName;
      connectedDeviceMac = savedDeviceMac;

      if (selectedDevice == 'C5') {
        currentDevice = Device.cSeries;
      } else if (selectedDevice == 'R5') {
        currentDevice = Device.rSeries;
      } else if (selectedDevice == 'Camera') {
        currentDevice = Device.cameraBarcodes;
      }

      AppConfig.device = selectedDevice;
      AppConfig.connectedDeviceName = connectedDeviceName;
      AppConfig.connectedDeviceMac = connectedDeviceMac;
    });
    print('Saved bluetooth name: ${AppConfig.connectedDeviceName}');
    print('Saved Bluetooth Mac: ${AppConfig.connectedDeviceMac}');
    print('Device type: ${AppConfig.device}');
  }

  //#region Navigation to menu
  /// Check Product
  void navigateToGoodsDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GoodsInformation()),
    );
  }

  /// Distribution
  void navigateToOfflineDistribution(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => OfflineDistribution(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Inventory check
  void navigateToCheckInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CheckInventory(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Assign info package
  void navigateToOfflineInformationDistribution(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              OfflineInformationDistribution(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Recall cancel manage
  void navigateToOfflineRecallManage(BuildContext context) {
    Navigator.push(
      context,
      //  MaterialPageRoute(builder: (context) => OfflineRecallManage(taiKhoan: widget.taiKhoan)),
      MaterialPageRoute(
          builder: (context) => RecallToCancel(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Recall surplus manage
  void navigateToOfflineRecallSurplusManage(BuildContext context) {
    Navigator.push(
      context,
      //  MaterialPageRoute(builder: (context) => OfflineRecallManage(taiKhoan: widget.taiKhoan)),
      MaterialPageRoute(
          builder: (context) => RecallFromSurplus(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Recall replace
  void navigateToOfflineRecallReplacemantList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              OfflineRecallReplacemantList(taiKhoan: widget.taiKhoan)),
    );
  }

  /// Sling Export
  void navigateToSlingExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SlingExport(taiKhoan: widget.taiKhoan)),
    );
  }

  // lOGOUT
  void navigateToLoginPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  //#endregion

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.12), // Chiều cao AppBar
        child: AppBar(
          backgroundColor: AppColor.backgroundAppColor,
          // Màu nền (có thể tùy chỉnh)
          elevation: 0,
          // Xóa bóng của AppBar
          flexibleSpace: Padding(
            padding: EdgeInsets.only(
                left: screenWidth * 0.08,
                top: screenHeight * 0.02,
                bottom: screenHeight * 0.002), // Khoảng cách bên trong AppBar
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // Căn giữa nội dung theo trục dọc
              children: [
                Image.asset(
                  'assets/image/logoJVF_RFID.png',
                  width: screenWidth * 0.5, // Chiều rộng của logo
                  height: screenHeight * 0.65,
                  fit: BoxFit.contain, // Đảm bảo logo không bị cắt xén
                ),
                //   SizedBox(width: screenWidth * 0.03),
                // Container(
                //   child: Text("Trang Chủ",
                //       style: TextStyle(fontSize: 30, color: AppColor.mainText)),
                //   alignment: Alignment.bottomCenter,
                // ),
                // Khoảng cách giữa logo và chữ
                // const Expanded(
                //   child: Column(
                //     mainAxisAlignment: MainAxisAlignment.end,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [],
                //   ),
                // ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                // Mở ConfigurationPage và nhận giá trị trả về
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DeviceConfigurationPage()),
                );

                // Kiểm tra kết quả trả về từ ConfigurationPage
                if (result != null) {
                  setState(() {});

                  print('Địa chỉ IP được chọn: ${AppConfig.IP}');
                  print('Thiết bị quét được chọn: $selectedDevice');
                }
              },
              icon: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                  child: const Icon( size: 30,
                    Icons.settings_outlined,
                    color: AppColor.mainText,
                  )),
            ),
          ],
        ),
      ),
      body: Container(
        padding: EdgeInsets.fromLTRB(
            screenWidth * 0.08, screenHeight * 0.01, screenWidth * 0.08, 0),
        constraints: const BoxConstraints.expand(),
        color: AppColor.backgroundAppColor,
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Menu list
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    children: <Widget>[
                      if (licenseCode.contains('CNKTSP')) ...[
                        TextButton(
                          onPressed: () {
                            navigateToGoodsDetail(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.045,
                                vertical: screenHeight * 0.02),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/quetSP_logo.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.13,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'KIỂM TRA SẢN PHẨM',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNPP')) ...[
                        // if (licenseCode == 'MQ0012' || licenseCode == 'MQ0008') ...[ // Hiển thị cho Quyền Phân Phối và Admin
                        TextButton(
                          onPressed: () {
                            navigateToOfflineDistribution(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.045,
                                vertical: screenHeight * 0.015),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/phanphoi_logo.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.14,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'PHÂN PHỐI',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNKK')) ...[
                        // if (licenseCode == 'MQ0012' || licenseCode == 'MQ0008') ...[ // Hiển thị cho Quyền Kiểm Kho và Admin
                        TextButton(
                          onPressed: () {
                            navigateToCheckInventory(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.05,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/kiemkho_logo.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'KIỂM KHO',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNDB')) ...[
                        // if (licenseCode == 'MQ0002' || licenseCode == 'MQ0013' || licenseCode == 'MQ0008' ) ...[// Hiển thị cho Quyền Đóng Bao và Admin
                        TextButton(
                          onPressed: () {
                            navigateToOfflineInformationDistribution(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.015),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/gantt.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'GÁN THÔNG TIN \nĐÓNG BAO',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNQLTHH')) ...[
                        // if (licenseCode == 'MQ0008' || licenseCode == 'MQ0012') ...[ // Chỉ hiển thị cho Admin
                        TextButton(
                          onPressed: () {
                            navigateToOfflineRecallManage(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/thuhoi.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'THU HỒI HỦY',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNQLTHN')) ...[
                        // if (licenseCode == 'MQ0008' || licenseCode == 'MQ0012') ...[ // Chỉ hiển thị cho Admin
                        TextButton(
                          onPressed: () {
                            navigateToOfflineRecallSurplusManage(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/thuhoi.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'THU HỒI XUẤT DƯ',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (licenseCode.contains('CNTHTT')) ...[
                        // if (licenseCode == 'MQ0008' || licenseCode == 'MQ0012') ...[ // Chỉ hiển thị cho Admin
                        TextButton(
                          onPressed: () {
                            navigateToOfflineRecallReplacemantList(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/recall_replace.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'THU HỒI THAY THẾ',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      if (true) ...[
                        // if (licenseCode == 'MQ0012' || licenseCode == 'MQ0008') ...[ // Hiển thị cho Quyền Phân Phối và Admin
                        TextButton(
                          onPressed: () {
                            navigateToSlingExport(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/phanphoi_logo.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'XUẤT SLING',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],//CNXSLN
                      if (true) ...[
                        // if (licenseCode == 'MQ0008' || licenseCode == 'MQ0012') ...[ // Chỉ hiển thị cho Admin
                        TextButton(
                          onPressed: () {
                            navigateToLoginPage(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColor.mainText,
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.055,
                                vertical: screenHeight * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/image/logout.png',
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                              ),
                              SizedBox(width: screenWidth * 0.1),
                              Text(
                                'ĐĂNG XUẤT',
                                style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'v1.0.0.0',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          ' | Server: ${AppConfig.IP}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Arrow button in the corner
            Positioned(
              bottom: 20,
              right: 0,
              child: Column(
                children: [
                  if (_showArrowUp)
                    GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(
                          0, // Scroll lên đầu
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 111, 122, 133),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_showArrowDown)
                    GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          // Scroll xuống cuối
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 111, 122, 133),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
