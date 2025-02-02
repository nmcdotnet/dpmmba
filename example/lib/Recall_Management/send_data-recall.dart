import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rfid_c72_plugin/rfid_c72_plugin.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'dart:collection';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rfid_c72_plugin_example/utils/common_functions.dart';
import 'dart:async';
import '../Assign_Packing_Information/model_information_package.dart';
import '../Barcode_Scanner_By_Camera/barcode_scanner_by_camera.dart';
import '../UserDatatypes/user_datatype.dart';
import '../Utils/DeviceActivities/DataProcessing.dart';
import '../Utils/DeviceActivities/DataReadOptions.dart';
import '../Utils/DeviceActivities/connectionNotificationRSeries.dart';
import '../Utils/app_color.dart';
import '../main.dart';
import '../utils/app_config.dart';
import 'database_recall.dart';
import 'model_recall_manage.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/scan_count_modal.dart';
import '../utils/key_event_channel.dart';

/* QUAN LY THU HOI */

class SendDataRecall extends StatefulWidget {
  final CalendarRecall event;
  final Function(CalendarRecall) onDeleteEvent;
  final bool isSurplusGoodRecall;

  const SendDataRecall(
      {Key? key, required this.event, required this.onDeleteEvent, required this.isSurplusGoodRecall})
      : super(key: key);

  @override
  State<SendDataRecall> createState() => _SendDataRecallState();
}

class _SendDataRecallState extends State<SendDataRecall> {
  final StreamController<int> _updateStreamController =
      StreamController<int>.broadcast(); // Tạo StreamController
  late CalendarRecall event;
  final CalendarRecallDatabaseHelper databaseHelper =
      CalendarRecallDatabaseHelper();
  final bool _isHaveSavedData = false;
  final bool _isStarted = false;
  final bool _isEmptyTags = false;
  bool _isConnected = false;
  bool _isLoading = true;
  int _totalEPC = 0, _invalidEPC = 0, _scannedEPC = 0;
  int currentPage = 0;
  int itemsPerPage = 5;
  late CalendarRecallDatabaseHelper _databaseHelper;
  List<TagEpcLDB> paginatedData = [];
  int targetTotalEPC = 100;
  late Timer _timer;
  final TextEditingController _agencyNameController = TextEditingController();
  final TextEditingController _goodsNameController = TextEditingController();
  bool confirm = false;
  final List<TagEpcLDB> _data = [];
  final List<String> _EPC = [];
  List<TagEpcLDB> _successfulTags = [];
  int totalTags = 0;
  static int _value = 0;
  int successfullySaved = 0;
  int previousSavedCount = 0;
  bool isScanning = false;
  Queue<List<TagEpcLDB>> p = Queue<List<TagEpcLDB>>();
  bool _isNotified = false;
  bool _isShowModal = false;
  List<TagEpcLDB> newData = [];
  int saveCount = 0;
  int a = 0;
  int TotalScan = 0;
  bool _is2dscanCall = false;
  int scannedTagsCount = 0;
  final _storage = const FlutterSecureStorage();
  String _selectedAgencyName = '';
  String _selectedGoodsName = '';
  int tagCount = 0;
  List<String> tagsList = [];
  bool _isContinuousCall = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool dadongbao = false;

  Stream<int> get updateStream => _updateStreamController.stream;
  bool _isSnackBarDisplayed = false;
  int successCountRecall = 0;
  int failCountRecall = 0;
  int _saveCounter = 0; // Biến toàn cục để theo dõi số lần lưu
  final secureRecallStorage = const FlutterSecureStorage();
  final secureStorage = const FlutterSecureStorage();
  final _storageAcountCode = const FlutterSecureStorage();
  final secureLTHStorage = const FlutterSecureStorage();
  bool dadongbo = false;
  bool _isDialogShown = false;
  bool _isDialogBarcodeShown = false;
  bool showConfirmationDialog = false;
  String _selectedScanningMethod = 'rfid';
  bool isRecallScan = false; // Mặc định là quét mã thu hồi
  final _storageRecallReplace = const FlutterSecureStorage();
  int tagRecallReplaceCount = 0;
  List<String> tagRecallReplaceList = [];
  String extractedCode = '';
  bool _isClickRFIDMenthod = false;
  bool _isClickConfirmScanMethod = false;
  bool isShowDuplicateTagDialog = false;

  // String IP = 'http://192.168.19.69:5088';
  // String IP = 'http://192.168.19.180:5088';
  // String IP = 'https://jvf-admin.rynansaas.com';

  final BarcodeScannerInPhoneController _barcodeScannerInPhoneController =
      BarcodeScannerInPhoneController();
  List<TagEpcLDB> r5_resultTags = [];
  bool scanStatusR5 = false;
  String getResult = '';
  String? result;

  @override
  void initState() {
    super.initState();
    event = widget.event;
    _databaseHelper = CalendarRecallDatabaseHelper();
    _initDatabase();
    initPlatformState();
    loadSuccessfullySaved(event.idLTH);
    _agencyNameController.text = _selectedAgencyName;
    _goodsNameController.text = _selectedGoodsName;
    loadTagCount();
    loadRecallReplaceTagCount();
    KeyEventChannel(
      onKeyReceived: checkCurrentDevice,
    ).initialize();
    uhfBLERegister();
  }


  Future<void> checkCurrentDevice() async {
    if (currentDevice == Device.cSeries) {
      await _toggleBarCodeScanning();
      await _toggleScanningForC5();
    } else if (currentDevice == Device.rSeries) {
      await _toggleScanningForR5();
    } else if (currentDevice == Device.cameraBarcodes) {
      await _toggleScanningForR5();
      await _toggleScanningForC5();
    }
  }

  void uhfBLERegister() {
    UHFBlePlugin.setMultiTagCallback((tagList) {
      // Listen data from R5
      setState(() async {
        if (currentDevice != Device.rSeries) return;
        r5_resultTags = DataProcessing.ConvertToTagEpcLDBList(tagList);
        List<TagEpcLDB> currentTags = await loadData(event.idLTH);
        DataProcessing.ProcessDataLDB(
            r5_resultTags, currentTags, _data, _playScanSound); // Filter
        print('Data from R5: ${r5_resultTags.length}');
        updateStatusAndCountResult();
      });
    });
    UHFBlePlugin.setScanningStatusCallback((scanStatus) {
      scanStatusR5 = scanStatus;
      _toggleScanningForR5();
    });
  }

//#endregion R_Series Register Tag Read

  Future<void> _initDatabase() async {
    await _databaseHelper.initDatabase();
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamController.close();
    closeAll();
    closeBarcodeAll();
  }

  closeAll() {
    RfidC72Plugin.close;
  }

  closeBarcodeAll() {
    RfidC72Plugin.closeScan;
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
    // if(!_isClickQRMenthod){
    RfidC72Plugin.tagsStatusStream.receiveBroadcastStream().listen(updateTags);
    // }
    // if(_selectedScanningMethod == 'rfid'){
    //   RfidC72Plugin.barcodeStatusStream.receiveBroadcastStream().listen(updateBarcodeTags);
    // }
    await RfidC72Plugin.connect;
    // await RfidC72Plugin.connectBarcode; //connect barcode
    await _initDatabase();
    if (!mounted) return;
    setState(() {
      print('Connection successful');
      _isLoading = false;
    });
  }

  Future<void> _playScanSound() async {
    try {
      await _audioPlayer.setAsset('assets/sound/Bip.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("$e");
    }
  }

//.....................................22.03.24.15:59..............................//

  void scanQRCodeByCamera() async {
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
      print('Error: $e');
    }
  }

