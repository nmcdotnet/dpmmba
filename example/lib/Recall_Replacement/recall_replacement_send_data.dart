import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rfid_c72_plugin/rfid_c72_plugin.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'dart:collection';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rfid_c72_plugin_example/Utils/DeviceActivities/DataReadOptions.dart';

//import '../Barcode_Scanner_By_Camera/barcode_scanner_by_camera.dart';
import '../Barcode_Scanner_By_Camera/barcode_scanner_by_camera.dart';
import '../UserDatatypes/user_datatype.dart';
import '../Utils/DeviceActivities/DataProcessing.dart';
import '../Utils/DeviceActivities/connectionNotificationRSeries.dart';
import '../Utils/app_color.dart';
import '../main.dart';
import '../utils/common_functions.dart';
import 'dart:async';
import '../Assign_Packing_Information/model_information_package.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_config.dart';
import '../utils/scan_count_modal.dart';
import '../utils/key_event_channel.dart';
import 'recall_replacement_model.dart';
import 'recall_replacement_database.dart';

class SendDataRecallReplacement extends StatefulWidget {
  final CalendarRecallReplacement event;
  final Function(CalendarRecallReplacement) onDeleteEvent;

  const SendDataRecallReplacement(
      {Key? key, required this.event, required this.onDeleteEvent})
      : super(key: key);

  @override
  State<SendDataRecallReplacement> createState() =>
      _SendDataRecallReplacementState();
}

class _SendDataRecallReplacementState extends State<SendDataRecallReplacement> {
  //#region Variables
  final StreamController<int> _updateStreamController =
      StreamController<int>.broadcast(); // Tạo StreamController
  late CalendarRecallReplacement event;
  final CalendarRecallReplacementDatabaseHelper databaseHelper =
      CalendarRecallReplacementDatabaseHelper();
  String _platformVersion = 'Unknown';
  final bool _isHaveSavedData = false;
  final bool _isStarted = false;
  final bool _isEmptyTags = false;
  bool _isConnected = false;
  bool _isLoading = true;
  int _totalEPC = 0, _invalidEPC = 0, _scannedEPC = 0;
  int currentPage = 0;
  int itemsPerPage = 5;
  late CalendarRecallReplacementDatabaseHelper _databaseHelper;
  List<TagEpcLDB> paginatedData = [];
  int targetTotalEPC = 100;
  late Timer _timer;
  final TextEditingController _agencyNameController = TextEditingController();
  final TextEditingController _goodsNameController = TextEditingController();
  BarcodeScannerInPhoneController _barcodeScannerInPhoneController =
      BarcodeScannerInPhoneController();
  bool confirm = false;
  List<TagEpcLDB> _data = [];
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
  int scannedTagsCount = 0;
  final _storage = const FlutterSecureStorage();
  final _storageRecallReplace = const FlutterSecureStorage();
  String _selectedAgencyName = '';
  String _selectedGoodsName = '';
  int tagCount = 0;
  int tagRecallReplaceCount = 0;
  bool _isSingleCall = false;
  bool _is2dscanCall = false;
  AudioPlayer _audioPlayer = AudioPlayer();
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
  bool showConfirmationDialog = false;
  bool _isScanningMethodSelected =
      false; // Trạng thái để kiểm tra phương thức quét đã chọn hay chưa
  String _selectedScanningMethod = 'qr'; // Lưu trữ phương thức quét đã chọn
  bool isShowModal = false;
  List<EPCInforRecall> EPCInforRecalls = [];
  List<EPCInforRecall> EPCInforReplaces = [];
  bool _isScanningStarted = false; // Kiểm tra xem việc quét đã bắt đầu chưa
  bool _isScanningRecallReplaceStarted =
      false; // Kiểm tra xem việc quét đã bắt đầu chưa
  bool isRecallScan = false; // Mặc định là quét mã thu hồi
  List<String> tagRecallReplaceList = [];
  List<String> tagsList = [];
  bool _isClickRecallScanButton = false;
  bool _isClickReplaceScanButton = false;
  bool _isClickConfirmScanMethod = false;
  String extractedCode = '';
  String getResult = '';
  String? result;

  // String IP = 'http://192.168.19.69:5088';
  // String IP = 'http://192.168.19.180:5088';
  // String IP = 'http://192.168.15.183:5010';
  // String IP = 'https://jvf-admin.rynansaas.com';

  bool scanStatusR5 = false;

  //#endregion Variables

  @override
  void initState() {
    super.initState();
    event = widget.event;
    _databaseHelper = CalendarRecallReplacementDatabaseHelper();
    _initDatabase();
    initPlatformState();
    loadSuccessfullySaved(event.idLTHTT);
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
      // Listen tag data from R5
      if (currentDevice != Device.rSeries) return;
      // for (var item in tagList) {
      //   print("du lieu nhan duoc + $item");
      // }

      var newData = DataProcessing.ConvertToTagEpcLDBList(tagList);
      // if(newData.isNotEmpty){
      //   print("du lieu nhan duọc " + newData.first.epc);
      // }
      updateTagsForR5(newData);
    });
    UHFBlePlugin.setScanningStatusCallback((scanStatus) {
      // key ?
      scanStatusR5 = scanStatus;
      _toggleScanningForR5();
    });
  }

  Future<void> _initDatabase() async {
    await _databaseHelper.initDatabase();
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamController.close();
    closeAll();
  }

  closeAll() {
    RfidC72Plugin.close;
    RfidC72Plugin.closeScan;
  }

