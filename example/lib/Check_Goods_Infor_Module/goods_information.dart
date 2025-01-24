import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rfid_c72_plugin/rfid_c72_plugin.dart';
import 'package:rfid_c72_plugin_example/Check_Goods_Infor_Module/webview_products.dart';
import 'package:rfid_c72_plugin_example/Utils/app_color.dart';
import 'package:rfid_c72_plugin_example/utils/common_functions.dart';
import '../Barcode_Scanner_By_Camera/barcode_scanner_by_camera.dart';
import '../Models/model.dart';
import '../UserDatatypes/user_datatype.dart';
import '../Utils/DeviceActivities/DataProcessing.dart';
import '../Utils/DeviceActivities/DataReadOptions.dart';
import '../Utils/DeviceActivities/connectionNotificationRSeries.dart';
import '../main.dart';
import '../utils/app_config.dart';
import 'barcode_scanner_page.dart';
import 'goods_Information_model.dart';
import '../utils/key_event_channel.dart';

/*CHECK PRODUCT*/
class GoodsInformation extends StatefulWidget {
  @override
  _GoodsInformationState createState() => new _GoodsInformationState();
}

class _GoodsInformationState extends State<GoodsInformation> {
  String _platformVersion = 'Unknown';
  final bool _isHaveSavedData = false;
  final bool _isStarted = false;
  final bool _isEmptyTags = false;
  late AudioPlayer _audioPlayer;
  bool _isConnected = false;
  bool _isLoading = true;
  int _totalEPC = 0, _invalidEPC = 0, _scannedEPC = 0;
  final GlobalKey webViewKey = GlobalKey();
  bool isLoadingAboutBlank = false;
  bool _showHeader = false;
  String scannedCode = '';
  String globalScannedCode = '';
  bool isScan = false;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();
  String defaultUrl = "about:blank";
  String? _lastScannedCode;
  bool _hasData = false;
  bool _scanAttempted = false;
  static bool startScan = false;
  UniqueKey rebuildKey = UniqueKey();

  // String IP = 'http://192.168.19.69:5088';
  // String IP = 'http://192.168.19.180:5088';
  // String IP = 'http://192.168.19.180:5057';
  // String IP = 'https://jvf-admin.rynansaas.com';