  // Cập nhật UI với mã QR đã quét
  void _updateUIWithQRCode(String code) async {
    if (!mounted) return; // Kiểm tra xem widget có còn tồn tại trong tree không
    setState(() {
      result = _extractCodeFromUrl(code); // Cập nhật mã QR đã quét
      // getResult = 'TH000002'; // Cập nhật mã QR đã quét
    });
    print("QrCode result: --$code");
    if (String != null) {
      _playScanSound();
      setState(() {
        _data.add(TagEpcLDB(epc: result!));
      });
      await _showBarcodeConfirmationDialog();
      // bool confirmed = await showDialog(
      //   context: context,
      //   builder: (BuildContext context) {
      //     return QRCodeConfirmationDialog(
      //       qrCode: getResult,  // Truyền mã QR vào
      //     );
      //   },
      // );
      // if (confirmed) {
      //   Navigator.pop(context, getResult); // Trả về mã QR đã quét
      // }
    }
  }

  void updateTags(dynamic result) async {
    List<TagEpcLDB> currentTags = await loadData(event.idLTH);
    List<TagEpcLDB> newData =
        TagEpcLDB.parseTags(result); //Convert to TagEpc list
    print("MinhChau: data get : ${newData.length}");
    DataProcessing.ProcessDataLDB(
        newData, currentTags, _data, _playScanSound); // Filter
    updateStatusAndCountResult();

    //  List<TagEpcLBD> newData = TagEpcLBD.parseTags(result);
    // // print("MinhChau: data get : ${_data.first.epc}");
    //  List<TagEpcLBD> currentTags = await loadData(event.idLTH);
    //  List<TagEpcLBD> uniqueData = newData.where((newTag) =>
    //  !currentTags.any((savedTag) => savedTag.epc == newTag.epc) &&
    //      !_data.any((existingTag) => existingTag.epc == newTag.epc)).toList();
    //   uniqueData.forEach((tag) {
    //     tag.scanDate = DateTime.now();  // Gán thời gian quét cho thẻ
    //   });
    //
    //   if (!uniqueData.isEmpty) {
    //     _playScanSound();
    //   }
    //  _data.addAll(uniqueData);
    //   setState(() {
    //     isScanning = true;
    //     successfullySaved = _data.length; // Cập nhật trạng thái
    //   });
    //    sendUpdateEvent(successfullySaved);
  }

  void updateStatusAndCountResult() {
    setState(() {
      isScanning = true;
      successfullySaved = _data.length; // Cập nhật trạng thái
    });
    sendUpdateEvent(successfullySaved);
  }