// init for C72,C5
  Future<void> initPlatformState() async {
    String platformVersion;
    print('StrDebug: initPlatformState');
    try {
      platformVersion = (await RfidC72Plugin.platformVersion)!;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    // RfidC72Plugin.tagsStatusStream.receiveBroadcastStream().listen((barcode) {
    //   print('Barcode scanned: $barcode');
    // });
    RfidC72Plugin.connectedStatusStream
        .receiveBroadcastStream()
        .listen(updateIsConnected);
    RfidC72Plugin.tagsStatusStream.receiveBroadcastStream().listen(updateTags);
    if (!_isClickRecallScanButton && !_isClickReplaceScanButton) {
      RfidC72Plugin.barcodeStatusStream
          .receiveBroadcastStream()
          .listen(updateTags);
    }
    await RfidC72Plugin.connect;
    // await RfidC72Plugin.connectBarcode; //connect barcode
    await _initDatabase();
    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
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

  Future<void> updateTagsForR5(List<TagEpcLDB> newData) async {
    var result = newData.first.epc;

    // QR Code scanner
    if (result.toString().startsWith('http') ||
        result.toString().contains('://')) {
      String? extractedCode = _extractCodeFromUrl(result); // get data from url
      if (extractedCode != null) {
        _data.add(TagEpcLDB(epc: extractedCode));
        _playScanSound();
        if (mounted) {
          setState(() {
            isScanning = false; // Đánh dấu đã quét xong
            successfullySaved = _data.length; // Cập nhật trạng thái
          });
        }
        sendUpdateEvent(successfullySaved);
        //  await RfidC72Plugin.stop;
        await DataReadOptions.readTagsAsync(false, currentDevice);
        setState(() {
          _isSingleCall = false;
        });
        await _showConfirmationDialog();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }
    // Scan RFID (Single Read)
    else {
      if (_data.isEmpty) {
        if (newData.isNotEmpty) {
          TagEpcLDB firstTag = newData.first;
          _data.add(firstTag);
          _playScanSound();
          if (mounted) {
            setState(() {
              isScanning = false;
              successfullySaved = _data.length;
            });
          }
          sendUpdateEvent(successfullySaved);

          await DataReadOptions.readTagsAsync(false, currentDevice);
          setState(() {
            _isSingleCall = false;
          });

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); //Close modal
          }
          await _showConfirmationDialog();
        }
      }
    }
  }

  // Update tags for C5
  void updateTags(dynamic result) async {
    if (currentDevice != Device.cSeries &&
        currentDevice != Device.cameraBarcodes) return;

    // QR Code scanner
    if (result.toString().startsWith('http') ||
        result.toString().contains('://')) {
      String? extractedCode = _extractCodeFromUrl(result);
      if (extractedCode != null) {
        _data.add(TagEpcLDB(epc: extractedCode));
        _playScanSound();

        if (mounted) {
          setState(() {
            isScanning = false;
            successfullySaved = _data.length;
          });
        }
        sendUpdateEvent(successfullySaved);
        await DataReadOptions.readTagsAsync(false, currentDevice);
        setState(() {
          _isSingleCall = false;
        });
        // Close scanning modal, close connection and show confirmation dialog
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await RfidC72Plugin.stopScan;
          await RfidC72Plugin.closeScan;
        }
        await _showConfirmationDialog();
      }
    }

    // Scan RFID (Single Read)
    else {
      if (_data.isEmpty) {
        List<TagEpcLDB> newData = TagEpcLDB.parseTags(result);
        if (newData.isNotEmpty) {
          TagEpcLDB firstTag = newData.first;
          _data.add(firstTag);
          _playScanSound();

          if (mounted) {
            setState(() {
              isScanning = false;
              successfullySaved = _data.length;
            });
          }
          sendUpdateEvent(successfullySaved);
          await DataReadOptions.readTagsAsync(false, currentDevice);
          setState(() {
            _isSingleCall = false;
          });
          if (mounted) {
            Navigator.of(context, rootNavigator: true)
                .pop(); // Close scanning modal
          }
          await _showConfirmationDialog();
        }
      }
    }
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
      final dbHelper = CalendarRecallReplacementDatabaseHelper();

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
                  future: loadData(event.idLTHTT),
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
                          String epcString = CommonFunction()
                              .hexToString(snapshot.data![index].epc);
                          // print(epcString);
                          return ListTile(
                            title: Text(
                              '${index + 1}. $epcString',
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

  void _showRecallReplaceChipInformation(BuildContext context) {
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
                  future: loadRecallReplaceData(event.idLTHTT),
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
                          String epcString = snapshot.data![index].epc;
                          // print(epcString);
                          return ListTile(
                            title: Text(
                              '${index + 1}. $epcString',
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
    if (widget.event.idLTHTT != null) {
      // Giả sử widget.event là sự kiện được chọn và có thuộc tính id
      List<TagEpcLDB> tags = await loadData('recall_${event.idLTHTT}');
      setState(() {
        tagCount = tags.length; // Cập nhật số lượng tags vào biến trạng thái
        tagsList = tags.map((tag) => tag.epc).toList();
      });
    }
  }

  void loadRecallReplaceTagCount() async {
    if (widget.event.idLTHTT != null) {
      // Giả sử widget.event là sự kiện được chọn và có thuộc tính id
      List<TagEpcLDB> tag =
          await loadRecallReplaceData('replace_${event.idLTHTT}');
      setState(() {
        tagRecallReplaceCount =
            tag.length; // Cập nhật số lượng tags vào biến trạng thái
        tagRecallReplaceList = tag.map((tag) => tag.epc).toList();
      });
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

  // Hộp thoại xác nhận dữ liệu sau khi quét
  Future<void> _showConfirmationDialog() async {
    // print("isRecallScan: $isRecallScan");
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
                  // Giới hạn chiều cao của Container chứa ListTile
                  height: 100, // Hoặc một giá trị phù hợp với nhu cầu của bạn
                  child: _data.isNotEmpty
                      ? ListTile(
                          title: Text(
                            '1. ${_convertTagIfNeeded(_data.last.epc)}',
                            // Chỉ hiển thị mã cuối cùng
                            style: const TextStyle(
                              color: AppColor.mainText,
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Không có mã nào được quét',
                            style: TextStyle(
                              color: AppColor.mainText,
                            ),
                          ),
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
              child: const Text(
                'Hủy Bỏ',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
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
            const SizedBox(width: 8),
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
                'Xác Nhận',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              onPressed: () async {
                // khi nhấn xác nhận
                // Chỉ lưu mã cuối cùng từ danh sách _data
                if (_data.isNotEmpty) {
                  if (isRecallScan) {
                    // Nếu là quét mã thu hồi
                    await saveData('recall_${event.idLTHTT}',
                        [_data.last]); // Ghi đè dữ liệu, chỉ lưu mã cuối cùng
                    await _storage.write(
                        key: 'recall_${event.idLTHTT}_length', value: '1');
                  } else {
                    // Nếu là quét mã thay thế
                    await saveRecallReplaceData('replace_${event.idLTHTT}',
                        [_data.last]); // Ghi đè dữ liệu, chỉ lưu mã cuối cùng
                    await _storageRecallReplace.write(
                        key: 'replace_${event.idLTHTT}_length', value: '1');
                  }
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                if (!_isClickConfirmScanMethod &&
                    _selectedScanningMethod == "rfid") {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
                setState(() {
                  loadTagCount();
                  loadRecallReplaceTagCount();
                  showConfirmationDialog = false;
                  //  _selectedScanningMethod = 'qr';
                  _isScanningStarted = false;
                  _isScanningRecallReplaceStarted = false;
                  _data.clear();
                });
              },
            ),
          ],
        );
      },
    ).then((_) async {
      showConfirmationDialog = false;
      _isSingleCall = false;
      // await RfidC72Plugin.stop; // stop scan RFID
      await DataReadOptions.readTagsAsync(false, currentDevice);
    });
  }

  String _convertTagIfNeeded(String tagepc) {
    // Kiểm tra nếu là EPC thì chuyển đổi, còn không thì để nguyên
    if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(tagepc)) {
      return CommonFunction().hexToString(tagepc);
    }
    return tagepc;
  }

  void _closeModal() {
    setState(() {
      isShowModal = false;
    });
  }

  void showModal() async {
    setState(() {
      isShowModal = true;
    });
    if (tagsList.isEmpty || tagRecallReplaceList.isEmpty) {
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
            content: const Text("Vui lòng kiểm tra lại dữ liệu quét.",
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
                  "Đóng",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                },
              )
            ],
          );
        },
      ).then((_) {
        _closeModal(); // Gọi hàm để đóng modal và cập nhật trạng thái
      });
    } else {
      _showInfoEPCRecallDialog();
    }
  }

  void _showInfoEPCRecallDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.90,
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColor.mainText,
                        size: 30.0,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Đóng modal
                      },
                    ),
                  ),
                  // Box chứa thông tin mã EPC bạn muốn thu hồi
                  _buildEPCInfoSection('Thông tin mã EPC bạn muốn thu hồi',
                      fetchEPCInfoRecallData()),
                  // Box chứa thông tin mã EPC bạn muốn thay thế
                  _buildEPCInfoSection('Thông tin mã EPC bạn muốn thay thế',
                      fetchEPCInfoReplaceData()),
                  // Nút "Bắt đầu đồng bộ"
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Center(
                        child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.mainText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 6.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        minimumSize:
                            const Size(200.0, 40.0), // Kích thước tối thiểu
                      ),
                      onPressed: () async {
                        await startSyncProcess();
                      },
                      child: const Text(
                        'Bắt đầu đồng bộ',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// Hàm tiện ích để xây dựng mỗi phần thông tin EPC
  Widget _buildEPCInfoSection(
      String title, Future<List<EPCInforRecall>> futureData) {
    return Expanded(
      child: Column(
        children: [
          // Header phần tiêu đề
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 5, 10, 0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColor.mainText,
                    ),
                    maxLines: 2, // Giới hạn số dòng tối đa
                    overflow: TextOverflow
                        .ellipsis, // Hiển thị dấu "..." nếu văn bản quá dài
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // FutureBuilder để hiển thị dữ liệu EPC
          Expanded(
            child: FutureBuilder<List<EPCInforRecall>>(
              future: futureData, // Gọi hàm lấy dữ liệu EPC
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Có lỗi xảy ra: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Không có dữ liệu EPC.'));
                }
                List<EPCInforRecall> epcData = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: epcData.length,
                  itemBuilder: (context, index) {
                    EPCInforRecall epcInfo = epcData[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 15),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Mã EPC: ',
                                  style: TextStyle(
                                      fontSize: 16, color: AppColor.mainText),
                                ),
                                TextSpan(
                                  text: epcInfo.EPC,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.mainText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Tên sản phẩm: ',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColor.mainText),
                                ),
                                TextSpan(
                                  text: epcInfo.ProductCode,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.mainText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Tình trạng Đóng bao: ',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColor.mainText),
                                ),
                                TextSpan(
                                  text: epcInfo.PackageStatus == 'true'
                                      ? 'Đã đóng bao'
                                      : ' ',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.mainText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Tình trạng Phân phối: ',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColor.mainText),
                                ),
                                TextSpan(
                                  text: epcInfo.DistributionStatus == 'true'
                                      ? 'Đã phân phối'
                                      : ' ',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.mainText),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Phân phối kho thuê: ',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColor.mainText),
                                ),
                                TextSpan(
                                  text:
                                      epcInfo.WarehouseRentalDistributionStatus ==
                                              'true'
                                          ? 'Đã phân phối kho thuê'
                                          : ' ',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.mainText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Không thể lưu',
            style: TextStyle(
                color: AppColor.mainText, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBarcodeConfirmationDialog() async {
    // print("isRecallScan: $isRecallScan");
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
                Container(
                  // Giới hạn chiều cao của Container chứa ListView.builder
                  height: 200, // Hoặc một giá trị phù hợp với nhu cầu của bạn
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      String tagepc = _data[index].epc;

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
                  if (_data.isNotEmpty) {
                    if (isRecallScan) {
                      // Nếu là quét mã thu hồi
                      await saveData(
                          'recall_${event.idLTHTT}', _data); // Ghi đè dữ liệu
                      await _storage.write(
                          key: 'recall_${event.idLTHTT}_length',
                          value: _data.length.toString());
                    } else {
                      // Nếu là quét mã thay thế
                      await saveRecallReplaceData(
                          'replace_${event.idLTHTT}', _data); // Ghi đè dữ liệu
                      await _storageRecallReplace.write(
                          key: 'replace_${event.idLTHTT}_length',
                          value: _data.length.toString());
                    }
                  }
                  Navigator.of(context).pop();
                  if (!_isClickConfirmScanMethod) {
                    Navigator.of(context).pop();
                  }
                  setState(() {
                    loadTagCount();
                    loadRecallReplaceTagCount();
                    showConfirmationDialog = false;
                    _selectedScanningMethod = 'qr';
                    _isScanningStarted = false;
                    _isScanningRecallReplaceStarted = false;
                    _data.clear();
                  });

                  //  Navigator.of(context).pop();
                }),
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

  String epcRecall = '';

  Future<List<EPCInforRecall>> fetchEPCInfoRecallData() async {
    List<EPCInforRecall> EPCInforRecalls = [];
    List<TagEpcLDB> allRFIDRecall = await loadData('recall_${event.idLTHTT}');

    // Gửi yêu cầu GET tới API với mã EPC
    for (TagEpcLDB tag in allRFIDRecall) {
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(tag.epc) &&
          tag.epc.length % 2 == 0) {
        //     // Chỉ khi nào chuỗi là hex hợp lệ mới chuyển đổi
        epcRecall = CommonFunction().hexToString(tag.epc);
      } else {
        //     // Đối với các chuỗi không phải hex, giữ nguyên giá trị ban đầu
        epcRecall = tag.epc;
      }
      // print('epc: $epcRecall');
      // print(tag.epc);
      // String epcRecall = CommonFunction().hexToString(tag.epc);
      // String epcRecall = 'RJVD2400006C7HML';
      // List<String>allTag=[
      //       "RJVD2400004MVXML",
      //     ];
      // for (String epcRecall in allTag) {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.IP}/api/92B13354C5044351B6D29FF4575139D4/$epcRecall'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      // Kiểm tra trạng thái phản hồi
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'];

        // Nếu dữ liệu không rỗng, thêm vào danh sách
        if (data.isNotEmpty) {
          for (var item in data) {
            EPCInforRecalls.add(EPCInforRecall(
              EPC: item["MaEPC"],
              EPCStatus: item["TrangThaiEPC"],
              ProductCode: item["MaSanPham"],
              PackageAccountCode: item["MaTaiKhoanDongBao"],
              PackageScanDate: item["NgayQuetDongBao"],
              PackageStatus: item["TinhTrangDongBao"],
              PackagingDescription: item["MotaDongBao"],
              PackageCode: item["MaLichDongBao"],
              DistributionStatus: item["TinhTrangPhanPhoi"],
              DistributionScanDate: item["NgayQuetPhanPhoi"],
              DistributionDescription: item["MoTaPhanPhoi"],
              DistributionCode: item["MaPhanPhoi"],
              DistributionAccountCode: item["MaTaiKhoanPhanPhoi"],
              WarehouseRentalDistributionStatus:
                  item["TinhTrangPhanPhoiKhoThue"],
              WarehouseRentalDistributionScanDate: item["NgayQuetPPKT"],
              WarehouseRentalDistributionDescription:
                  item["MoTaPhanPhoiKhoThue"],
              WarehouseRentalDistributionCode: item["MaPhanPhoiKhoThue"],
              WarehouseRentalDistributionAccountCode: item["MaTaiKhoanPPKT"],
            ));
          }
          // print('Data fetched for : $data'); // In dữ liệu để kiểm tra
        } else {
          print('No data found for .'); // In thông báo nếu không có dữ liệu
        }
      } else {
        // throw Exception('Failed to load data: ${response.statusCode}'); // Thông báo lỗi nếu không thành công'
        print('Failed to load data: ${response.statusCode}');
      }
    }

    return EPCInforRecalls; // Trả về danh sách dữ liệu EPC đã thu thập
  }

  Future<List<EPCInforRecall>> fetchEPCInfoReplaceData() async {
    // Khởi tạo danh sách exportCodes
    // EPCInforReplaces = [
    //   EPCInforRecall(
    //     EPC: "RCMA240DP7ZTOL1C1",
    //     PackageStt: "Đã Đóng Bao",
    //     DistributionStt: "Đã Phân Phối Đến Đại Lý",
    //     DistributionWearhouseStt: "",
    //     GoodsName: "TPH-G01C",
    //   ),
    // ];
    List<EPCInforRecall> EPCInforRecalls = [];
    List<TagEpcLDB> allRFIDRecall =
        await loadRecallReplaceData('replace_${event.idLTHTT}');

    // Gửi yêu cầu GET tới API với mã EPC
    for (TagEpcLDB tag in allRFIDRecall) {
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(tag.epc) &&
          tag.epc.length % 2 == 0) {
        // //     // Chỉ khi nào chuỗi là hex hợp lệ mới chuyển đổi
        epcRecall = CommonFunction().hexToString(tag.epc);
      } else {
        // //     // Đối với các chuỗi không phải hex, giữ nguyên giá trị ban đầu
        epcRecall = tag.epc;
      }
      //
      //   // String epcRecall = CommonFunction().hexToString(tag.epc);
      //   print("mã thay thế $epcRecall");
      //   String epcRecall = 'RJVD2400006C7HML';
      // List<String>allTag=[
      //   "RJVD240000485SML",
      // ];
      // for (String epcRecall in allTag) {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.IP}/api/92B13354C5044351B6D29FF4575139D4/$epcRecall'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      // Kiểm tra trạng thái phản hồi
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'];
        // Nếu dữ liệu không rỗng, thêm vào danh sách
        if (data.isNotEmpty) {
          for (var item in data) {
            EPCInforRecalls.add(EPCInforRecall(
              EPC: item["MaEPC"],
              EPCStatus: item["TrangThaiEPC"],
              ProductCode: item["MaSanPham"],
              PackageAccountCode: item["MaTaiKhoanDongBao"],
              PackageScanDate: item["NgayQuetDongBao"],
              PackageStatus: item["TinhTrangDongBao"],
              PackagingDescription: item["MotaDongBao"],
              PackageCode: item["MaLichDongBao"],
              DistributionStatus: item["TinhTrangPhanPhoi"],
              DistributionScanDate: item["NgayQuetPhanPhoi"],
              DistributionDescription: item["MoTaPhanPhoi"],
              DistributionCode: item["MaPhanPhoi"],
              DistributionAccountCode: item["MaTaiKhoanPhanPhoi"],
              WarehouseRentalDistributionStatus:
                  item["TinhTrangPhanPhoiKhoThue"],
              WarehouseRentalDistributionScanDate: item["NgayQuetPPKT"],
              WarehouseRentalDistributionDescription:
                  item["MoTaPhanPhoiKhoThue"],
              WarehouseRentalDistributionCode: item["MaPhanPhoiKhoThue"],
              WarehouseRentalDistributionAccountCode: item["MaTaiKhoanPPKT"],
            ));
          }
          // print('Data fetched for : $data'); // In dữ liệu để kiểm tra
        } else {
          print('No data found for .'); // In thông báo nếu không có dữ liệu
        }
      } else {
        // throw Exception('Failed to load data: ${response.statusCode}'); // Thông báo lỗi nếu không thành công'
        print('Failed to load data: ${response.statusCode}');
      }
    }

    return EPCInforRecalls;
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

  Future<void> _toggleScanningForR5() async {
    try {
      if (currentDevice != Device.rSeries ||
          _selectedScanningMethod != "rfid" ||
          _isDialogShown) return;
      await RfidC72Plugin.stopScan;
      await RfidC72Plugin.closeScan;
      // Check connection
      var isConnected = await UHFBlePlugin.getConnectionStatus();
      if (!isConnected && mounted) {
        ConnectionNotificationRSeries.showConnectionStatus(context, false);
        return;
      }
      // Check options
      if (!_isClickRecallScanButton && !_isClickReplaceScanButton) {
        return;
      }

      if (_isSingleCall) {
        await DataReadOptions.readTagsAsync(false, currentDevice);
        _isSingleCall = false;
      } else {
        if (!showConfirmationDialog) {
          await DataReadOptions.readTagsAsync(true, currentDevice);
          _data.clear();
          _isSingleCall = true;
          showConfirmationDialog = true;
          if (!_isDialogShown) {
            _showScanningModal(); //R5
          }
        }
      }
      setState(() {
        _isShowModal = _isSingleCall;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _toggleScanningForC5() async {
    try {
      if ((currentDevice != Device.cSeries &&
              currentDevice != Device.cameraBarcodes) ||
          _selectedScanningMethod != "rfid" ||
          _isDialogShown) {
        return;
      }
      if (!_isClickRecallScanButton && !_isClickReplaceScanButton) {
        return;
      }
      await RfidC72Plugin.stopScan;
      await RfidC72Plugin.closeScan;

      if (_is2dscanCall) {
        setState(() {
          _is2dscanCall = false;
        });
      }
      await RfidC72Plugin.connect;
      if (_isSingleCall) {
        await RfidC72Plugin.stop;
        _isSingleCall = false;
      } else {
        if (!showConfirmationDialog) {
          await RfidC72Plugin.startSingle;
          _data.clear();
          showConfirmationDialog = true;
          _isSingleCall = true;
          if (!_isDialogShown) {
            _showScanningModal(); //C5
          }
        }
      }
      setState(() {
        _isShowModal = _isSingleCall;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _showBarcodeScanningModal() async {
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
    ).then((_) {
      _is2dscanCall = false; // Đặt lại trạng thái quét sau khi quét xong
    });

    // Đóng dialog sau 5 giây
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted && _is2dscanCall) {
        // dùng mounted để kiểm tra context còn tồn tại
        Navigator.of(context).pop();
        _is2dscanCall = false;
        // await RfidC72Plugin.stopScan;
        // await RfidC72Plugin.closeScan;
      }
    });
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

  Future<void> _toggleBarCodeScanning() async {
    if (currentDevice == Device.cameraBarcodes ||
        currentDevice == Device.rSeries ||
        _selectedScanningMethod != "qr") {
      return;
    }
    if (!_isClickRecallScanButton && !_isClickReplaceScanButton) {
      return;
    }
    if (mounted) {
      setState(() {
        _is2dscanCall = !_is2dscanCall; // False => True , state scan
      });
    }

    if (_is2dscanCall) {
      _showBarcodeScanningModal();
      await RfidC72Plugin.connectBarcode;
      await RfidC72Plugin.scanBarcode;

      if (extractedCode.isNotEmpty) {
        setState(() {
          _data.clear();
          _data.add(
              TagEpcLDB(epc: extractedCode)); // Thêm mã QR vào danh sách EPC
          _totalEPC = _data.length; // Cập nhật số lượng EPC quét được
          _is2dscanCall = false; // Dừng quét
        });

        await RfidC72Plugin.stopScan;
        await RfidC72Plugin.closeScan;
        if (_barcodeSubscription != null) {
          await _barcodeSubscription?.cancel();
          _barcodeSubscription = null;
        }

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

  String? _extractCodeFromUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.queryParameters['id']; // Trả về phần mã phía sau `id=`
    } catch (e) {
      print("Error parsing URL: $e");
      return null; // Trả về null nếu có lỗi khi phân tích URL
    }
  }

  void _showScanningModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return (_isShowModal)
            ? Center(
                child: Dialog(
                  elevation: 0,
                  backgroundColor: const Color.fromARGB(255, 43, 78, 128),
                  child: SizedBox(
                    height: 300,
                    child: Column(
                      children: [
                        const Text("RFID",
                            style: TextStyle(color: Colors.white)),
                        SavedTagsModal(
                          updateStream: _updateStreamController.stream,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox
                .shrink(); //một widget rỗng được hiển thị nếu _isShowModal = false
      },
    ).then(
        (_) => _isDialogShown = false); // Cập nhật trạng thái khi dialog đóng
    _isDialogShown = true;

    // Đóng dialog sau 1 giây
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isDialogShown) {
        // dùng mounted để kiểm tra context còn tồn tại
        _isDialogShown = false;
        Navigator.of(context).pop();
        _showConfirmationDialog();
      }
    });
  }

  Future<void> startSyncProcess() async {
    try {
      // Gọi fetch để lấy dữ liệu từ API trước khi thực hiện đồng bộ
      List<EPCInforRecall> epcRecallList = await fetchEPCInfoRecallData();
      List<EPCInforRecall> epcReplaceList = await fetchEPCInfoReplaceData();

      // Tạo các map để lưu dữ liệu tạm thời
      Map<String, EPCInforRecall> epcRecallMap = {};
      Map<String, EPCInforRecall> epcReplaceMap = {};

      // Điền dữ liệu vào epcRecallMap
      for (var epcRecall in epcRecallList) {
        epcRecallMap[epcRecall.EPC] = epcRecall;
        epcReallString = epcRecall.EPC;
      }

      // Điền dữ liệu vào epcReplaceMap
      for (var epcReplace in epcReplaceList) {
        epcReplaceMap[epcReplace.EPC] = epcReplace;
        epcReplaceString = epcReplace.EPC;
      }

      // Sau khi lấy và lưu dữ liệu tạm thời, gọi các hàm putRecal và putReplace
      await putRecal(epcRecallList, epcReplaceMap);
      await putReplace(epcReplaceList, epcRecallMap);
    } catch (e) {
      print("Có lỗi xảy ra khi đồng bộ: $e");
      // Bạn có thể hiển thị thông báo lỗi nếu cần
    }
  }

  Future<void> putRecal(List<EPCInforRecall> epcRecallList,
      Map<String, EPCInforRecall> epcReplaceMap) async {
    print('Thu hồi được gọi');
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

    String eventId = event.idLTHTT; // ID của lịch
    int successCount = 0;
    int failCount = 0;
    String LDTH = widget.event.ghiChuLTHTT; // Lấy ghi chú của sự kiện
    String? maTK = await _getMaTKFromSecureStorage();
    DateTime ngayPost = DateTime.now(); // Định dạng ngày gửi
    String postDate = ngayPost.toIso8601String();
    bool networkErrorOccurred = false;

    String key =
        getSentTagsKey(event.idLTHTT); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureLTHStorage.read(key: key);
    List<String> sentTags =
        sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    String baseUrl = '${AppConfig.IP}/api/9215A3F22E3C4E529042582F399CF53D';

    final DateTime now = DateTime.now();
    String formattedTimestamp =
        now.millisecondsSinceEpoch.toString().padLeft(18, '0');

    for (var epcRecall in epcRecallList) {
      String epcString = epcRecall.EPC; // Lấy EPC từ danh sách recall
      String apiUrl = '$baseUrl/$epcString';
      var replaceData = epcReplaceMap[epcReplaceString];

      if (!sentTags.contains(epcString)) {
        Map<String, dynamic> data = {
          "10ME": "${epcString}_${formattedTimestamp}",
          "10MTK": maTK,
          "2LDTH": LDTH,
          "4NTH": postDate,
          "1MESP": epcString,
          "1METT": replaceData?.EPC ?? " ",
          "30TT": "TT001",
          "3MLĐB": epcRecall.PackageCode ?? " ",
          "1TTĐB": "true",
          "28GC": "Mã EPC được thay thế",
          "16MT": "ERROR_0000",
          "2MPP": epcRecall.DistributionCode ?? " ",
          "1TTPP": "true",
          "29GC": "Mã EPC được thay thế",
          "15MT": "ERROR_0000",
          "1TTPPKT": "true",
          "18MT": "ERROR_0000",
          "30GC": "Mã EPC được thay thế",
          "3MPPKT": epcRecall.WarehouseRentalDistributionCode ?? " ",
          "3SĐQ": 0,
          "2SQTC": 0,
          "3SGTC": 0,
          "2SLĐQ": 0,
          "4SGTC": 0,
          "3SQTC": 0
        };
        print("thu hồi: $apiUrl");
        print(data);
        try {
          final response = await http.put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            sentTags.add(epcString);
            await secureLTHStorage.write(key: key, value: jsonEncode(sentTags));
            final responseData = json.decode(response.body);
            if (responseData["success"] == true) {
              successCount++;
            } else {
              failCount++;
            }
          } else {
            failCount++;
          }
        } on SocketException {
          networkErrorOccurred = true;
          break;
        } catch (e) {
          print("Error occurred while posting data for EPC $epcString: $e");
          failCount++;
        }
      }
    }

    Navigator.pop(context); // Đóng dialog

    if (networkErrorOccurred) {
      // Hiển thị thông báo lỗi kết nối
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Mất kết nối!",
                style: TextStyle(
                    color: AppColor.mainText, fontWeight: FontWeight.bold)),
            content: const Text("Vui lòng kiểm tra kết nối mạng.",
                style: TextStyle(fontSize: 18, color: AppColor.mainText)),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng cửa sổ dialog
                },
              ),
            ],
          );
        },
      );
    }

    // Lưu kết quả vào cơ sở dữ liệu và đếm số thành công, thất bại
    final dbHelper = CalendarRecallReplacementDatabaseHelper();
    await dbHelper.syncEvent(event);
    saveCountsToStorage(eventId, successCount, failCount,
        DateFormat('dd/MM/yyyy').format(ngayPost));
  }

  String epcReallString = '';
  String epcReplaceString = '';

  Future<void> putReplace(List<EPCInforRecall> epcReplaceList,
      Map<String, EPCInforRecall> epcRecallMap) async {
    print('Đang thực hiện đồng bộ thay thế...');

    showDialog(
      context: context,
      barrierDismissible: false,
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

    String eventId = event.idLTHTT;
    int successCount = 0;
    int failCount = 0;
    String LDTH = widget.event.ghiChuLTHTT;
    String? maTK = await _getMaTKFromSecureStorage();
    DateTime ngayPost = DateTime.now();
    String postDate = ngayPost.toIso8601String();
    bool networkErrorOccurred = false;

    String key = getSentTagsKey(eventId);
    String? sentTagsJson = await secureLTHStorage.read(key: key);
    List<String> sentTags =
        sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    String baseUrl = '${AppConfig.IP}/api/FE9B89F49FB3471BAAB71A8DEDE3F9CB';

    final DateTime now = DateTime.now();
    String formattedTimestamp =
        now.millisecondsSinceEpoch.toString().padLeft(18, '0');

    for (var epcReplace in epcReplaceList) {
      String epcString = epcReplace.EPC;
      String apiUrl = '$baseUrl/$epcString';
      var recallData = epcRecallMap[epcReallString];

      if (!sentTags.contains(epcString)) {
        Map<String, dynamic> data = {
          "1MR": recallData?.EPC,
          "30TT": recallData?.EPCStatus ?? "TT001",
          "29MSP": recallData?.ProductCode ?? " ",
          "3MLĐB": recallData?.PackageCode ?? " ",
          "1TTĐB": "true",
          "28GC": "Mã EPC được thay thế",
          "16MT": recallData?.PackagingDescription ?? "ERROR_0000",
          "2ME": epcReplace.EPC,
          "12ME": "${epcReplace.EPC}_$formattedTimestamp",
          "30NT": recallData?.PackageScanDate ?? "$postDate",
          "32MSP": recallData?.ProductCode ?? " ",
          "17MTK": recallData?.PackageAccountCode ?? "user002",
          "2MPP": recallData?.DistributionCode ?? " ",
          "1TTPP": "true",
          "29GC": "Mã EPC được thay thế",
          "15MT": recallData?.DistributionDescription ?? "ERROR_0000",
          "29NT": recallData?.DistributionScanDate ?? "$postDate",
          "1ME": epcReplace.EPC ?? "A",
          "11ME": "${epcReplace.EPC}_$formattedTimestamp",
          "31MSP": recallData?.ProductCode ?? " ",
          "16MTK": recallData?.DistributionAccountCode ?? "user011",
          "1TTPPKT": "true",
          "30GC": "Mã EPC được thay thế",
          "18MT": recallData?.WarehouseRentalDistributionDescription ??
              "ERROR_0000",
          "8ME": epcReplace.EPC ?? "A",
          "13ME": "${epcReplace.EPC}_$formattedTimestamp",
          "3MPPKT": recallData?.WarehouseRentalDistributionCode ?? " ",
          "31NT":
              recallData?.WarehouseRentalDistributionScanDate ?? "$postDate",
          "33MSP": recallData?.ProductCode ?? "",
          "18MTK":
              recallData?.WarehouseRentalDistributionAccountCode ?? "user033",
          "3SĐQ": 0,
          "2SQTC": 0,
          "3SGTC": 0,
          "2SLĐQ": 0,
          "4SGTC": 0,
          "3SQTC": 0
        };
        print("replace: $apiUrl");
        print("replce: $data");
        try {
          final response = await http.put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            sentTags.add(epcString);
            await secureLTHStorage.write(key: key, value: jsonEncode(sentTags));
            final responseData = json.decode(response.body);
            if (responseData["success"] == true) {
              successCount++;
            } else {
              failCount++;
            }
          } else {
            failCount++;
          }
        } on SocketException {
          networkErrorOccurred = true;
          break;
        } catch (e) {
          print("Error occurred while posting data for EPC $epcString: $e");
          failCount++;
        }
      }
    }

    Navigator.pop(context);

    if (networkErrorOccurred) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Mất kết nối!",
                style: TextStyle(
                    color: AppColor.mainText, fontWeight: FontWeight.bold)),
            content: const Text("Vui lòng kiểm tra kết nối mạng.",
                style: TextStyle(fontSize: 18, color: AppColor.mainText)),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Đồng bộ thành công",
                style: TextStyle(
                    color: AppColor.mainText, fontWeight: FontWeight.bold)),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(AppColor.mainText),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  fixedSize:
                      MaterialStateProperty.all<Size>(const Size(100.0, 30.0)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
                  Navigator.pop(context, true);
                },
              ),
            ],
          );
        },
      );
    }

    final dbHelper = CalendarRecallReplacementDatabaseHelper();
    await dbHelper.syncEvent(event);
    saveCountsToStorage(eventId, successCount, failCount,
        DateFormat('dd/MM/yyyy').format(ngayPost));
  }

  Future<List<TagEpcLDB>> getTagEpcList(String key) async {
    return await loadData(event.idLTHTT);
  }

  Future<String> formatDataForFileWithTags(String key) async {
    StringBuffer buffer = StringBuffer();
    // Dữ liệu từ các thông tin khác
    buffer.writeln("Nội dung thu hồi: ${event.ghiChuLTHTT}");
    buffer.writeln("Số lượng quét: $tagCount");
    buffer.writeln("Ngày tạo lịch: ${event.ngayTaoLTHTT}");
    // Lấy danh sách TagEpcLBD từ loadData
    List<TagEpcLDB> tagEpcList = await getTagEpcList(event.idLTHTT);
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
          await formatDataForFileWithTags(event.idLTHTT); // Lấy chuỗi định dạng
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

  Future<void> scanRFID() async {}

  // Chọn phương thức quét cho thu hồi
  void _showScanMethodDialog() async {
    // await RfidC72Plugin.connectBarcode;
    showDialog(
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
                      // RfidC72Plugin.closeScan;
                      // RfidC72Plugin.connect;
                      KeyEventChannel(
                        // đăng ký dự kiện trước
                        onKeyReceived: checkCurrentDevice,
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
                    // Nếu chọn quét QR
                    onTap: () {
                      setStateModal(() {
                        _selectedScanningMethod = "qr";
                      });
                      KeyEventChannel(
                        onKeyReceived:
                            checkCurrentDevice, // đăng ký sự kiện đọc qr khi nhấn phím
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
                    Navigator.of(context).pop();
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
                    _isClickConfirmScanMethod = true;
                    Navigator.of(context).pop();
                    if (_selectedScanningMethod.isNotEmpty) {
                      if (_selectedScanningMethod == "rfid") {
                        checkCurrentDevice();
                      } else if (_selectedScanningMethod == "qr") {
                        if (currentDevice == Device.cameraBarcodes ||
                            currentDevice == Device.rSeries) {
                          scanQRCodeByCamera();
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

  void _showScanRecallReplaceMethodDialog() async {
    showDialog(
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
                      // RfidC72Plugin.closeScan;
                      // RfidC72Plugin.connect;
                      // KeyEventChannel(
                      //   onKeyReceived: checkCurrentDevice, // RFID quét
                      // ).initialize();
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
                    Navigator.of(context).pop();
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
                  // onPressed: () {
                  //   if (_selectedScanningMethod.isNotEmpty) {
                  //     Navigator.of(context).pop(true); // Trả về giá trị true
                  //   }
                  onPressed: () {
                    _isClickConfirmScanMethod = true;
                    // Navigator.of(context).pop(true);
                    Navigator.of(context).pop();
                    // Thực hiện hành động khi người dùng nhấn "OK" ở hộp thoại xác nhận
                    if (_selectedScanningMethod.isNotEmpty) {
                      // Dựa trên phương thức quét, khởi tạo KeyEventChannel với sự kiện tương ứng
                      if (_selectedScanningMethod == "rfid") {
                        // RfidC72Plugin.connect;
                        // RfidC72Plugin.closeScan;
                        if (currentDevice == Device.rSeries) {
                          _toggleScanningForR5();
                        } else {
                          _toggleScanningForC5();
                        }
                      } else if (_selectedScanningMethod == "qr") {
                        // RfidC72Plugin.close;
                        //quét bằng C5
                        if (currentDevice == Device.cameraBarcodes ||
                            currentDevice == Device.rSeries) {
                          scanQRCodeByCamera();
                          // only use camera phone to scan QR code
                        } else if (currentDevice == Device.cSeries) {
                          _toggleBarCodeScanning();
                        }
                        //  _toggleBarCodeScanning();
                        //quét bằng Camera
                        //  scanQRCodeByCamera();
                        // _simulateKeyEvent(139);
                      }
                    }
                    // Cập nhật trạng thái để nút chuyển thành "Bắt đầu quét"
                  },
                ),
              ],
            );
          },
        );
      },
    );
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
                'Lịch thu hồi',
                style: TextStyle(
                  fontSize: screenWidth * 0.07, // Kích thước chữ
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
                          saveDataWithTags(
                              event.idLTHTT, "${event.ghiChuLTHTT}");
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
                                      color: AppColor.mainText,
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
                                      fixedSize:
                                          MaterialStateProperty.all<Size>(
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
                                      fixedSize:
                                          MaterialStateProperty.all<Size>(
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
                            text: '${event.ghiChuLTHTT}',
                          ),
                        ],
                      ),
                    )),
                GestureDetector(
                  onTap: () {},
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
                                  text: 'Mã thu hồi\n ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.065),
                                ),
                                TextSpan(
                                  text: tagsList.isNotEmpty
                                      ? tagsList.map((epc) {
                                          // Kiểm tra nếu là chuỗi hex (chỉ có ký tự hợp lệ và độ dài hợp lý)
                                          if (RegExp(r'^[0-9a-fA-F]+$')
                                                  .hasMatch(epc) &&
                                              epc.length % 2 == 0) {
                                            return CommonFunction().hexToString(
                                                epc); // Chuyển hex sang chuỗi
                                          } else {
                                            return epc; // Đã ở dạng chuỗi, giữ nguyên
                                          }
                                        }).join('\n') // Hiển thị trên từng dòng
                                      : '', // Nếu chưa có mã
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Icon(Icons.navigate_next, color: AppColor.mainText, size: 30.0),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // if (_selectedScanningMethod.isNotEmpty) {
                    //   // Dựa trên phương thức quét, khởi tạo KeyEventChannel với sự kiện tương ứng
                    //   if (_selectedScanningMethod == "rfid") {
                    //     _showChipInformation(context);
                    //   } else if (_selectedScanningMethod == "qr") {
                    //     _showRecallReplaceChipInformation(context);
                    //   }
                    // }
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
                                  text: 'Mã thay thế\n ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.065),
                                ),
                                TextSpan(
                                  text: tagRecallReplaceList.isNotEmpty
                                      ? tagRecallReplaceList.map((epc) {
                                          // Kiểm tra nếu là chuỗi hex (chỉ có ký tự hợp lệ và độ dài hợp lý)
                                          if (RegExp(r'^[0-9a-fA-F]+$')
                                                  .hasMatch(epc) &&
                                              epc.length % 2 == 0) {
                                            return CommonFunction().hexToString(
                                                epc); // Chuyển hex sang chuỗi
                                          } else {
                                            return epc; // Đã ở dạng chuỗi, giữ nguyên
                                          }
                                        }).join('\n') // Hiển thị trên từng dòng
                                      : '', // Nếu chưa có mã
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Icon(Icons.navigate_next, color: AppColor.mainText, size: 30.0),
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
                            text: '${event.ngayTaoLTHTT}',
                          ),
                        ],
                      ),
                    )),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              height: screenHeight * 0.23, // Tăng chiều cao để đủ chỗ cho 3 nút
              color: Colors.transparent,
              child: Container(
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // Đảm bảo các nút nằm giữa
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Nút "Quét mã thu hồi"
                        ElevatedButton(
                          onPressed: () {
                            // print('_selectedScanningMethod: ${_selectedScanningMethod}');
                            setState(() {
                              _isClickRecallScanButton = true;
                            });
                            isRecallScan = true;
                            if (!_isScanningStarted) {
                              _showScanMethodDialog(); // Nếu chưa chọn phương thức, hiển thị hộp thoại chọn phương thức
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isScanningStarted
                                ? AppColor.mainText
                                : AppColor.mainText,
                            // Thay đổi màu nút dựa trên trạng thái
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            fixedSize:
                                const Size(160.0, 50.0), // Kích thước cố định
                          ),
                          child: Text(
                            'Quét mã thu hồi',
                            // Hiển thị nhãn dựa trên trạng thái
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth *
                                  0.05, // Điều chỉnh cỡ chữ phù hợp
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        // Nút "Quét mã thay thế"
                        ElevatedButton(
                          onPressed: () {
                            // print('_selectedScanningMethod: ${_selectedScanningMethod}');
                            //   RfidC72Plugin.connectBarcode;
                            _showScanRecallReplaceMethodDialog(); // Nếu chưa chọn phương thức, hiển thị hộp thoại chọn phương thức
                            setState(() {
                              isRecallScan = false;
                              _isClickReplaceScanButton = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isScanningRecallReplaceStarted
                                ? AppColor.mainText
                                : AppColor.mainText,
                            // Thay đổi màu nút dựa trên trạng thái
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            fixedSize:
                                const Size(165.0, 50.0), // Kích thước cố định
                          ),
                          child: Text(
                            'Quét mã thay thế',
                            // Hiển thị nhãn dựa trên trạng thái
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth *
                                  0.05, // Điều chỉnh cỡ chữ phù hợp
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Nút "Đồng bộ" nằm dưới hai nút trên
                    const SizedBox(height: 10),
                    // Thêm khoảng cách giữa hai hàng
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFd5a529), // Màu vàng
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        fixedSize:
                            const Size(350.0, 50.0), // Kích thước cố định
                      ),
                      onPressed: () {
                        showModal();
                      },
                      child: const Text(
                        'Đồng bộ',
                        style: TextStyle(fontSize: 22, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )));
  }
}