  List<TagEpc> r5_resultTags = [];
  bool scanStatusR5 = false;
  StreamSubscription<dynamic>? _barcodeSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    KeyEventChannel(
      onKeyReceived: scanSingleTagAndUpdateWebView,
    ).initialize();
    uhfBLERegister();
  }

  bool isShowingInfo = false;

  void uhfBLERegister() {
    UHFBlePlugin.setMultiTagCallback((tagList) {
      // Listen tag data from R5

      try {
        if (currentDevice != Device.rSeries || tagList.isEmpty) {
          //      print("Not is R5");
          DataReadOptions.readTagsAsync(false, Device.rSeries);
          return;
        }
        isShowingInfo = true;
        r5_resultTags = DataProcessing.ConvertToTagEpcList(tagList);
        String rawScannedCode = r5_resultTags.first.epc;
        scannedCode = CommonFunction().hexToString(rawScannedCode);
        print('Data from R5: $scannedCode');
        if (scannedCode.isNotEmpty && startScan) {
          DataReadOptions.readTagsAsync(false, currentDevice); //stop scan
          //  globalScannedCode = 'RPMK240000478QML'; // Simulate a valid tag;
          print('globalScannedCode: $scannedCode');
          setState(() {
             globalScannedCode = scannedCode;
            rebuildKey = UniqueKey(); // Force rebuild
          });
        }
      } catch (e) {
        print('Error when scanning RFID: $e');
      }
    });
    UHFBlePlugin.setScanningStatusCallback((scanStatus) {
      // key ?
      scanStatusR5 = scanStatus;
      _toggleScanningForR5();
    });
  }

  Future<void> _toggleScanningForR5() async {
    if (currentDevice != Device.rSeries) {
      return;
    }
    //Check device
    if (currentDevice == Device.cameraBarcodes) {
      ConnectionNotificationRSeries.showDeviceWaring(context, false);
      return;
    }

    // Check connection
    var isConnected = await UHFBlePlugin.getConnectionStatus();
    if (mounted && !isConnected) {
      ConnectionNotificationRSeries.showConnectionStatus(context, false);
      return;
    }

    if (startScan) {
      DataReadOptions.readTagsAsync(false, currentDevice); //stop scan
      startScan = false;
    }

    DataReadOptions.readTagsAsync(true, currentDevice); //stop scan
    startScan = true;
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    print('StrDebug: initPlatformState');
    try {
      platformVersion = (await RfidC72Plugin.platformVersion)!;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    RfidC72Plugin.connectedStatusStream
        .receiveBroadcastStream()
        .listen(updateIsConnected);
    RfidC72Plugin.tagsStatusStream.receiveBroadcastStream().listen(updateTags);
    await RfidC72Plugin.connect;
    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
      print('Connection successful');
      _isLoading = false;
    });
  }

  void updateIsConnected(dynamic isConnected) {
    _isConnected = isConnected;
  }

  List<TagEpc> _data = [];
  final List<String> _EPC = [];
  bool _is2dscanCall = false;

  @override
  void dispose() {
    super.dispose();
    //scanSingleTagAndUpdateWebView();
  }

  // void updateTags(dynamic result) {
  //   setState(() {
  //     _data = TagEpc.parseTags(result);
  //     _totalEPC = _data.toSet().toList().length;
  //     if (_data.isNotEmpty) {
  //
  //     }
  //   });
  // }
  Future<void> _playScanSound() async {
    try {
      await _audioPlayer.setAsset('assets/sound/Bip.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("$e");
    }
  }

  void updateTags(dynamic result) {
    setState(() {
      List<TagEpc> newData = TagEpc.parseTags(result); //Convert to TagEpc list
      DataProcessing.ProcessData(newData, _data, _playScanSound); // Filter
      _totalEPC = _data.toSet().toList().length;
    });
  }

  int count = 0;

  void scanSingleTagAndUpdateWebView() async {
    if (currentDevice == Device.rSeries) {
      await _toggleScanningForR5();
    } else if (currentDevice == Device.cameraBarcodes) {
      ConnectionNotificationRSeries.showDeviceWaring(context, false);
      return;
    } else {
      await RfidC72Plugin.stopScan;
      await RfidC72Plugin.closeScan;
      StreamSubscription<dynamic>? subscription;
      try {
        StreamSubscription<dynamic>? subscription = RfidC72Plugin
            .tagsStatusStream
            .receiveBroadcastStream()
            .listen(null);

        subscription.onData((result) async {
          if (result.isNotEmpty) {
            String rawScannedCode = TagEpc.parseTags(result).first.epc;
            scannedCode = CommonFunction().hexToString(rawScannedCode);
            setState(() {
              globalScannedCode = scannedCode;
              rebuildKey = UniqueKey(); // Force rebuild
              // if (kDebugMode) {
              //        // print("Debug: Scanned code infomation: $globalScannedCode");
              //        // if (count % 2 == 0)
              //        //   globalScannedCode = 'RJVD24000047GQML';
              //        // else
              //        //   globalScannedCode = 'RJVD240000478QML';
              // //     }
            });
            //  print('mã được quét: $globalScannedCode');
            // Hủy đăng ký sau khi xử lý kết quả đầu tiên
            subscription.cancel();
          }
        });
        setState(() {
          isScan = true;
          _scanAttempted = true; // Mark that a scan has been attempted
        });
        // Bắt đầu quét một thẻ RFID
        await RfidC72Plugin.startSingle;
      } catch (e) {
        print("Error when scanning RFID: $e");
      }
    }
  }

  Future<void> loadInformationFromScannedCode(String scannedCode) async {
    try {
      // Giả sử đây là hàm gọi API để lấy thông tin sản phẩm dựa trên mã quét
      await getGoodsInformationAccordingToPackageScheduleDetail(scannedCode);
    } catch (e) {
      print("Error loading data for scanned code: $e");
    }
  }

  Future<List<PackageScheduleDetail>>
      getGoodsInformationAccordingToPackageScheduleDetail(
          String scannedCode) async {
    print('Fetching package schedule details');
    List<PackageScheduleDetail> dealers = [];
    final response = await http.get(
      Uri.parse(
          '${AppConfig.IP}/api/7C96C8E10A004D53AF6727D03DD17004/$scannedCode'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      List<dynamic> data = jsonResponse['data'];
      for (var item in data) {
        if (item["16MT"] == "ERROR_0000") {
          dealers.add(PackageScheduleDetail(
              ngaySX: item["11NSX"],
              ngayHeHan: item["3HSD"],
              soLOT: item["7SL"],
              moTa: item["16MT"]));
        }
      }
    } else {
      throw Exception(
          'Failed to load data: HTTP status ${response.statusCode}');
    }
    return dealers;
  }

  Future<List<DistributionScheduleDetail>>
      getGoodsInformationAccordingToDistributionDetail(
          String scannedCode) async {
    // print('Fetching distribution details');
    List<DistributionScheduleDetail> dealers = [];
    final response = await http.get(
      Uri.parse(
          '${AppConfig.IP}/api/BBC047CCA9AB4CA888817F7E5EF51385/$scannedCode'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      List<dynamic> data = jsonResponse['data'];
      for (var item in data) {
        if (item["15MT"] == "ERROR_0000") {
          dealers.add(DistributionScheduleDetail(
              khuVuc: item["2TKV"],
              lenhXH: item["4LXH"],
              ngayPP: item["7NPP"],
              phanPhoiDen: item["2TNPP"],
              phanPhoiBoi: item["2TNPPB"]));
        }
      }
    } else {
      throw Exception(
          'Failed to load data: HTTP status ${response.statusCode}');
    }
    return dealers;
  }

  Future<List<WareHouseDistributionScheduleDetail>>
      getGoodsInformationAccordingToWareHouseDistributionCode(
          String scannedCode) async {
    print('Fetching distribution details');
    List<WareHouseDistributionScheduleDetail> dealers = [];

    final response = await http.get(
      Uri.parse(
          '${AppConfig.IP}/api/87670F9F2DCB4844A657DBA72AFA2782/$scannedCode'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      List<dynamic> data = jsonResponse['data'];
      for (var item in data) {
        if (item["18MT"] == "ERROR_0000") {
          dealers.add(WareHouseDistributionScheduleDetail(
              KTkhuVuc: item["2TKV"],
              KTlenhXH: item["4LXH"],
              KTngayPP: item["7NPP"],
              KTphanPhoiDen: item["2TNPP"],
              KTphanPhoiBoi: item["2TNPPB"]));
        }
      }
    } else {
      throw Exception(
          'Failed to load data: HTTP status ${response.statusCode}');
    }
    return dealers;
  }

  Future<List<RFIDCodeManagement>>
      getGoodsInformationAccordingToRFIDCodeManagement(
          String scannedCode) async {
    print('Starting data fetch');
    List<RFIDCodeManagement> dealers = [];

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.IP}/api/6480825C17ED4B7C9CC69D4A2DC462A7/$scannedCode'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'];
        for (var item in data) {
          dealers.add(RFIDCodeManagement(
            diaChi: item["10ĐC"],
            email: item["11E"],
            SDT: item["3ĐT"],
            nhaSanXuat: item["3TNSX"],
            website: item["2W"],
            gioiThieu: item["5GT"],
            thongTinSP: item["1TTSP"],
            xuatXu: item["2XX"],
            tenSP: item["10TSP"],
            maSP: item["29MSP"],
            hinhAnhSP: item["2HẢ"],
            trangThai: item["30TT"],
          ));
        }
        print(data);
      } else {
        print('Failed to load data: HTTP status ${response.statusCode}');
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error occurred: $e');
      throw Exception('Error fetching data: $e');
    }

    return dealers;
  }

  Future<CombinedProductDetails> fetchAllProductDetails(
      String scannedCode) async {
    try {
      // Execute all fetch operations concurrently
      var packageFuture =
          getGoodsInformationAccordingToPackageScheduleDetail(scannedCode);
      var distributionFuture =
          getGoodsInformationAccordingToDistributionDetail(scannedCode);
      var warehouseFuture =
          getGoodsInformationAccordingToWareHouseDistributionCode(scannedCode);
      var rfidFuture =
          getGoodsInformationAccordingToRFIDCodeManagement(scannedCode);

      // Wait for all futures to complete
      await Future.wait([
        packageFuture,
        distributionFuture,
        warehouseFuture,
        rfidFuture,
      ]);

      // Collect results
      var packageDetails = await packageFuture;
      var distributionDetails = await distributionFuture;
      var warehouseDetails = await warehouseFuture;
      var rfidDetails = await rfidFuture;
      isShowingInfo = false;
      return CombinedProductDetails(
        packageDetails: packageDetails,
        distributionDetails: distributionDetails,
        warehouseDetails: warehouseDetails,
        rfidDetails: rfidDetails,
      );
    } catch (e) {
      throw Exception('Failed to fetch all data: $e');
    }
  }

  Widget buildDetailSections(CombinedProductDetails data) {
    List<Widget> widgets = [];
    widgets.addAll(data.rfidDetails.map((item) {
      List<String> imageUrls =
          item.hinhAnhSP != null && item.hinhAnhSP!.isNotEmpty
              ? item.hinhAnhSP!.map((img) => '${AppConfig.IP}' + img).toList()
              : [];

      PageController _pageController = PageController(initialPage: 0);
      Timer? _timer;

      // Khởi tạo timer để tự động chuyển trang
      void _startAutoSlide() {
        if (imageUrls.length > 1) {
          _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
            if (_pageController.hasClients) {
              int nextPage = _pageController.page!.toInt() + 1;
              if (nextPage >= imageUrls.length) {
                nextPage = 0;
              }
              _pageController.animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }

      // Hủy timer khi không cần thiết để tránh rò rỉ bộ nhớ
      void _stopAutoSlide() {
        _timer?.cancel();
      }

      // Bắt đầu tự động trượt khi widget được khởi tạo
      if (imageUrls.length > 1) {
        _startAutoSlide();
      }

      return Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.fromLTRB(5, 5, 5, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFEEEEEE),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                borderRadius: BorderRadius.circular(5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrls.isEmpty
                    ? const Center(
                        heightFactor: 10,
                        child: Text(
                          'Không có hình ảnh',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : Stack(
                        children: [
                          Container(
                            height: 300, // Adjust height as needed
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) {
                                String imageUrl = imageUrls[index];
                                return Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: MediaQuery.of(context).size.width,
                                  loadingBuilder: (BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                AppColor.mainText),
                                      ),
                                    );
                                  },
                                  errorBuilder: (BuildContext context,
                                      Object exception,
                                      StackTrace? stackTrace) {
                                    return const Center(
                                      child: Text(
                                        'Hình ảnh xảy ra lỗi',
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.grey),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          if (imageUrls.length > 1) ...[
                            Positioned(
                              left: 0,
                              top: 130,
                              bottom: 130,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios,
                                    color: Colors.grey),
                                onPressed: () {
                                  _stopAutoSlide();
                                  if (_pageController.hasClients) {
                                    _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                  _startAutoSlide();
                                },
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 130,
                              bottom: 130,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios,
                                    color: Colors.grey),
                                onPressed: () {
                                  _stopAutoSlide();
                                  if (_pageController.hasClients) {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                  _startAutoSlide();
                                },
                              ),
                            ),
                          ]
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
    }));

    widgets.add(Container(
        padding: const EdgeInsets.all(10),
        // Khoảng cách bên trong giữa viền và hình ảnh
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
        // Khoảng cách bên ngoài giữa container và các widget xung quanh
        decoration: BoxDecoration(
          color: Colors.white,
          // Màu nền của container, nên thiết lập để đổ bóng hiển thị rõ ràng
          border: Border.all(
            color: const Color(0xFFEEEEEE), // Màu viền
            width: 1.0, // Độ dày của viền
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5), // Màu đổ bóng
              spreadRadius: 1, // Phạm vi mà đổ bóng sẽ lan rộng
              blurRadius: 10, // Độ mờ của đổ bóng
              offset: const Offset(0, 5), // Vị trí đổ bóng, x và y
            ),
          ],
          borderRadius: BorderRadius.circular(5), // Bo góc của container
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...data.rfidDetails.map((item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${item.tenSP ?? ' '} (${item.maSP ?? ' '})",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF379BD1))),
                    Text("(Mã EPC: $globalScannedCode)",
                        style: const TextStyle(
                            fontSize: 18,
                            // fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ],
                )),
            if (data.packageDetails.isNotEmpty)
              ...data.packageDetails.map((item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Giả sử ngaySX là chuỗi đúng định dạng
                    children: [
                      Row(
                        children: [
                          const Text("Ngày sản xuất: ",
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF777777))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                item.ngaySX != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(DateTime.parse(item.ngaySX!))
                                    : '',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text("Ngày hết hạn:",
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF777777))),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text("Xem trên bao bì",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      Row(
                        children: [
                          const Text("Số lô:",
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF777777))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(item.soLOT ?? ' ',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Row(
                        children: [
                          Text("Xuất Xứ:",
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF777777))),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text("Việt Nam",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  )),
            if (data.packageDetails.isEmpty)
              ...data.packageDetails.map(
                (item) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Ngày sản xuất: ",
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF777777))),
                        SizedBox(width: 10),
                      ],
                    ),
                    Row(
                      children: [
                        Text("Ngày hết hạn:",
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF777777))),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text("Xem trên bao bì",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Row(
                      children: [
                        Text("Số lô:",
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF777777))),
                        SizedBox(width: 10),
                      ],
                    ),
                    Row(
                      children: [
                        Text("Xuất Xứ:",
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF777777))),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text("Việt Nam",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              )
          ],
        )));

    widgets.addAll(data.distributionDetails.map((item) => Container(
          padding: const EdgeInsets.all(10),
          // Khoảng cách bên trong giữa viền và hình ảnh
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
          // Khoảng cách bên ngoài giữa container và các widget xung quanh
          decoration: BoxDecoration(
            color: Colors.white,
            // Màu nền của container, nên thiết lập để đổ bóng hiển thị rõ ràng
            border: Border.all(
              color: const Color(0xFFEEEEEE), // Màu viền
              width: 1.0, // Độ dày của viền
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5), // Màu đổ bóng
                spreadRadius: 1, // Phạm vi mà đổ bóng sẽ lan rộng
                blurRadius: 10, // Độ mờ của đổ bóng
                offset: const Offset(0, 5), // Vị trí đổ bóng, x và y
              ),
            ],
            borderRadius: BorderRadius.circular(5), // Bo góc của container
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PHÂN PHỐI",
                  style: TextStyle(fontSize: 20, color: Color(0xFF379BD1))),
              Text(
                "Ngày phân phối: ${item.ngayPP != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item.ngayPP!)) : ' '}",
                style: const TextStyle(fontSize: 16, color: Color(0xFF777777)),
              ),
              Row(
                children: [
                  const Text("Lệnh giao hàng:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(" ${item.lenhXH}",
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Phân phối bởi:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.phanPhoiBoi ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Phân phối đến:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.phanPhoiDen ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Khu vực:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.khuVuc ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
            ],
          ),
        )));
    //
    widgets.addAll(data.warehouseDetails.map((item) => Container(
          padding: const EdgeInsets.all(10),
          // Khoảng cách bên trong giữa viền và hình ảnh
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
          // Khoảng cách bên ngoài giữa container và các widget xung quanh
          decoration: BoxDecoration(
            color: Colors.white,
            // Màu nền của container, nên thiết lập để đổ bóng hiển thị rõ ràng
            border: Border.all(
              color: const Color(0xFFEEEEEE), // Màu viền
              width: 1.0, // Độ dày của viền
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5), // Màu đổ bóng
                spreadRadius: 1, // Phạm vi mà đổ bóng sẽ lan rộng
                blurRadius: 10, // Độ mờ của đổ bóng
                offset: const Offset(0, 5), // Vị trí đổ bóng, x và y
              ),
            ],
            borderRadius: BorderRadius.circular(5), // Bo góc của container
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PHÂN PHỐI KHO THUÊ",
                  style: TextStyle(fontSize: 20, color: Color(0xFF379BD1))),
              Row(
                children: [
                  const Text("Ngày phân phối:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (item.KTngayPP != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(DateTime.parse(item.KTngayPP!))
                          : ''),
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF777777)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("Lệnh giao hàng:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.KTlenhXH ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Phân phối bởi :",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.KTphanPhoiBoi ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Phân phối đến:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.KTphanPhoiDen ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
              Row(
                children: [
                  const Text("Khu vực:",
                      style: TextStyle(fontSize: 16, color: Color(0xFF777777))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.KTkhuVuc ?? '',
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF337ab7))),
                  )
                ],
              ),
            ],
          ),
        )));

    Widget htmlContent(String htmlData) {
      return Html(
        data: htmlData,
        style: {
          "p": Style(
            textAlign: TextAlign.justify,
            fontSize: FontSize(16.0),
            color: Colors.black,
          ),
          "strong": Style(fontWeight: FontWeight.bold),
          "span": Style(color: Colors.black),
        },
      );
    }

    widgets.addAll(data.rfidDetails.map((item) => Container(
          padding: const EdgeInsets.all(10),

          margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFEEEEEE),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5), // Màu đổ bóng
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            borderRadius: BorderRadius.circular(5),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("THÔNG TIN SẢN PHẨM",
                  style: TextStyle(fontSize: 20, color: Color(0xFF379BD1))),
              htmlContent(item.thongTinSP ?? ''),
              // Đây là widget Html, không phải widget Text
            ],
          ),
        )));

    widgets.addAll(data.rfidDetails.map((item) => Container(
          padding: const EdgeInsets.all(10),
          // Khoảng cách bên trong giữa viền và hình ảnh
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
          // Khoảng cách bên ngoài giữa container và các widget xung quanh
          decoration: BoxDecoration(
            color: Colors.white,
            // Màu nền của container, nên thiết lập để đổ bóng hiển thị rõ ràng
            border: Border.all(
              color: const Color(0xFFEEEEEE), // Màu viền
              width: 1.0, // Độ dày của viền
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5), // Màu đổ bóng
                spreadRadius: 1, // Phạm vi mà đổ bóng sẽ lan rộng
                blurRadius: 10, // Độ mờ của đổ bóng
                offset: const Offset(0, 5), // Vị trí đổ bóng, x và y
              ),
            ],
            borderRadius: BorderRadius.circular(5), // Bo góc của container
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("CÔNG TY SẢN XUẤT",
                  style: TextStyle(fontSize: 20, color: Color(0xFF379BD1))),
              const SizedBox(
                height: 10,
              ),
              Text(item.nhaSanXuat ?? '',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF379BD1),
                      fontWeight: FontWeight.bold)),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFF379BD1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Địa chỉ: ",
                            style: TextStyle(
                                fontSize: 16,
                                color:
                                    Color(0xFF777777)), // Set color for label
                          ),
                          TextSpan(
                            text: item.diaChi ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(
                                    0xFF1f2b3d)), // Set a different color for email
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, color: Color(0xFF379BD1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Số điện thoại: ",
                            style: TextStyle(
                                fontSize: 16,
                                color:
                                    Color(0xFF777777)), // Set color for label
                          ),
                          TextSpan(
                            text: item.SDT ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(
                                    0xFF379BD1)), // Set a different color for email
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: Color(0xFF379BD1)),
                  const SizedBox(width: 10),
                  // Expanded(child: Text("Email: ${item.email}", style: TextStyle(fontSize: 16))),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Email: ",
                            style: TextStyle(
                                fontSize: 16,
                                color:
                                    Color(0xFF777777)), // Set color for label
                          ),
                          TextSpan(
                            text: item.email ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(
                                    0xFF379BD1)), // Set a different color for email
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  const Icon(Icons.web, color: Color(0xFF379BD1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Website: ",
                            style: TextStyle(
                                fontSize: 16,
                                color:
                                    Color(0xFF777777)), // Set color for label
                          ),
                          TextSpan(
                            text: item.website ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(
                                    0xFF379BD1)), // Set a different color for email
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )));
    return Column(children: widgets);
  }

  void _showDeviceSelectionModal(BuildContext context) {
    print('Screen sizeL ${MediaQuery.of(context).size.width}');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                "Chọn phương pháp quét mã",
                style: TextStyle(fontSize: MediaQuery.of(context).size.width *0.06, fontWeight: FontWeight.bold, color: AppColor.mainText),
              ),
              const SizedBox(height: 16),
              Container(
                color: Colors.grey[200], // Add background color here
                child: ListTile(
                  leading:
                      const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  title: const Text(
                    "Quét QR",
                    style: TextStyle(fontSize: 18, color: AppColor.mainText,fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Chế độ quét Barcodes"),
                  onTap: () {
                    Navigator.pop(context); // Close the modal
                    if (kDebugMode) {
                      print("Camera Selected");
                    }
                    Future.delayed(const Duration(seconds: 1), () {
                      _toggleBarCodeScanning();
                      scanQRCodeByCamera();
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                color: Colors.grey[200],
                child: ListTile(
                  leading: const Icon(Icons.rss_feed, color: Colors.green),
                  title: const Text(
                    "Quét RFID",
                    style: TextStyle(fontSize: 18,color: AppColor.mainText, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Chế độ quét RFID."),
                  onTap: () {
                    Navigator.pop(context); // Close the modal
                    if (kDebugMode) {
                      print("External Device Selected");
                    }
                    // Navigate or call the external device scanner logic here
                    Future.delayed(const Duration(seconds: 1), () {
                      scanWithButton();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the modal
                },
                child: const Text(
                  "Hủy",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void scanWithButton() {
    setState(() {
      _isLoading = true;
    });
    scanSingleTagAndUpdateWebView();

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  final BarcodeScannerInPhoneController _barcodeScannerInPhoneController =
      BarcodeScannerInPhoneController();

  void scanQRCodeByCamera() async {
    if (currentDevice != Device.rSeries) {
      return;
    }
    try {
      //Disconnect Scanner before
      if (await RfidC72Plugin.isConnected == true) {
        await RfidC72Plugin.stop;
        await RfidC72Plugin.closeScan;
      }
      String? code = await _barcodeScannerInPhoneController.scanQRCode();
      if (code != null) {
        _updateUIWithQRCode(code);
      } else {}
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  String? _extractCodeFromUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.queryParameters['id']; // Trả về phần mã phía sau `id=`
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing URL: $e");
      }
      return null;
    }
  }


  void _updateUIWithQRCode(String code) async {
    if (!mounted) return;
    setState(() {
      globalScannedCode = _extractCodeFromUrl(code)!;
      rebuildKey = UniqueKey();
    });
      _playScanSound();

  }

  String? extractedCode;

  //#region Barcode scanner QR
  void updateBarcodeTags(dynamic result) async {
    if (result.toString().startsWith('http') ||
        result.toString().contains('://')) {
      extractedCode = _extractCodeFromUrl(result);
      if (extractedCode != null) {
        setState(() {
          globalScannedCode = extractedCode!;
          rebuildKey = UniqueKey();
        });
        _playScanSound();
      }
    } else {
      if (result != null) {
        setState(() {
          globalScannedCode = result.toString();
          rebuildKey = UniqueKey();
        });
        _playScanSound();
      }
    }
  }

  Future<void> _toggleBarCodeScanning() async {
    if (currentDevice == Device.cameraBarcodes ||
        currentDevice == Device.rSeries) {
      return;
    }
    try {
      RfidC72Plugin.barcodeStatusStream
          .receiveBroadcastStream()
          .listen(updateBarcodeTags);

      if (_is2dscanCall) {
        await RfidC72Plugin.stopScan;
        await RfidC72Plugin.closeScan;
        _is2dscanCall = false;
      }

      await RfidC72Plugin.connectBarcode;
      var isScanned = await RfidC72Plugin.scanBarcode;
      // if (isScanned == false) {
      //   await RfidC72Plugin.stopScan;
      //   await RfidC72Plugin.closeScan;
      // }
      _is2dscanCall = true;

      if (extractedCode != null) {
        if (kDebugMode) {
          print("Received code: $extractedCode");
        }
        // await RfidC72Plugin.stopScan;
        // await RfidC72Plugin.closeScan;
      }
      // Cancel event
      if (_barcodeSubscription != null) {
        await RfidC72Plugin.stopScan;
        await RfidC72Plugin.closeScan;
        await _barcodeSubscription?.cancel();
        _barcodeSubscription = null;
        _is2dscanCall = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  //#endregion Barcode scanner QR

  @override
  Widget build(BuildContext context) {
    print("Rebuil webpage");
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Ensure globalScannedCode is valid

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Thông tin sản phẩm",
          style: TextStyle(
            color: AppColor.mainText,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.061,
          ),
        ),
        actions: [
          // IconButton(
          //
          //   icon: Image.asset('assets/image/scan_noBG.png'),
          //   onPressed: () {
          //     _showDeviceSelectionModal(context);
          //     // setState(() {
          //     //   _isLoading = true;
          //     // });
          //     // scanSingleTagAndUpdateWebView();
          //     //
          //     // Future.delayed(const Duration(seconds: 1), () {
          //     //   setState(() {
          //     //     _isLoading = false;
          //     //   });
          //     // });
          //   },
          // ),
          IconButton(
            icon: Container(
              width: 60, // Set the width of the container (same as the image size or slightly larger)
              height: 50, // Set the height of the container
              decoration: BoxDecoration(
                color:  Colors.white60,
                border: Border.all(
                  color: AppColor.mainText, // Border color
                  width: 2, // Border width
                ),
                borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
              ),
              child: Image.asset(
                'assets/image/scan_noBG.png',
                fit: BoxFit.contain, // Adjusts the image to fit within the container
              ),
            ),
            onPressed: () {
              _showDeviceSelectionModal(context);
            },
          ),
        ],
      ),
      body: Center(
        child: globalScannedCode.isNotEmpty
            ? WebviewProducts(key: rebuildKey, product_id: globalScannedCode)
            : Text(
                globalScannedCode.isNotEmpty
                    ? "Scanned Code: $globalScannedCode"
                    : "Nhấn nút để quét mã!",
                style: const TextStyle(fontSize: 16),
              ), // Show loading while waiting for the code
      ),
    );

    // return WebviewProducts(
    //     key: ValueKey(globalScannedCode), // Key thay đổi mỗi khi `globalScannedCode` thay đổi
    //     product_id: globalScannedCode);
    // return Scaffold(
    //   appBar: AppBar(
    //     title: Text(
    //       "Thông tin sản phẩm",
    //       style: TextStyle(
    //         color: AppColor.mainText,
    //         fontWeight: FontWeight.bold,
    //         fontSize: screenWidth * 0.07,
    //       ),
    //     ),
    //     actions: [
    //       IconButton(
    //         icon: Image.asset('assets/image/scan_noBG.png'),
    //         onPressed: () {
    //           setState(() {
    //             _isLoading = true;
    //           });
    //           scanSingleTagAndUpdateWebView();
    //
    //           Future.delayed(const Duration(seconds: 1), () {
    //             setState(() {
    //               _isLoading = false;
    //             });
    //           });
    //         },
    //       ),
    //     ],
    //   ),
    //   body: ListView(
    //     children: <Widget>[
    //       if (isScan)
    //         Container(
    //           height: screenHeight * 0.1,
    //           color: const Color(0xFF274452),
    //           child: Row(
    //             mainAxisAlignment: MainAxisAlignment.start,
    //             children: [
    //               Padding(
    //                 padding: const EdgeInsets.only(left: 10),
    //                 child: Image.asset(
    //                   'assets/image/logoJVF_RFID.png',
    //                   width: screenWidth * 0.14, // 50% của chiều rộng màn hình
    //                   height: screenHeight * 0.8,
    //                 ),
    //               ),
    //               const SizedBox(
    //                 width: 10,
    //               ),
    //               Expanded(
    //                 child: RichText(
    //                   text: const TextSpan(
    //                     children: [
    //                       TextSpan(
    //                         text: 'CÔNG TY PHÂN BÓN\n',
    //                         style: TextStyle(
    //                           color: Color(0xFF888787),
    //                           fontSize: 18,
    //                         ),
    //                       ),
    //                       WidgetSpan(
    //                         child: Padding(
    //                           padding: EdgeInsets.only(left: 10.0),
    //                         ),
    //                       ),
    //                       TextSpan(
    //                         text: 'VIỆT NHẬT (JVF)',
    //                         style: TextStyle(
    //                           color: Color(0xFF19C37B),
    //                           fontSize: 20,
    //                           fontWeight: FontWeight.bold,
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       FutureBuilder<CombinedProductDetails>(
    //         future: fetchAllProductDetails(globalScannedCode),
    //         builder: (context, snapshot) {
    //           if (snapshot.connectionState == ConnectionState.waiting) {
    //             return const Center(
    //                 child: CircularProgressIndicator(
    //               valueColor: AlwaysStoppedAnimation<Color>(AppColor.mainText),
    //             ));
    //           } else if (snapshot.hasError) {
    //             String errorMessage = "Đã xảy ra lỗi. Vui lòng thử lại.";
    //             if (snapshot.error.toString().contains("SocketException")) {
    //               // errorMessage = "Không có kết nối Internet. Vui lòng kiểm tra lại kết nối của bạn.";
    //               return Container(
    //                 margin: const EdgeInsets.only(top: 50),
    //                 // Adjust top margin as needed
    //                 child: const Center(
    //                   child: Column(
    //                     mainAxisSize: MainAxisSize.min,
    //                     // Makes the column's height fit its children
    //                     children: <Widget>[
    //                       Text('KHÔNG CÓ INTERNET.',
    //                           style:
    //                               TextStyle(fontSize: 18, color: Colors.grey)),
    //                       Text('VUI LÒNG KIỂM TRA LẠI KẾT NỐI!',
    //                           style:
    //                               TextStyle(fontSize: 18, color: Colors.grey))
    //                     ],
    //                   ),
    //                 ),
    //               );
    //             }
    //             return Container(
    //               margin: const EdgeInsets.only(top: 50),
    //               // Adjust the top margin as needed
    //               child: const Center(
    //                 child: Text("KHÔNG TÌM THẤY THÔNG TIN",
    //                     style: TextStyle(fontSize: 18, color: Colors.grey)),
    //               ),
    //             );
    //           } else if (snapshot.hasData) {
    //             bool hasContent = snapshot.data!.packageDetails.isNotEmpty ||
    //                 snapshot.data!.distributionDetails.isNotEmpty ||
    //                 snapshot.data!.warehouseDetails.isNotEmpty ||
    //                 snapshot.data!.rfidDetails.any(
    //                     (item) => item.maSP != null && item.maSP!.isNotEmpty);
    //             bool hasValidMaSP = snapshot.data!.rfidDetails
    //                 .any((item) => item.maSP != null && item.maSP!.isNotEmpty);
    //             bool hasValidRecallStatus = snapshot.data!.rfidDetails
    //                 .any((item) => item.trangThai == "TT012");
    //             bool hasValidReplaceStatus = snapshot.data!.rfidDetails
    //                 .any((item) => item.trangThai == "TT017");
    //             if (hasValidRecallStatus) {
    //               return Container(
    //                 margin: const EdgeInsets.only(top: 50),
    //                 // Adjust the top margin as needed
    //                 child: const Center(
    //                   child: Text("Mã vạch đã thu hồi",
    //                       style: TextStyle(fontSize: 18, color: Colors.grey)),
    //                 ),
    //               );
    //             } else if (hasValidReplaceStatus) {
    //               return Container(
    //                 margin: const EdgeInsets.only(top: 50),
    //                 // Adjust the top margin as needed
    //                 child: const Center(
    //                   child: Text("Mã vạch đã thu hồi thay thế",
    //                       style: TextStyle(fontSize: 18, color: Colors.grey)),
    //                 ),
    //               );
    //             } else if (hasContent) {
    //               return SingleChildScrollView(
    //                 child: buildDetailSections(snapshot.data!),
    //               );
    //             } else if (_scanAttempted && !hasValidMaSP) {
    //               return Container(
    //                 margin: const EdgeInsets.only(top: 50),
    //                 // Adjust the top margin as needed
    //                 child: const Center(
    //                   child: Text("KHÔNG TÌM THẤY THÔNG TIN",
    //                       style: TextStyle(fontSize: 18, color: Colors.grey)),
    //                 ),
    //               );
    //             }
    //           }
    //
    //           return Container();
    //         },
    //       )
    //     ],
    //   ),
    // );
  }
}