  void updateBarcodeTags(dynamic result) async {
    if (isShowDuplicateTagDialog == true) {
      return;
    }
    if (result.toString().startsWith('http') ||
        result.toString().contains('://')) {
      String? extractedCode = _extractCodeFromUrl(result);

      if (extractedCode != null) {
        List<TagEpcLDB> currentTags = await loadData(event.idLTH);
        bool isDuplicate =
            currentTags.any((savedTag) =>  CommonFunction().hexToString(savedTag.epc) == extractedCode);
        if (isDuplicate) {
          isShowDuplicateTagDialog = true;
          _showDuplicateTagDialog();
        } else {

          _data.add(TagEpcLDB(epc: extractedCode));
          _playScanSound();

          if (mounted) {
            setState(() {
              isScanning = false;
              successfullySaved = _data.length;
            });
          }
          sendUpdateEvent(successfullySaved);
          await RfidC72Plugin.stop;
          setState(() {
            _isContinuousCall = false;
          });
          await _showBarcodeConfirmationDialog();
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }
    }
  }

  void _showDuplicateTagDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Mã quét đã tồn tại.',
            style: TextStyle(
                color: AppColor.mainText, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Mã đã tồn tại trong danh sách. Vui lòng quét quét mã khác!',
            style: TextStyle(
              color: AppColor.mainText,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child:
                  const Text('OK', style: TextStyle(color: AppColor.mainText)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      // isShowDuplicateTagDialog = true;
    });
    isShowDuplicateTagDialog = false;
  }

  Future<void> saveSuccessfullySaved(String eventId, int value) async {
    final secureStorage = const FlutterSecureStorage();
    await secureStorage.write(
        key: '${eventId}_length', value: value.toString());
  }

  Future<void> loadSuccessfullySaved(String eventId) async {
    String? savedLength = await _storage.read(key: '${eventId}_length');
    if (savedLength != null) {
      setState(() {
        successfullySaved = int.parse(savedLength);
      });
    }
  }

  void sendUpdateEvent(int value) {
    _updateStreamController.add(value);
  }

  void onDataReceived(int newData) {
    sendUpdateEvent(newData);
  }

// Hàm để dừng timer
  void stopTimer() {
    _timer.cancel(); // Hủy timer
  }

  Future<void> saveData(String key, List<TagEpcLDB> data) async {
    // Chuyển đổi danh sách tags thành chuỗi JSON sử dụng phương thức toMap()
    String dataString = TagEpcLDB.tagsToJson(data);
    await _storage.write(key: key, value: dataString);
  }

  Future<List<TagEpcLDB>> loadData(String key) async {
    String? dataString = await _storage.read(key: key);
    if (dataString != null) {
      // Sử dụng parseTags để chuyển đổi chuỗi JSON thành danh sách TagEpcLBD
      return TagEpcLDB.parseTags(dataString);
    }
    return [];
  }

  Future<void> stopScanning() async {
    if (!_isSnackBarDisplayed) {
      await RfidC72Plugin.stop;
      _showSnackBar('Đã đạt đủ số lượng');
      _isSnackBarDisplayed = true;
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void updateIsConnected(dynamic isConnected) {
    _isConnected = isConnected;
    print(' successful');
  }

  void deleteEventFromCalendar() async {
    try {
      final dbHelper = CalendarRecallDatabaseHelper();

      await dbHelper.deleteEvent(event);
      widget.onDeleteEvent(event);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xóa lịch thành công!'),
          backgroundColor: Color(0xFF4EB47D),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Lỗi khi xóa lichj: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xảy ra lỗi khi xóa lịch!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  bool isHexadecimal(String epc) {
    final hexRegex = RegExp(
        r'^[0-9A-Fa-f]+$'); // Kiểm tra chuỗi chỉ chứa ký tự từ 0-9 và A-F (cả chữ hoa và thường)
    return hexRegex.hasMatch(epc);
  }

  void _showChipInformation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin chip',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColor.mainText,
                  ),
                ),
                FutureBuilder<List<TagEpcLDB>>(
                  future: loadData(event.idLTH),
                  // Sử dụng loadData với event.id
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          var tag = snapshot.data![index];

                          // Kiểm tra xem mã có phải là dạng hexadecimal không
                          String displayString = isHexadecimal(tag.epc)
                              ? CommonFunction().hexToString(
                                  tag.epc) // Nếu là dạng hex, chuyển đổi
                              : tag.epc; // Nếu không, hiển thị nguyên bản

                          return ListTile(
                            title: Text(
                              '${index + 1}. $displayString',
                              // Hiển thị mã đã xử lý
                              style: const TextStyle(
                                color: AppColor.mainText,
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(
                        child: Text(
                          'Không có dữ liệu',
                          style: TextStyle(
                            color: AppColor.mainText,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void loadTagCount() async {
    if (widget.event.idLTH != null) {
      // Giả sử widget.event là sự kiện được chọn và có thuộc tính id
      List<TagEpcLDB> tags = await loadData(event.idLTH);
      setState(() {
        tagCount = tags.length; // Cập nhật số lượng tags vào biến trạng thái
        tagsList = tags.map((tag) => tag.epc).toList();
      });
    }
  }

  Future<void> saveRecallReplaceData(String key, List<TagEpcLDB> data) async {
    // Chuyển đổi danh sách tags mới thành chuỗi JSON
    String dataString = TagEpcLDB.tagsToJson(data);

    // Lưu chuỗi JSON vào bộ nhớ bảo mật
    await _storageRecallReplace.write(key: key, value: dataString);
  }

  Future<List<TagEpcLDB>> loadRecallReplaceData(String key) async {
    String? dataString = await _storageRecallReplace.read(key: key);
    if (dataString != null) {
      // Sử dụng parseTags để chuyển đổi chuỗi JSON thành danh sách TagEpcLBD
      return TagEpcLDB.parseTags(dataString);
    }
    return [];
  }

  void loadRecallReplaceTagCount() async {
    if (widget.event.idLTH != null) {
      // Giả sử widget.event là sự kiện được chọn và có thuộc tính id
      List<TagEpcLDB> tag =
          await loadRecallReplaceData('replace_${event.idLTH}');
      setState(() {
        tagRecallReplaceCount =
            tag.length; // Cập nhật số lượng tags vào biến trạng thái
        tagRecallReplaceList = tag.map((tag) => tag.epc).toList();
      });
    }
  }

  Future<void> _showBarcodeConfirmationDialog() async {
    print('được gọi');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Lưu mã chip?',
            style: TextStyle(
                color: AppColor.mainText, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _data.isNotEmpty ? 1 : 0,
                    // Hiển thị 1 phần tử nếu có dữ liệu
                    itemBuilder: (context, index) {
                      // Lấy mã chip mới nhất (phần tử cuối cùng trong _data)
                      String latestTagEpc = _data.last.epc;
                      print(latestTagEpc);
                      return ListTile(
                        title: Text(
                          '1. $latestTagEpc', // Chỉ hiển thị 1 mã chip mới nhất
                          style: const TextStyle(
                            color: AppColor.mainText,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text('Hủy Bỏ',
                  style: TextStyle(
                    color: Colors.white,
                  )),
              onPressed: () async {
                Navigator.of(context).pop();
                await RfidC72Plugin.clearData;
                setState(() {
                  successfullySaved = tagCount;
                  _data.clear();
                  showConfirmationDialog = false;
                });
              },
            ),
            const SizedBox(
              width: 8,
            ),
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text('Xác Nhận',
                  style: TextStyle(
                    color: Colors.white,
                  )),
              onPressed: () async {
                // Đầu tiên, tải danh sách tag hiện tại từ lưu trữ
                List<TagEpcLDB> currentTags = await loadData(event.idLTH);
                // Lọc ra những tag mới chưa có trong currentTags
                List<TagEpcLDB> newUniqueTags = _data
                    .where((newTag) => !currentTags
                        .any((savedTag) => savedTag.epc == newTag.epc))
                    .toList();
                // Thêm các tag mới vào danh sách hiện tại và loại bỏ các tag trùng lặp
                currentTags.addAll(newUniqueTags);
                currentTags = currentTags.toSet().toList();
                // Sử dụng Set để loại bỏ các tag trùng lặp
                // Lưu danh sách đã cập nhật vào lưu trữ
                await saveData(event.idLTH, currentTags);
                await _storage.write(
                    key: '${event.idLTH}_length',
                    value: _data.length.toString());
                Navigator.of(context).pop();
                if (!_isClickConfirmScanMethod) {
                  Navigator.of(context).pop();
                }
                setState(() {
                  loadTagCount();
                  showConfirmationDialog = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showBarcodeScanningModal() {
    showDialog(
      context: context,
      barrierDismissible: true, // Không cho phép đóng khi nhấn ngoài
      builder: (BuildContext context) {
        return const Center(
          child: Dialog(
            backgroundColor: Color.fromARGB(255, 43, 78, 128),
            elevation: 0,
            child: SizedBox(
              height: 200, // Chiều cao cố định
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 50),
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF1C88FF)),
                  ),
                  SizedBox(height: 50),
                  Text(
                    "Đang quét mã QR...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) async {
      _isDialogBarcodeShown = false;
      _is2dscanCall = false;
      await RfidC72Plugin.stopScan;
    });
    _isDialogBarcodeShown = false;

    // Future.delayed(const Duration(seconds: 5), () async {
    //   if (mounted ) {  // dùng mounted để kiểm tra context còn tồn tại
    //     Navigator.of(context).pop();
    //     _is2dscanCall = false;
    //   }
    // });
  }

  void _showTimeoutMessage() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Không thể quét",
            style: TextStyle(
              color: AppColor.mainText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Không thể quét QR Code. Vui lòng sử dụng Strigger để quét!",
            style: TextStyle(
              fontSize: 18,
              color: AppColor.mainText,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  StreamSubscription<dynamic>? _barcodeSubscription;
  Timer? _scanTimeoutTimer;

  String? _extractCodeFromUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.queryParameters['id']; // Trả về phần mã phía sau `id=`
    } catch (e) {
      print("Error parsing URL: $e");
      return null; // Trả về null nếu có lỗi khi phân tích URL
    }
  }

  Future<void> _toggleBarCodeScanning() async {
    if (currentDevice == Device.cameraBarcodes ||
        _isDialogBarcodeShown ||
        isShowDuplicateTagDialog ||
        currentDevice == Device.rSeries ||
        _selectedScanningMethod != "qr") {
      return;
    }
    RfidC72Plugin.barcodeStatusStream
        .receiveBroadcastStream()
        .listen(updateBarcodeTags);
    if (mounted) {
      setState(() {
        _is2dscanCall = !_is2dscanCall; // Thay đổi trạng thái quét
      });
    }

    if (_is2dscanCall) {
      // Hiển thị dialog "Đang quét"
      _isDialogBarcodeShown = true;
      _showBarcodeScanningModal();

      await RfidC72Plugin.connectBarcode; // Kết nối Barcode scanner
      await RfidC72Plugin.scanBarcode; // Bắt đầu quét mã QR

      if (extractedCode.isNotEmpty) {

        setState(() {
          _data.clear();
          _data.add(
              TagEpcLDB(epc: extractedCode)); // Thêm mã QR vào danh sách EPC
          _totalEPC = _data.length; // Cập nhật số lượng EPC quét được
          _is2dscanCall = false; // Dừng quét
        });

        // Dừng quét sau khi mã QR đã được xử lý
        await RfidC72Plugin.stopScan;

        // Ngắt kết nối máy quét sau khi dừng quét
        await RfidC72Plugin.closeScan;

        // Hủy lắng nghe sự kiện
        if (_barcodeSubscription != null) {
          await _barcodeSubscription?.cancel();
          _barcodeSubscription = null;
        }

        //  Đóng dialog "Đang quét"
        Navigator.of(context, rootNavigator: true).pop();

        // Hiển thị modal lưu mã chip (nếu cần)
        await _showBarcodeConfirmationDialog();
      }
    } else {
      // Dừng quét nếu đang quét
      await RfidC72Plugin.stopScan;

      // Hủy lắng nghe sự kiện nếu cần
      if (_barcodeSubscription != null) {
        await _barcodeSubscription?.cancel();
        _barcodeSubscription = null;
      }
    }
  }

  Future<void> saveTagsToSecureStorage(
      String calendarId, List<TagEpcLDB> tags) async {
    // Serialize danh sách tag thành chuỗi JSON
    List<Map<String, dynamic>> jsonTags =
        tags.map((tag) => tag.toJson()).toList();
    String jsonString = jsonEncode(jsonTags);
    // Sử dụng ID lịch như một phần của key khi lưu
    await _storage.write(key: 'saved_tags_$calendarId', value: jsonString);
  }

  Future<List<TagEpcLDB>> loadTagsFromSecureStorage(String calendarId) async {
    String? jsonString = await _storage.read(key: 'saved_tags_$calendarId');
    if (jsonString == null) return [];
    List<dynamic> jsonTags = jsonDecode(jsonString);
    List<TagEpcLDB> tags =
        jsonTags.map((jsonTag) => TagEpcLDB.fromJson(jsonTag)).toList();
    return tags;
  }

  // Show bảng xác nhận lưu mã quét bằng GUN
  Future<void> _showConfirmationDialog() async {
    setState(() {
      _isContinuousCall = false;
    });
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Lưu mã chip?',
            style: TextStyle(
                color: AppColor.mainText, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Text('Bạn có chắc chắn muốn lưu kết quả quét không?'),
                const SizedBox(height: 20),
                SizedBox(
                  // Giới hạn chiều cao của Container chứa ListView.builder
                  height: 200, // Hoặc một giá trị phù hợp với nhu cầu của bạn
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      String tagepc =
                          CommonFunction().hexToString(_data[index].epc);
                      return ListTile(
                        title: Text(
                          '${index + 1}.$tagepc',
                          style: const TextStyle(color: AppColor.mainText),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text('Hủy Bỏ',
                  style: TextStyle(
                    color: Colors.white,
                  )),
              onPressed: () async {
                Navigator.of(context).pop();
                await RfidC72Plugin.clearData;
                setState(() {
                  successfullySaved = tagCount;
                  _data.clear();
                  showConfirmationDialog = false;
                });
              },
            ),
            const SizedBox(
              width: 8,
            ),
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text('Xác Nhận',
                  style: TextStyle(
                    color: Colors.white,
                  )),
              onPressed: () async {
                // Đầu tiên, tải danh sách tag hiện tại từ lưu trữ
                List<TagEpcLDB> currentTags = await loadData(event.idLTH);
                // Lọc ra những tag mới chưa có trong currentTags
                List<TagEpcLDB> newUniqueTags = _data
                    .where((newTag) => !currentTags
                        .any((savedTag) => savedTag.epc == newTag.epc))
                    .toList();
                // Thêm các tag mới vào danh sách hiện tại và loại bỏ các tag trùng lặp
                currentTags.addAll(newUniqueTags);
                currentTags = currentTags.toSet().toList();
                // Lưu danh sách đã cập nhật vào lưu trữ
                await saveData(event.idLTH, currentTags);
                await _storage.write(
                    key: '${event.idLTH}_length',
                    value: _data.length.toString());
                Navigator.of(context).pop();
                setState(() {
                  loadTagCount();
                  showConfirmationDialog = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getMaTKFromSecureStorage() async {
    return await _storageAcountCode.read(key: 'maTK');
  }

  String getSentTagsKey(String eventId) {
    return 'sent_tags_$eventId';
  }

  Future<void> saveTagState(TagEpcLDB tag) async {
    final secureLTHStorage = const FlutterSecureStorage();
    String key = 'tag_${tag.epc}';
    String json = jsonEncode(tag.toJson());
    await secureLTHStorage.write(key: key, value: json);
  }

  Future<void> _showScanMethodDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text(
                "Vui lòng chọn hình thức quét!",
                style: TextStyle(
                  color: AppColor.mainText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      setStateModal(() {
                        _selectedScanningMethod = "rfid";
                      });
                      KeyEventChannel(
                        onKeyReceived: checkCurrentDevice, //NMC 97
                      ).initialize();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: <Widget>[
                          Radio<String>(
                            value: "rfid",
                            groupValue: _selectedScanningMethod,
                            onChanged: (String? value) {
                              setStateModal(() {
                                _selectedScanningMethod = value!;
                              });
                            },
                            activeColor: const Color(0xFFd5a529),
                            fillColor: MaterialStateProperty.all<Color>(
                              _selectedScanningMethod == "rfid"
                                  ? const Color(0xFFd5a529)
                                  : AppColor.mainText,
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          const Text(
                            "Quét mã RFID",
                            style: TextStyle(
                              color: AppColor.mainText,
                              fontSize: 18.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    // Nếu là lựa chọn quét QR
                    onTap: () {
                      setStateModal(() {
                        _selectedScanningMethod = "qr";
                      });
                      KeyEventChannel(
                        onKeyReceived: checkCurrentDevice,
                      ).initialize();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: <Widget>[
                          Radio<String>(
                            value: "qr",
                            groupValue: _selectedScanningMethod,
                            onChanged: (String? value) {
                              setStateModal(() {
                                _selectedScanningMethod = value!;
                              });
                            },
                            activeColor: const Color(0xFFd5a529),
                            fillColor: MaterialStateProperty.all<Color>(
                              _selectedScanningMethod == "qr"
                                  ? const Color(0xFFd5a529)
                                  : AppColor.mainText,
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          const Text(
                            "Quét QR code",
                            style: TextStyle(
                              color: AppColor.mainText,
                              fontSize: 18.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                        AppColor.mainText),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    fixedSize: MaterialStateProperty.all<Size>(
                        const Size(100.0, 30.0)),
                  ),
                  child: const Text(
                    "Hủy",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Đóng dialog mà không thực hiện gì
                  },
                ),
                TextButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                        AppColor.mainText),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    fixedSize: MaterialStateProperty.all<Size>(
                        const Size(100.0, 30.0)),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    // Khi lựa chọn xong thì nhấn OK, lúc này sẽ bắt đầu thực thi
                    setState(() {
                      _isClickConfirmScanMethod = true;
                    });
                    Navigator.of(context).pop(true);
                    if (_selectedScanningMethod.isNotEmpty) {
                      if (_selectedScanningMethod == "rfid") {
                        // RFID có hiệu lực R5 và C5
                        checkCurrentDevice();
                      } else if (_selectedScanningMethod == "qr") {
                        // nếu chọn QR
                        if (currentDevice == Device.cameraBarcodes ||
                            currentDevice == Device.rSeries) {
                          scanQRCodeByCamera(); // Camera có hiệu lực cho cả R5 và C5
                        } else if (currentDevice == Device.cSeries) {
                          _toggleBarCodeScanning();
                        }
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> postDataRecal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      // Người dùng không thể tắt dialog bằng cách nhấn ngoài biên
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColor.mainText),
                ),
                SizedBox(width: 20),
                Text(
                  "Đang đồng bộ...",
                  style: TextStyle(
                    color: AppColor.mainText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    String eventId = event.idLTH; // ID của lịch
    int successCount = 0;
    int failCount = 0;
    String? maTK = await _getMaTKFromSecureStorage();
    List<TagEpcLDB> allRFIDData =
        await loadData(event.idLTH); // Tải tất cả dữ liệu RFID
    DateTime ngayPost = DateTime.now(); // Định dạng ngày gửi
    String postDate = ngayPost.toIso8601String();
    String currentDate = DateFormat('dd/MM/yyyy').format(ngayPost);
    bool networkErrorOccurred = false;
    String key =
        getSentTagsKey(event.idLTH); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureLTHStorage.read(key: key);
    List<String> sentTags =
        sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    String baseUrl = '${AppConfig.IP}/api/76BCE4D5B5F04D69AA468C0AAE8FA254';
    DateTime now = DateTime.now();
    int milli = now.millisecondsSinceEpoch;
    String milliString = milli.toString();
    String formattedTimestamp = milliString.padLeft(18, '0');
    for (TagEpcLDB tag in allRFIDData) {
      String epcString = CommonFunction().hexToString(tag.epc);
      // List<String>allTag=[
      //   "RJVI24000022ANML",
      //  ];
      // for (String epcString in allTag) {
      String apiUrl = '$baseUrl/$epcString';
      print(apiUrl);
      if (!sentTags.contains(epcString)) {
        Map<String, dynamic> data = {
          "10ME": "${epcString}_${formattedTimestamp}",
          "1MESP": epcString,
          "10MTK": maTK,
          "2LDTH": event.ghiChuLTH,
          "4NTH": postDate,
          "30TT": "TT001"
        };
        try {
          final response = await http.put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          );
          if (response.statusCode == 200) {
            sentTags.add(epcString);
            await secureLTHStorage.write(
              key: key,
              value: jsonEncode(sentTags),
            );
            final responseData = json.decode(response.body);
            // print(responseData["success"]);
            if (responseData["success"] == true &&
                responseData["results_of_update"].isNotEmpty) {
              successCount++; // Tăng số lượng thành công
            } else {
              failCount++; // Tăng số lượng thất bại
            }
          } else {
            failCount++; // Tăng số lượng thất bại
          }
        } on SocketException {
          networkErrorOccurred = true;
          break; // Dừng nếu có lỗi mạng
        } catch (e) {
          print("Error occurred while posting data for EPC $epcString: $e");
          failCount++; // Xem như thất bại nếu có lỗi xảy ra
        }
      }
    }
    Navigator.pop(context); // Đóng dialog
    // Hiển thị dialog thông báo kết quả một lần sau khi gửi hết tất cả EPC
    if (networkErrorOccurred) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Mất kết nối!",
              style: TextStyle(
                color: AppColor.mainText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text("Vui lòng kiểm tra kết nối mạng.",
                style: TextStyle(
                  fontSize: 18,
                  color: AppColor.mainText,
                )),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          10.0), // Điều chỉnh độ cong của góc
                    ),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                },
              )
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Đồng bộ thành công",
              style: TextStyle(
                color: AppColor.mainText,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          10.0), // Điều chỉnh độ cong của góc
                    ),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                  // Navigator.of(context).pop(); // Đóng cửa sổ dialog
                  Navigator.pop(context, true);
                },
              )
            ],
          );
        },
      );
    }
    final dbHelper = CalendarRecallDatabaseHelper();
    await dbHelper.syncEvent(event);
    dadongbo = true;
    setState(() {
      dadongbao = true;
    });
    setState(() {
      saveCountsToStorage(eventId, successCount, failCount, currentDate);
    });
    // print(currentDate);
  }

  Future<void> putWearhouseRecal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      // Người dùng không thể tắt dialog bằng cách nhấn ngoài biên
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColor.mainText),
                ),
                SizedBox(width: 20),
                Text(
                  "Đang đồng bộ...",
                  style: TextStyle(
                    color: AppColor.mainText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    String eventId = event.idLTH; // ID của lịch
    int successCount = 0;
    int failCount = 0;
    String LDTH = widget.event.ghiChuLTH; // Lấy ghi chú của sự kiện
    String? maTK = await _getMaTKFromSecureStorage();
    List<TagEpcLDB> allRFIDData =
        await loadData(event.idLTH); // Tải tất cả dữ liệu RFID
    DateTime ngayPost = DateTime.now(); // Định dạng ngày gửi
    String currentDate = DateFormat('dd/MM/yyyy').format(ngayPost);
    String postDate = ngayPost.toIso8601String();
    bool networkErrorOccurred = false;

    final DateTime now = DateTime.now();
    int milli = now.millisecondsSinceEpoch;
    String milliString = milli.toString();
    String formattedTimestamp = milliString.padLeft(18, '0');
    String key =
        getSentTagsKey(event.idLTH); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureLTHStorage.read(key: key);
    List<String> sentTags =
        sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    String baseUrl = '${AppConfig.IP}/api/40A0EE04219B4262B692F1F2DDB367DF';
    //
    for (TagEpcLDB tag in allRFIDData) {
      String epcString = CommonFunction().hexToString(tag.epc);
      // List<String>allTag=[
      //   "RJVD2400006NKVML",
      // ];
      // for (String epcString in allTag) {

      String apiUrl = '$baseUrl/$epcString';
      print(apiUrl);
      if (!sentTags.contains(epcString)) {
        Map<String, dynamic> data = {
          "10ME": "${epcString}_${formattedTimestamp}",
          "10MTK": maTK,
          "2LDTH": LDTH,
          "4NTH": postDate,
          "1MESP": epcString,
          "30TT": "TT001",
          "3MLĐB": " ",
          "1TTĐB": "true",
          "16MT": "ERROR_0000",
          "2MPP": " ",
          "1TTPP": "true",
          "15MT": "ERROR_0000",
          "1TTPPKT": "true",
          "18MT": "ERROR_0000",
          "3MPPKT": " ",
          "28GC": "Thu hồi nhiễu (Xuất dư)",
          "29GC": "Thu hồi nhiễu (Xuất dư)",
          "30GC": "Thu hồi nhiễu (Xuất dư)",
          "3SĐQ": 0,
          "2SQTC": 0,
          "2SQTB": 0,
          "3SGTC": 0,
          "3SGTB": 0,
          "2SLĐQ": 0,
          "4SGTC": 0,
          "4SGTB": 0,
          "3SQTC": 0,
          "3SQTB": 0
        };
        print(data);
        try {
          final response = await http.put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            sentTags.add(epcString);
            await secureLTHStorage.write(
              key: key,
              value: jsonEncode(sentTags),
            );
            final responseData = json.decode(response.body);
            print(responseData["success"]);

            if (responseData["success"] == true &&
                responseData["results_of_update"].isNotEmpty) {
              // Truy cập phần tử đầu tiên của danh sách `results_of_update`
              var result = responseData["results_of_update"][0];

              // Lấy giá trị `1LPPKT`, nếu không có thì lấy `1LPP`
              String? maPhanPhoi =
                  result["1LPPKT"] != null && result["1LPPKT"].isNotEmpty
                      ? result["1LPPKT"]
                      : result["1LPP"];

              // Kiểm tra điều kiện và gọi hàm tương ứng
              if (maPhanPhoi != null && maPhanPhoi.isNotEmpty) {
                await putInfoToApi(maPhanPhoi);
              } else {
                // Kiểm tra nếu `6LĐB` tồn tại và hợp lệ
                String? maLDB = result["6LĐB"];
                if (maLDB != null && maLDB.isNotEmpty) {
                  await putInfLDBToAPi(maLDB);
                }
              }
            } else {
              failCount++; // Tăng số lượng thất bại
            }
          } else {
            failCount++; // Tăng số lượng thất bại
          }
        } on SocketException {
          networkErrorOccurred = true;
          break; // Dừng nếu có lỗi mạng
        } catch (e) {
          print("Error occurred while posting data for EPC $epcString: $e");
          failCount++; // Xem như thất bại nếu có lỗi xảy ra
        }
      }
    }

    print(successCount);
    Navigator.pop(context); // Đóng dialog

    if (networkErrorOccurred) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Mất kết nối!",
              style: TextStyle(
                color: AppColor.mainText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text("Vui lòng kiểm tra kết nối mạng.",
                style: TextStyle(
                  fontSize: 18,
                  color: AppColor.mainText,
                )),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          10.0), // Điều chỉnh độ cong của góc
                    ),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                },
              )
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Đồng bộ thành công",
              style: TextStyle(
                color: AppColor.mainText,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          10.0), // Điều chỉnh độ cong của góc
                    ),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                  Navigator.pop(
                      context, true); // Trả về giá trị true khi đóng màn hình
                },
              )
            ],
          );
        },
      );
    }

    final dbHelper = CalendarRecallDatabaseHelper();
    await dbHelper.syncEvent(event);
    dadongbo = true;
    setState(() {
      dadongbao = true;
    });

    setState(() {
      saveCountsToStorage(eventId, successCount, failCount, currentDate);
    });
  }

  Future<void> putInfoToApi(String maPhanPhoi) async {
    print(maPhanPhoi);
    // URL API với mã phân phối (1LPPKT)
    String apiUrl =
        '${AppConfig.IP}/api/A628AFBBEB794516A581025419F85336/$maPhanPhoi';

    // Dữ liệu JSON để gửi trong body của request
    Map<String, dynamic> data = {"2SLĐQ": 0, "4SGTC": 0, "3SQTC": 0};

    try {
      // Thực hiện PUT request
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(data),
      );

      // Kiểm tra trạng thái phản hồi
      if (response.statusCode == 200) {
        print('Request thành công: ${response.body}');
        // Xử lý kết quả trả về nếu cần
      } else {
        print('Request thất bại với mã trạng thái: ${response.statusCode}');
      }
    } catch (e) {
      // Xử lý lỗi nếu có
      print('Lỗi xảy ra khi thực hiện PUT request: $e');
    }
  }

  Future<void> putInfLDBToAPi(String maLDB) async {
    print(maLDB);
    // URL API với mã phân phối (1LPPKT)
    String apiUrl =
        '${AppConfig.IP}/api/B2BB478124BF4CDCAE4F126FFB831D14/$maLDB';

    // Dữ liệu JSON để gửi trong body của request
    Map<String, dynamic> data = {"3SĐQ": 0, "2SQTC": 0, "3SGTC": 0};
    print('a $apiUrl');
    print('a $data');

    try {
      // Thực hiện PUT request
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(data),
      );

      // Kiểm tra trạng thái phản hồi
      if (response.statusCode == 200) {
        print('Request thành công: ${response.body}');
        // Xử lý kết quả trả về nếu cần
      } else {
        print('Request thất bại với mã trạng thái: ${response.statusCode}');
      }
    } catch (e) {
      // Xử lý lỗi nếu có
      print('Lỗi xảy ra khi thực hiện PUT request: $e');
    }
  }

  void _showRecallConfirmationDialog(String dialogTitle, Function() onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            dialogTitle,
            style: const TextStyle(
              color: AppColor.mainText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Bạn có chắc chắn muốn thực hiện thu hồi với lý do: ${widget.event.ghiChuLTH}?",
            style: const TextStyle(
              fontSize: 18,
              color: AppColor.contentText,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text(
                "Hủy",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
              },
            ),
            TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        10.0), // Điều chỉnh độ cong của góc
                  ),
                ),
                fixedSize:
                    MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
                onConfirm(); // Gọi hàm xác nhận để tiếp tục
              },
            ),
          ],
        );
      },
    );
  }

  String getKey(String eventId, String id) {
    return '$eventId-$id';
  }

  Future<void> saveCountsToStorage(String eventId, int successCount,
      int failCount, String currentDate) async {
    List<String> keys = ["successCount", "failCount", "currentDate"];
    // Đọc giá trị hiện tại từ bộ nhớ và cộng dồn giá trị mới
    for (String key in keys) {
      String storageKey = getKey(key, eventId);
      String? value = await secureRecallStorage.read(key: storageKey);
      int currentValue = int.tryParse(value ?? '') ??
          0; // Sử dụng 0 làm giá trị mặc định nếu không phải số
      // Cộng dồn giá trị mới với giá trị đã lưu
      switch (key) {
        case "successCount":
          currentValue += successCount;
          break;
        case "failCount":
          currentValue += failCount;
          break;
        case "currentDate":
          await secureRecallStorage.write(key: storageKey, value: currentDate);
          continue; // Bỏ qua bước lưu số vì đã lưu chuỗi ngày
      }
      // Lưu giá trị đã cộng dồn trở lại vào bộ nhớ
      await secureRecallStorage.write(
          key: storageKey, value: currentValue.toString());
    }
  }

  Future<void> saveCounterToStorage() async {
    await secureStorage.write(
        key: "saveCounter", value: _saveCounter.toString());
  }

  Future<void> loadCounterFromStorage() async {
    String? counterString = await secureStorage.read(key: "saveCounter");
    _saveCounter = int.tryParse(counterString ?? '0') ??
        0; // Đặt lại _saveCounter nếu tìm thấy
  }

  Future<List<Map<String, dynamic>>> loadAllRecalls(String eventId) async {
    List<Map<String, dynamic>> allRecalls = [];
    final allKeys = (await secureStorage.readAll())
        .keys
        .where((key) => key.contains(eventId))
        .toList();
    // Tạo một cấu trúc dữ liệu để giữ thông tin thành công và thất bại cho mỗi postId
    Map<String, Map<String, int>> recallCounts = {};
    for (var key in allKeys) {
      var parts = key.split('-');
      var postId =
          parts[parts.length - 1]; // Giả sử postId là phần tử cuối cùng
      var value = await secureStorage.read(key: key);
      var count = int.tryParse(value ?? '0') ?? 0;
      recallCounts[postId] ??= {'successCountRecall': 0, 'failCountRecall': 0};
      if (key.contains("successCountRecall")) {
        recallCounts[postId]!['successCountRecall'] = count;
      } else if (key.contains("failCountRecall")) {
        recallCounts[postId]!['failCountRecall'] = count;
      }
    }
    // Chuyển đổi recallCounts thành danh sách cho allRecalls
    recallCounts.forEach((postId, counts) {
      allRecalls.add({
        'postId': int.tryParse(postId) ?? 0,
        ...counts // Sử dụng spread operator để thêm counts vào Map
      });
    });
    // Sắp xếp allRecalls dựa trên postId từ cũ đến mới
    allRecalls.sort((a, b) => a['postId'].compareTo(b['postId']));
    return allRecalls;
  }

  void onAgencySelected(String selectedAgencyName) {}

  Future<void> _toggleScanningForC5() async {
    try {
      if ((currentDevice != Device.cSeries &&
              currentDevice != Device.cameraBarcodes) ||
          _selectedScanningMethod != "rfid") {
        return;
      }
      RfidC72Plugin.closeScan;
      if (_isContinuousCall) {
        // Đóng dialog quét nếu nó đang hiển thị
        if (_isDialogShown) {
          Navigator.of(context, rootNavigator: true).pop('dialog');
        }
        // Chờ một khoảng thời gian ngắn (nếu cần) và mở dialog xác nhận
        if (!showConfirmationDialog) {
          Future.delayed(const Duration(milliseconds: 100), () {
            //  _showConfirmationDialog();
            showConfirmationDialog = true;
          });
        }
      } else {
        if (!showConfirmationDialog) {
          DataReadOptions.readTagsAsync(true,
              currentDevice); //Start by internal device key or software button
          _data.clear();
          _isContinuousCall = true;
          if (!_isDialogShown) {
            _showScanningModal();
          }
        }
      }
      setState(() {
        _isShowModal = _isContinuousCall;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _toggleScanningForR5() async {
    try {
      if (currentDevice != Device.rSeries ||
          _selectedScanningMethod != "rfid" /*|| _isDialogShown*/) return;
      if (await RfidC72Plugin.isConnected == true) {
        await RfidC72Plugin.stopScan;
        await RfidC72Plugin.closeScan;
      }
      // Check connection
      var isConnected = await UHFBlePlugin.getConnectionStatus();
      if (!isConnected && mounted) {
        ConnectionNotificationRSeries.showConnectionStatus(context, false);
        return;
      }

      if (_isContinuousCall) {
        if (!scanStatusR5) {
          DataReadOptions.readTagsAsync(false,
              currentDevice); //Start by internal device key or software button
        }
        if (mounted && _isDialogShown) {
          Navigator.of(context, rootNavigator: true).pop('dialog');
        }
        if (!showConfirmationDialog) {
          Future.delayed(const Duration(milliseconds: 100), () {
            //  _showConfirmationDialog();
            showConfirmationDialog = true;
          });
        }
      } else {
        if (!showConfirmationDialog) {
          print("MinhChau: bat dau doc2");
          if (!scanStatusR5) {
            print("MinhChau: bat dau doc3");
            print("Current Device ${currentDevice}");
            DataReadOptions.readTagsAsync(true,
                currentDevice); //Stop by internal device key or software button
          }
          _data.clear();
          _isContinuousCall = true;
          if (!_isDialogShown) {
            _showScanningModal();
          }
        }
      }
      setState(() {
        _isShowModal = _isContinuousCall;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Show dialog scanning indicator
  void _showScanningModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return (_isShowModal)
            ? Center(
                child: Dialog(
                  elevation: 0,
                  backgroundColor: const Color.fromARGB(255, 43, 78, 128),
                  child: SizedBox(
                    height: 300,
                    child: SavedTagsModal(
                      updateStream: _updateStreamController.stream,
                    ),
                  ),
                ),
              )
            : const SizedBox
                .shrink(); //một widget rỗng được hiển thị nếu _isShowModal = false
      },
    ).then((_) {
      _isDialogShown = false;
      DataReadOptions.readTagsAsync(false, currentDevice); // stop scan
      if (!showConfirmationDialog) {
        //Show confirm to save tag
        Future.delayed(const Duration(milliseconds: 100), () {
          _showConfirmationDialog();
          showConfirmationDialog = true;
        });
      }
    });
    _isDialogShown = true;
  }

  // builder: (BuildContext context) {
  // // Trả về widget dialog
  // return Center(
  // child: Dialog(
  // elevation: 0,
  // backgroundColor: Colors.transparent,
  // child: SavedTagsModal(
  // updateStream: _updateStreamController.stream,
  // ),
  // ),
  // );
  // }

  Future<List<TagEpcLDB>> getTagEpcList(String key) async {
    return await loadData(event.idLTH);
  }

  Future<String> formatDataForFileWithTags(String key) async {
    StringBuffer buffer = StringBuffer();
    // Dữ liệu từ các thông tin khác
    buffer.writeln("Nội dung thu hồi: ${event.ghiChuLTH}");
    buffer.writeln("Số lượng quét: $tagCount");
    buffer.writeln("Ngày tạo lịch: ${event.ngayTaoLTH}");
    // Lấy danh sách TagEpcLBD từ loadData
    List<TagEpcLDB> tagEpcList = await getTagEpcList(event.idLTH);
    buffer.writeln("Mã EPC:");
    // Duyệt qua danh sách và thêm từng EPC vào chuỗi
    for (var tag in tagEpcList) {
      String epcString = CommonFunction().hexToString(tag.epc);
      buffer.writeln(epcString); // Giả định `epc` là trường trong TagEpcLBD
    }
    return buffer.toString();
  }

  //
  Future<void> saveFileToDownloads(String data, String fileName) async {
    try {
      final downloadDirectory =
          await ExternalPath.getExternalStoragePublicDirectory(
              ExternalPath.DIRECTORY_DOWNLOADS);
      final filePath = '$downloadDirectory/$fileName';
      final file = File(filePath);
      await file.writeAsString(data); // Viết dữ liệu vào tệp
      print('File saved to Downloads: $filePath');
    } catch (e) {
      print('Failed to save file: $e');
      // Xử lý lỗi khi không thể ghi file
    }
  }

  Future<void> saveDataWithTags(String key, String baseFileName) async {
    var permissionStatus = await Permission.storage.request();
    if (permissionStatus.isGranted) {
      String formattedData =
          await formatDataForFileWithTags(event.idLTH); // Lấy chuỗi định dạng
      String timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName =
          '$baseFileName\_$timeStamp.txt'; // Tạo tên file với dấu thời gian
      await saveFileToDownloads(
          formattedData, fileName); // Ghi dữ liệu vào tệp với tên duy nhất
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tệp đã được lưu vào mục Download: $fileName'),
          backgroundColor: const Color(0xFF4EB47D),
          duration: const Duration(seconds: 3), // Thời gian hiển thị SnackBar
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Quyền truy cập bị từ chối. Không thể lưu tệp.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return WillPopScope(
        onWillPop: () async {
          if (dadongbo = true) {
            // Hành động cụ thể khi tagCount > 0
            Navigator.pop(context,
                true); // Quay trở lại màn hình trước và gửi giá trị true
            return false; // Trả về false để ngăn việc tự động pop, vì đã xử lý pop
          } else {
            return true; // Cho phép người dùng thoát nếu không có điều kiện nào được thỏa mãn
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            toolbarHeight: screenHeight * 0.12,
            // Chiều cao thanh công cụ
            backgroundColor: const Color(0xFFE9EBF1),
            elevation: 4,
            shadowColor: Colors.blue.withOpacity(0.5),
            leading: Row(children: [
              // SizedBox(
              //   width: screenWidth * 0.2, // Chiều rộng logo
              //   height: screenHeight * 0.15, // Chiều cao logo
              //   child: Image.asset(
              //     'assets/image/logoJVF_RFID.png',
              //     fit: BoxFit.contain,
              //   ),
              // ),
              IconButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.arrow_back)),
            ]),

            title: Text(
             widget.isSurplusGoodRecall ? 'Lịch thu hồi hủy bỏ' : 'Lịch thu hồi xuất dư',
              style: TextStyle(
                fontSize: screenWidth * 0.055, // Kích thước chữ
                fontWeight: FontWeight.bold,
                color: AppColor.mainText,
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: screenWidth * 0.03),
                // Khoảng cách từ mép phải
                child: Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        saveDataWithTags(event.idLTH, "${event.ghiChuLTH}");
                      },
                      child: Image.asset(
                        'assets/image/download.png',
                        width: screenWidth * 0.1, // Chiều rộng hình ảnh
                        height: screenHeight * 0.1, // Chiều cao hình ảnh
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    // Khoảng cách giữa hai nút
                    InkWell(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text(
                                'Xác nhận xóa',
                                style: TextStyle(
                                    color: AppColor.mainText,
                                    fontWeight: FontWeight.bold),
                              ),
                              content: const Text(
                                  "Bạn có chắc chắn muốn xóa lịch này không?",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColor.contentText,
                                  )),
                              actions: <Widget>[
                                TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            AppColor.mainText),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            10.0), // Điều chỉnh độ cong của góc
                                      ),
                                    ),
                                    fixedSize: MaterialStateProperty.all<Size>(
                                        const Size(100.0, 30.0)),
                                  ),
                                  child: const Text('Hủy',
                                      style: TextStyle(
                                        color: Colors.white,
                                      )),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            AppColor.mainText),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            10.0), // Điều chỉnh độ cong của góc
                                      ),
                                    ),
                                    fixedSize: MaterialStateProperty.all<Size>(
                                        const Size(100.0, 30.0)),
                                  ),
                                  child: const Text('Xác Nhận',
                                      style: TextStyle(
                                        color: Colors.white,
                                      )),
                                  onPressed: () async {
                                    deleteEventFromCalendar();
                                    Navigator.pop(context, true);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Image.asset(
                        'assets/image/thungrac1.png',
                        width: screenWidth * 0.1, // Chiều rộng hình ảnh
                        height: screenHeight * 0.1, // Chiều cao hình ảnh
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(screenWidth * 0.05,
                      screenHeight * 0.012, 0, screenHeight * 0.012),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.5),
                        // Màu sắc của đường viền dưới
                        width: 2, // Độ dày của đường viền dưới
                      ),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        // fontSize: 24,
                        fontSize: screenWidth * 0.065,
                        color: AppColor.mainText,
                      ),
                      children: [
                        TextSpan(
                          text: 'Nội dung thu hồi\n',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            // fontSize: 24,
                            fontSize: screenWidth * 0.065,
                          ),
                        ),
                        TextSpan(
                          text: '${event.ghiChuLTH}',
                          style: const TextStyle(color: AppColor.contentText)
                        ),
                      ],
                    ),
                  )),
              GestureDetector(
                onTap: () {
                  _showChipInformation(context);
                },
                child: Container(
                  // padding: EdgeInsets.fromLTRB(20, 15, 0, 12),
                  padding: EdgeInsets.fromLTRB(screenWidth * 0.05,
                      screenHeight * 0.012, 0, screenHeight * 0.012),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.5), width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: screenWidth * 0.065,
                                color: AppColor.mainText),
                            children: [
                              TextSpan(
                                text: 'Số lượng quét\n ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.065),
                              ),
                              TextSpan(
                                // Kiểm tra trạng thái quét để quyết định hiển thị giá trị nào
                                text: '$tagCount',
                                  style: const TextStyle(color: AppColor.contentText)
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(Icons.navigate_next,
                          color: AppColor.mainText, size: 30.0),
                    ],
                  ),
                ),
              ),
              Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(screenWidth * 0.05,
                      screenHeight * 0.012, 0, screenHeight * 0.012),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.5),
                        // Màu sắc của đường viền dưới
                        width: 2, // Độ dày của đường viền dưới
                      ),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: screenWidth * 0.065,
                        color: AppColor.mainText,
                      ),
                      children: [
                        TextSpan(
                          text: 'Ngày tạo lịch\n',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.065,
                          ),
                        ),
                        TextSpan(
                          text: '${event.ngayTaoLTH}',
                            style: const TextStyle(color: AppColor.contentText)
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            height: screenHeight * 0.12,
            color: Colors.transparent,
            child: Container(
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    key: const Key("ScanRecall_Button"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.mainText,
                      // Thay đổi màu nút dựa trên trạng thái
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      fixedSize: const Size(170.0, 50.0), // Kích thước cố định
                    ),
                    onPressed: () async {
                      await _showScanMethodDialog();
                    },
                    child:
                        // (_isContinuousCall)
                        //     ? Text('Dừng quét', style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.06))
                        //     :
                        Text('Quét mã thu hồi',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.055)),
                  ),
                  ElevatedButton(
                    key: const Key("Sync_Button"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFd5a529),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      fixedSize: const Size(150.0, 50.0),
                    ),
                    onPressed: () {
                      if (tagCount == 0) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text(
                                "Không thể đồng bộ",
                                style: TextStyle(
                                  color: AppColor.mainText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: const Text(
                                "Vui lòng kiểm tra lại số lượng quét.",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColor.mainText,
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            AppColor.mainText),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            10.0), // Điều chỉnh độ cong của góc
                                      ),
                                    ),
                                    fixedSize: MaterialStateProperty.all<Size>(
                                        const Size(100.0, 30.0)),
                                  ),
                                  child: const Text(
                                    "Đóng",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(); // Đóng cửa sổ dialog
                                  },
                                )
                              ],
                            );
                          },
                        );
                      } else {
                        if(widget.isSurplusGoodRecall){
                          _showRecallConfirmationDialog(
                              "Xác nhận thu hồi hủy bỏ", () {
                            postDataRecal(); // Gọi API khi xác nhận
                          });
                        }else{
                          _showRecallConfirmationDialog(
                              "Xác nhận thu hồi Nhiễu (Xuất dư)", () {
                            putWearhouseRecal(); // Gọi API khi xác nhận
                          });
                        }


                        // Show dialog for recall method
                        // showDialog(
                        //   context: context,
                        //   builder: (BuildContext context) {
                        //     String _selectedRecallOption =
                        //         ''; // Biến lưu trữ lựa chọn của người dùng
                        //     return StatefulBuilder(
                        //       builder: (context, setState) {
                        //         return AlertDialog(
                        //           title: const Text(
                        //             "Hình thức thu hồi?",
                        //             style: TextStyle(
                        //               color: AppColor.mainText,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //           content: Container(
                        //             child: Column(
                        //               mainAxisSize: MainAxisSize.min,
                        //               children: <Widget>[
                        //                 GestureDetector(
                        //                   onTap: () {
                        //                     setState(() {
                        //                       _selectedRecallOption = "huy_bo";
                        //                     });
                        //                   },
                        //                   child: Container(
                        //                     padding: const EdgeInsets.symmetric(
                        //                         vertical: 8.0),
                        //                     // Khoảng cách bên trong
                        //                     child: Row(
                        //                       children: <Widget>[
                        //                         Radio<String>(
                        //                           value: "huy_bo",
                        //                           groupValue:
                        //                               _selectedRecallOption,
                        //                           onChanged: (String? value) {
                        //                             setState(() {
                        //                               _selectedRecallOption =
                        //                                   value!;
                        //                             });
                        //                           },
                        //                           activeColor:
                        //                               const Color(0xFFd5a529),
                        //                           // Màu khi được chọn
                        //                           fillColor:
                        //                               MaterialStateProperty.all<
                        //                                   Color>(
                        //                             _selectedRecallOption ==
                        //                                     "huy_bo"
                        //                                 ? const Color(
                        //                                     0xFFd5a529) // Màu khi được chọn
                        //                                 : const Color(
                        //                                     0xFF097746), // Màu mặc định
                        //                           ),
                        //                         ),
                        //                         const SizedBox(width: 10.0),
                        //                         // Khoảng cách giữa Radio và Text
                        //                         const Text(
                        //                           "Thu hồi hủy bỏ",
                        //                           style: TextStyle(
                        //                               color: AppColor.mainText,
                        //                               fontSize: 18.0),
                        //                         ),
                        //                       ],
                        //                     ),
                        //                   ),
                        //                 ),
                        //                 GestureDetector(
                        //                   onTap: () {
                        //                     setState(() {
                        //                       _selectedRecallOption =
                        //                           "nhap_kho";
                        //                     });
                        //                   },
                        //                   child: Container(
                        //                     padding: const EdgeInsets.symmetric(
                        //                         vertical: 8.0),
                        //                     // Khoảng cách bên trong
                        //                     child: Row(
                        //                       children: <Widget>[
                        //                         Radio<String>(
                        //                           value: "nhap_kho",
                        //                           groupValue:
                        //                               _selectedRecallOption,
                        //                           onChanged: (String? value) {
                        //                             setState(() {
                        //                               _selectedRecallOption =
                        //                                   value!;
                        //                             });
                        //                           },
                        //                           activeColor:
                        //                               const Color(0xFFd5a529),
                        //                           // Màu khi được chọn
                        //                           fillColor:
                        //                               MaterialStateProperty.all<
                        //                                   Color>(
                        //                             _selectedRecallOption ==
                        //                                     "nhap_kho"
                        //                                 ? const Color(
                        //                                     0xFFd5a529) // Màu khi được chọn
                        //                                 : const Color(
                        //                                     0xFF097746), // Màu mặc định
                        //                           ),
                        //                         ),
                        //                         const SizedBox(width: 10.0),
                        //                         // Khoảng cách giữa Radio và Text
                        //                         const Expanded(
                        //                           // Đảm bảo rằng văn bản có thể giãn ra toàn bộ chiều ngang còn lại
                        //                           child: Text(
                        //                             "Thu hồi nhiễu (Xuất dư)",
                        //                             style: TextStyle(
                        //                                 color:
                        //                                     AppColor.mainText,
                        //                                 fontSize: 18.0),
                        //                           ),
                        //                         ),
                        //                       ],
                        //                     ),
                        //                   ),
                        //                 ),
                        //               ],
                        //             ),
                        //           ),
                        //           actions: <Widget>[
                        //             TextButton(
                        //               style: ButtonStyle(
                        //                 backgroundColor:
                        //                     MaterialStateProperty.all<Color>(
                        //                         AppColor.mainText),
                        //                 shape: MaterialStateProperty.all<
                        //                     RoundedRectangleBorder>(
                        //                   RoundedRectangleBorder(
                        //                     borderRadius: BorderRadius.circular(
                        //                         10.0), // Điều chỉnh độ cong của góc
                        //                   ),
                        //                 ),
                        //                 fixedSize:
                        //                     MaterialStateProperty.all<Size>(
                        //                         const Size(100.0, 30.0)),
                        //               ),
                        //               child: const Text(
                        //                 "Hủy",
                        //                 style: TextStyle(color: Colors.white),
                        //               ),
                        //               onPressed: () {
                        //                 Navigator.of(context)
                        //                     .pop(); // Đóng dialog
                        //               },
                        //             ),
                        //             TextButton(
                        //               style: ButtonStyle(
                        //                 backgroundColor:
                        //                     MaterialStateProperty.all<Color>(
                        //                         AppColor.mainText),
                        //                 shape: MaterialStateProperty.all<
                        //                     RoundedRectangleBorder>(
                        //                   RoundedRectangleBorder(
                        //                     borderRadius: BorderRadius.circular(
                        //                         10.0), // Điều chỉnh độ cong của góc
                        //                   ),
                        //                 ),
                        //                 fixedSize:
                        //                     MaterialStateProperty.all<Size>(
                        //                         const Size(100.0, 30.0)),
                        //               ),
                        //               child: const Text(
                        //                 "OK",
                        //                 style: TextStyle(color: Colors.white),
                        //               ),
                        //               onPressed: () {
                        //                 Navigator.of(context)
                        //                     .pop(); // Đóng dialog
                        //                 if (_selectedRecallOption == "huy_bo") {
                        //                   _showRecallConfirmationDialog(
                        //                       "Xác nhận thu hồi hủy bỏ", () {
                        //                     postDataRecal(); // Gọi API khi xác nhận
                        //                   });
                        //                 } else if (_selectedRecallOption ==
                        //                     "nhap_kho") {
                        //                   _showRecallConfirmationDialog(
                        //                       "Xác nhận thu hồi Nhiễu (Xuất dư)",
                        //                       () {
                        //                     putWearhouseRecal(); // Gọi API khi xác nhận
                        //                   });
                        //                 }
                        //               },
                        //             ),
                        //           ],
                        //         );
                        //       },
                        //     );
                        //   },
                        // );
                      }
                    },
                    child: Text(

                      'Đồng bộ', // Sync Button
                      style: TextStyle(
                          color: Colors.white, fontSize: screenWidth * 0.055),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // )
        ));
  }
}
