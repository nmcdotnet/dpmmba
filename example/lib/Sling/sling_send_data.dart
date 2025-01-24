import 'package:flutter/material.dart';
import 'package:rfid_c72_plugin/rfid_c72_plugin.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:collection';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rfid_c72_plugin_example/Sling/sling_show_info.dart';
import 'package:rfid_c72_plugin_example/Sling/sling_tag_show.dart';
import 'package:rfid_c72_plugin_example/utils/common_functions.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../Distribution_Module/edit_celendar.dart';
import '../Distribution_Module/inventory_export_codes.dart';
import '../Distribution_Module/select_schedule_page.dart';
import '../Distribution_Module/showchip_informaton_page.dart';
import '../UserDatatypes/user_datatype.dart';
import '../Utils/DeviceActivities/DataProcessing.dart';
import '../Utils/DeviceActivities/DataReadOptions.dart';
import '../Utils/DeviceActivities/connectionNotificationRSeries.dart';
import '../Utils/app_color.dart';
import '../main.dart';
import '../utils/app_config.dart';
import '../Models/model.dart';
import '../Helpers/calendar_database_helper.dart';

import 'dart:convert';

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/key_event_channel.dart';
import '../utils/scan_count_modal.dart';

/*Distribution*/
class SlingSendData extends StatefulWidget {
  final Calendar event;
  final Function(Calendar) onDeleteEvent;

  const SlingSendData({Key? key, required this.event, required this.onDeleteEvent})
      : super(key: key);

  @override
  State<SlingSendData> createState() => _SlingSendDataState();
}

class _SlingSendDataState extends State<SlingSendData> {
  //Khai báo biến
  final StreamController<int> _updateStreamController =
  StreamController<int>.broadcast();
  late Calendar event;
  final CalendarDatabaseHelper databaseHelper = CalendarDatabaseHelper();
  String _platformVersion = 'Unknown';
  final bool _isHaveSavedData = false;
  final bool _isStarted = false;
  final bool _isEmptyTags = false;
  bool _isConnected = false;
  bool _isLoading = true;
  int _totalEPC = 0, _invalidEPC = 0, _scannedEPC = 0;
  int currentPage = 0;
  int itemsPerPage = 5;
  late CalendarDatabaseHelper _databaseHelper;
  List<TagEpc> paginatedData = [];
  int targetTotalEPC = 100;
  late Timer _timer;
  TextEditingController _agencyNameController = TextEditingController();
  TextEditingController _goodsNameController = TextEditingController();
  bool showchip = false;
  bool dadongbo = false;
  String? tenLNPP;
  List<TagEpc> _data = [];
  final List<String> _EPC = [];
  List<TagEpc> _successfulTags = [];
  int totalTags = 0;
  static int _value = 0;
  int successfullySaved = 0;
  int previousSavedCount = 0;
  bool isScanning = false;
  bool _isNotifiedEnough = false;
  bool _isShowModal = false; // biến điều khiển show model
  List<TagEpc> newData = [];
  int saveCount = 0;
  int a = 0;
  int TotalScan = 0;
  int scannedTagsCount = 0;
  final _storage = const FlutterSecureStorage();
  String _selectedAgencyName = '';
  String _selectedGoodsName = '';
  bool _dataSaved = false;
  int tagCount = 0;
  bool _isContinuousCall = false;
  bool _shouldRequest = true;
  List<TagEpc> temporarySavedTags = [];
  Queue<TagEpc> tagsToProcess = Queue<TagEpc>();
  int processedTagsCount =
  0; // Biến trung gian để theo dõi số lượng tag đã xử lý
  bool _isDialogShown = false; // biến báo để close popup
  final _storageTemporary = const FlutterSecureStorage();
  bool isSaving = false;
  bool _isEnoughQuantity = false;
  bool _isStop = false;
  TextEditingController _selectedAgencyNameController = TextEditingController();
  TextEditingController _mspTspController = TextEditingController();
  TextEditingController _MnppTnppController = TextEditingController();
  TextEditingController _PXKController = TextEditingController();
  TextEditingController _LXHnppController = TextEditingController();
  TextEditingController _SLXController = TextEditingController();
  TextEditingController _mspController = TextEditingController();
  TextEditingController _GCController = TextEditingController();
  TextEditingController _exportCodesController = TextEditingController();
  late AudioPlayer _audioPlayer;

  bool isSync = false;
  int successfulSends = 0;
  int failSend = 0;
  int alreadyDistributed = 0;
  int notActivated = 0;
  int wrongDistribution = 0;
  int makhongtontai = 0;
  int notPackage = 0;
  int SyncCode = 0;
  int recallCode = 0;
  int completSchedule = 0;
  int notwarehouseDistributionYet = 0;
  int orthercase = 0;
  final secureStorage = const FlutterSecureStorage();
  final distributionStorage = const FlutterSecureStorage();

  Stream<int> get updateStream => _updateStreamController.stream;
  static bool isShowModal = false;
  final _storageAcountCode = const FlutterSecureStorage();
  bool _isShowSelectSyncInfModal = false;
  List<ExportCode> selectedExportCodes = [];
  List<ExportCode> _selectedExportCodes = [];
  List<String> selectedMaPPs = [];
  List<String> selectedMaLXH = [];
  String maPP = '';
  String maPXK = '';
  PXKCode? _selectedExportCode; // Mã PXK đã chọn
  List<PXKCode> exportCodes = []; // Các mã PXK mẫu
  Future<List<PXKCode>>? _futureExportCodes;

  // String IP = 'https://jvf-admin.rynansaas.com/api';
  // String IP = 'http://192.168.19.69:5088/api';
  // String IP = 'http://192.168.19.180:5088/api';

  List<TagEpc> r5_resultTags = [];
  bool scanStatusR5 = false;

  @override
  void initState() {
    super.initState();
    event = widget.event;
    _databaseHelper = CalendarDatabaseHelper();
    _audioPlayer = AudioPlayer();
    _initDatabase();
    initPlatformState();
    loadSuccessfullySaved(event.id);
    loadTemporarySavedTags(event.id);
    _agencyNameController.text = _selectedAgencyName;
    _goodsNameController.text = _selectedGoodsName;
    _initTenLNPP();
    loadTagCount();
    // _futureExportCodes = fetchExportCodesData();
    _futureExportCodes = fetchExportCodesMaKhoData();
    loadTemporarySavedTags(event.id).then((tags) {
      setState(() {
        temporarySavedTags = tags;
      });
    });
    KeyEventChannel(
      onKeyReceived: _toggleScanningForC5,
    ).initialize();

    uhfBLERegister();
  }

  Future<void> checkCurrentDevice() async {
    if (currentDevice == Device.cSeries) {
      await _toggleScanningForC5();
    } else if (currentDevice == Device.rSeries) {
      await _toggleScanningForR5();
    } else if (currentDevice == Device.cameraBarcodes) {
      await _toggleScanningForC5();
    }
  }

  void uhfBLERegister() {
    UHFBlePlugin.setMultiTagCallback((tagList) async {
      // Listen tag data from R5
      if (currentDevice != Device.rSeries) return;
      int targetQuantity = (event.soLuong + (event.soLuong * 0.5)).toInt();

      if (_data.length >= targetQuantity) {
        if (!_isNotifiedEnough) {
          await stopScanning();
          if (mounted) {
            setState(() {
              _isContinuousCall = false;
              _isNotifiedEnough = true;
            });
          }
        }
        return;
      }

      isScanning = true;
      r5_resultTags = DataProcessing.ConvertToTagEpcList(tagList);
      List<TagEpc> uniqueData = r5_resultTags
          .where((newTag) =>
      !_data.any((existingTag) => existingTag.epc == newTag.epc))
          .toList();
      print("danh sach cac the doc lap: ${uniqueData.length}");

      if (uniqueData.isNotEmpty) {
        _playScanSound();
        tagsToProcess.addAll(uniqueData);
        processNextTag();
      }

      setState(() {
        successfullySaved = _data.length;
      });
    });
    UHFBlePlugin.setScanningStatusCallback((scanStatus) async {
      scanStatusR5 = scanStatus;
      await _toggleScanningForR5();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamController.close();
    closeAll();
  }

  closeAll() {
    RfidC72Plugin.close;
  }

  Future<void> initPlatformState() async {
    String platformVersion;
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
    await _initDatabase();
    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
      print('Connection successful');
      _isLoading = false;
    });
  }

  Future<void> _initDatabase() async {
    await _databaseHelper.initDatabase();
  }

  Future<void> _initTenLNPP() async {
    tenLNPP = await _gettenLNPPromSecureStorage();
    setState(() {});
  }

  void processNextTag() async {
    if (tagsToProcess.isNotEmpty) {
      TagEpc tag = tagsToProcess.removeFirst();
      _data.add(tag);
      // await saveData(event.id, _data);  // Đợi lưu dữ liệu thành công
      await saveData(event.id, _data);
      setState(() {
        // CommonFunction().playScanSound();
        successfullySaved = _data.length;
      });
      sendUpdateEvent(
          successfullySaved); // Send update event with new tag count
      processNextTag(); // Tiếp tục xử lý nhãn tiếp theo
    } else {}
  }

  Future<void> _playScanSound() async {
    try {
      await _audioPlayer.setAsset('assets/sound/Bip.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("$e");
    }
  }

  void updateTags(dynamic result) async {
    try {
      int targetQuantity = (event.soLuong + (event.soLuong * 0.5)).toInt();

      if (_data.length >= targetQuantity) {
        if (!_isNotifiedEnough) {
          await stopScanning();
          if (mounted) {
            setState(() {
              _isContinuousCall = false;
              _isNotifiedEnough = true;
            });
          }
        }
        return;
      }

      isScanning = true;
      List<TagEpc> newData = TagEpc.parseTags(result);
      List<TagEpc> uniqueData = newData
          .where((newTag) =>
      !_data.any((existingTag) => existingTag.epc == newTag.epc))
          .toList();
      if (uniqueData.isNotEmpty) {
        _playScanSound();
        tagsToProcess.addAll(uniqueData);
        processNextTag();
      }
      setState(() {
        successfullySaved = _data.length;
      });
    } catch (e) {
      return;
    }
  }

  Future<void> saveTemporarySavedTags(String eventId, List<TagEpc> tags) async {
    String key =
        'temporarySavedTags_$eventId'; // Tạo khóa duy nhất dựa trên ID lịch
    String tagsJson = jsonEncode(tags.map((tag) => tag.toJson()).toList());
    await _storageTemporary.write(key: key, value: tagsJson);
  }

  Future<List<TagEpc>> loadTemporarySavedTags(String eventId) async {
    String key = 'temporarySavedTags_$eventId'; // Sử dụng khóa duy nhất
    String? tagsJson = await _storageTemporary.read(key: key);
    if (tagsJson != null) {
      List<dynamic> tagsList = json.decode(tagsJson);
      return tagsList.map((json) => TagEpc.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<void> saveTagsToDatabase() async {
    bool savedatabase = false;
    isSaving = true;
    List<TagEpc> tempSavedTags = await loadTemporarySavedTags(event.id);
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
                  "Đang lưu dữ liệu...",
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
    for (var tag in _data) {
      if (!tempSavedTags.any((savedTag) => savedTag.epc == tag.epc)) {
        // Nếu tag không tồn tại trong CSDL và chưa có trong temporarySavedTags
        await _databaseHelper.insertRFIDData(tag, event.id);
        temporarySavedTags
            .add(tag); // Thêm tag vào danh sách tạm sau khi lưu thành công
        savedatabase = true;
      }
      saveTemporarySavedTags(event.id, temporarySavedTags);
    }
    Navigator.pop(context); // Đóng dialog
    setState(() {
      _dataSaved = true;
      isSaving = false;
    });
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

  // Future<void> saveData(String key, List<TagEpc> data) async {
  //   // final DateTime scanDate = DateTime.now();
  //   data.forEach((tag) {
  //     tag.saveDate = DateTime.now();
  //     print('tg: ${tag.saveDate}');
  //   });
  //   // Chuyển đổi danh sách tags thành chuỗi JSON sử dụng phương thức toMap()
  //   String dataString = TagEpc.tagEpcToJson(data);
  //   await _storage.write(key: key, value: dataString);
  // }
  Future<void> saveData(String key, List<TagEpc> newData) async {
    // Lấy danh sách tag đã lưu trước đó từ bộ nhớ
    String? existingDataString = await _storage.read(key: key);

    List<TagEpc> existingData = [];
    if (existingDataString != null && existingDataString.isNotEmpty) {
      // Nếu có dữ liệu cũ, parse dữ liệu cũ ra thành List<TagEpc>
      existingData = TagEpc.parseTags(existingDataString);
    }

    // Lấy ngày giờ hiện tại
    DateTime currentDate = DateTime.now();

    // Kiểm tra các tag mới và chỉ cập nhật ngày quét (saveDate) cho các tag chưa có hoặc mới
    newData.forEach((newTag) {
      // Kiểm tra xem tag này đã có trong existingData chưa
      TagEpc? existingTag = existingData.firstWhere(
            (tag) => tag.epc == newTag.epc,
        orElse: () => TagEpc(epc: newTag.epc), // Tạo tag mới nếu không tìm thấy
      );

      // Nếu tag đã có, giữ nguyên saveDate, chỉ cập nhật nếu tag mới
      if (existingTag.saveDate == null) {
        existingTag.saveDate = currentDate; // Cập nhật ngày giờ cho tag mới
      }

      // Thêm tag vào danh sách đã lưu
      if (!existingData.any((tag) => tag.epc == newTag.epc)) {
        existingData.add(existingTag); // Thêm tag mới vào danh sách
      }
    });

    // Chuyển đổi danh sách tag đã cập nhật thành chuỗi JSON
    String updatedDataString = TagEpc.tagEpcToJson(existingData);

    // Lưu lại vào bộ nhớ
    await _storage.write(key: key, value: updatedDataString);
  }

  /// Load tag list from storage
  Future<List<TagEpc>> loadData(String key) async {
    print(
        "Debug: data string key ${key}"); //45851b4f-580d-4ad6-b6bf-eb0cf73b8052
    String? dataString = await _storage.read(key: key);
    print("Debug: data string ${dataString}");
    if (dataString != null) {
      // Sử dụng parseTags để chuyển đổi chuỗi JSON thành danh sách TagEpc
      return TagEpc.parseTags(dataString);
    }
    return [];
  }

  Future<void> stopScanning() async {
    if (mounted) {
      if (_isDialogShown) {
        Navigator.of(context, rootNavigator: true).pop('dialog');
        _isDialogShown = false;
      }
    }
    await DataReadOptions.readTagsAsync(false, currentDevice);
  }

  void _showSnackBar_bk1(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF4EB47D),
      ),
    );
  }
  void _showSnackBar(String message,{bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red : const Color(0xFF4EB47D),
      ),
    );
  }

  void updateIsConnected(dynamic isConnected) {
    _isConnected = isConnected;
  }

  void _showSlingInformation(BuildContext context, String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SlingInformationPage(eventId: eventId)),
    );
  }

  void _showChipInformation(BuildContext context, String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SlingTagsInformationPage(eventId: eventId)),
    );
  }

  void loadTagCount() async {
    if (widget.event.id != null) {
      // Giả sử widget.event là sự kiện được chọn và có thuộc tính id
      List<TagEpc> tags = await loadData(event.id);
      setState(() {
        tagCount = tags.length; // Cập nhật số lượng tags vào biến trạng thái
        print("Debug: cập nhật số lượng quét $tagCount");
      });
    }
  }

  void navigateToUpdate(BuildContext context) async {
    // Navigator.push trả về một giá trị từ trang EditCalendarPage khi quay lại
    final updatedEvent = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCalendarPage(event: event),
      ),
    );
    // Kiểm tra xem dữ liệu đã được cập nhật từ trang EditCalendarPage hay không
    if (updatedEvent != null) {
      setState(() {
        // Cập nhật biến event với dữ liệu mới
        event = updatedEvent;
      });
    }
  }

  void deleteEventFromCalendar() async {
    try {
      final dbHelper = CalendarDatabaseHelper();
      await dbHelper.deleteEvent(event,tableName: "Sling");
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xảy ra lỗi khi xóa lịch!'),
          backgroundColor: Color(0xFF4EB47D),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void onAgencySelected(String selectedAgencyName) {}

  Future<void> _toggleScanningForC5() async {
    try {
      if (isShowModal ||
          currentDevice != Device.cSeries &&
              currentDevice != Device.cameraBarcodes) {
        return;
      }
      if (currentDevice == Device.cameraBarcodes) {
        ConnectionNotificationRSeries.showDeviceWaring(context, false);
        return;
      }

      if (_isNotifiedEnough ||
          tagCount >= (event.soLuong + (event.soLuong * 0.5)).toInt()) {
        await DataReadOptions.readTagsAsync(false, currentDevice);
        _showSnackBar(
          'Đã đạt đủ số lượng',
        );
        return;
      } else {
        if (_isContinuousCall) {
          DataReadOptions.readTagsAsync(false, currentDevice);
          if (mounted && _isDialogShown) {
            Navigator.of(context, rootNavigator: true).pop('dialog');
            _isDialogShown = false;
          }
          setState(() {
            loadTagCount();
          });
        } else {
          DataReadOptions.readTagsAsync(true, currentDevice); //Start
        }
        setState(() {
          _isContinuousCall = !_isContinuousCall;
          _isShowModal = _isContinuousCall;
          _isDialogShown = true;
        });
        if (_isContinuousCall) {
          _data = await loadData(event.id);
          showDialog(
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
            context: context,
          ).then((_) => _isDialogShown =
          false); // Cập nhật trạng thái khi dialog đóng =flase để tránh stop scan sẽ đóng luôn cửa sổ chính
        } else {
          _isShowModal = false;
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _toggleScanningForR5() async {
    try {
      if (isShowModal || currentDevice != Device.rSeries) {
        return;
      }

      // Notify if not use scanner device
      else if (currentDevice == Device.cameraBarcodes) {
        ConnectionNotificationRSeries.showDeviceWaring(context, false);
        return;
      }

      // Check connection
      var isConnected = await UHFBlePlugin.getConnectionStatus();
      if (mounted && !isConnected) {
        ConnectionNotificationRSeries.showConnectionStatus(context, false);
        return;
      }

      // Notify if enough quantity
      if (_isNotifiedEnough ||
          tagCount >= (event.soLuong + (event.soLuong * 0.5)).toInt()) {
        await DataReadOptions.readTagsAsync(false, currentDevice);
        _showSnackBar(
          'Đã đạt đủ số lượng',
        );
        return;
      } else {
        //If you see continuous scanning, stop before starting
        if (_isContinuousCall) {
          await DataReadOptions.readTagsAsync(false, currentDevice);
          if (mounted && _isDialogShown) {
            Navigator.of(context, rootNavigator: true)
                .pop('dialog'); // Đóng dialog
            _isDialogShown = false;
            // Navigator.pop(context);
          }
          setState(() {
            loadTagCount();
          });
        }
        // Not scan continue,...
        else {
          await DataReadOptions.readTagsAsync(true, currentDevice); //Start
        }
        setState(() {
          // show model lên
          _isContinuousCall = !_isContinuousCall;
          _isShowModal = _isContinuousCall;
          scanStatusR5 = false;
          _isDialogShown = true;
        });
        if (_isContinuousCall) {
          // đang scan
          _data = await loadData(event.id);
          showDialog(
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
            context: context,
          ).then((_) {
            _isDialogShown = false;
          }); // Cập nhật trạng thái khi dialog đóng =flase để tránh stop scan sẽ đóng luôn cửa sổ chính
        } else {
          _isShowModal = false;
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _showMPXSelection(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectSchedulePage(
          // fetchPXKData: fetchPXKData, // Sử dụng phương thức fetchPXKData hiện tại của bạn
          fetchPXKData: fetchPXKmaKhoData,
          onSelect: (Dealer selectedDealer) {
            _updateUIWithSelectedDealer(
                selectedDealer); // Cập nhật UI với Dealer được chọn
          },
        ),
      ),
    );
  }

  Future<void> _showExportCodesSelection(BuildContext context,
      StateSetter modalSetState, String selectedPXK, String pTien) async {
    final selectedExportCodes =
    await Navigator.of(context).push<List<ExportCode>>(
      MaterialPageRoute(
        builder: (context) => SelectExportCodesPage(
          selectedPXK: selectedPXK,
          pTien: pTien,
          onConfirm: (List<ExportCode> selectedCodes) {
            Navigator.pop(
                context, selectedCodes); // Trả về danh sách mã PXK đã chọn
          },
        ),
      ),
    );

    // Kiểm tra nếu có mã PXK được chọn
    if (selectedExportCodes != null && selectedExportCodes.isNotEmpty) {
      modalSetState(() {
        _selectedExportCodes =
            selectedExportCodes; // Cập nhật danh sách PXK đã chọn
        _exportCodesController.text = selectedExportCodes
            .map((code) => code.maPXK)
            .join(', '); // Hiển thị các mã PXK trong TextField
        selectedMaPPs = selectedExportCodes.map((code) => code.maPP).toList();
        selectedMaLXH =
            selectedExportCodes.map((code) => code.lenhGiaoHang).toList();

        // Gộp mã PP và lệnh giao hàng thành một chuỗi duy nhất
        String combinedMaPPandLXH = selectedExportCodes
            .map((code) =>
        'Mã PP: ${code.maPP}, Lệnh Giao Hàng: ${code.lenhGiaoHang}')
            .join('\n');

        // Xử lý dữ liệu hoặc in ra thông tin gộp
        // print('Các mã PP đã chọn: $selectedMaPPs');
        // print('Các lệnh giao hàng đã chọn: $selectedMaLXH');
        // print('Thông tin gộp Mã PP và Lệnh Giao Hàng:\n$combinedMaPPandLXH');
      });
    }
  }

  void updateMSPAndTSP(String? msp, String? tsp) {
    String combinedValue = "$tsp\n$msp ";
    _mspTspController.text = combinedValue;
  }

  void updateSoLuongXuat(int sbcx) {
    String combinedValue = "$sbcx ";
    _SLXController.text = combinedValue;
  }

  void updateGhiChu(String? ghiChu) {
    if (ghiChu != null) {
      String combinedValue = "$ghiChu";
      _GCController.text = combinedValue;
    } else {
      String combinedValue = "";
      _GCController.text = combinedValue;
    }
  }

  void updateMNPPAndTNPP(String? mnpp, String? tnpp) {
    if (mnpp == null) {
      _MnppTnppController.text =
      "$tnpp"; // Hoặc bạn có thể đặt giá trị mặc định, ví dụ: "Không có thông tin"
    } else if (tnpp == null) {
      _MnppTnppController.text =
      "$mnpp"; // Hoặc bạn có thể đặt giá trị mặc định, ví dụ: "Không có thông tin"
    } else {
      _MnppTnppController.text = "$tnpp\n$mnpp";
      _mspController.text = "$mnpp";
    }
  }

  void updatePXK(int? PXK) {
    if (PXK == null) {
      _PXKController.text =
      ""; // Hoặc bạn có thể đặt giá trị mặc định, ví dụ: "Không có thông tin"
    } else {
      _PXKController.text = "$PXK";
    }
  }

  void updateLXH(String? LXH) {
    if (LXH == null) {
      _LXHnppController.text = '';
    }
    _LXHnppController.text = LXH.toString();
  }

  void _updateUIWithSelectedDealer(Dealer selectedDealer) {
    setState(() {
      _selectedAgencyNameController.text = selectedDealer.MPX;
      // Cập nhật MNPP và TNPP vào một TextField
      updateMNPPAndTNPP(selectedDealer.MNPP, selectedDealer.TNPP);
      // Cập nhật MSP và TSP vào một TextField khác
      updateMSPAndTSP(selectedDealer.MSP, selectedDealer.TSP);
      updatePXK(selectedDealer.PXK);
      updateLXH(selectedDealer.LXH);
      updateSoLuongXuat(selectedDealer.SBCX);
      updateGhiChu(selectedDealer.ghiChu);
    });
  }

  // Future<List<Dealer>> fetchPXKData() async {
  //   List<Dealer> dealers = [];
  //   int startAt = 0;
  //   const int dataAmount = 1000;
  //   bool hasMore = true;
  //   while (hasMore) {
  //     final response = await http.get(
  //       Uri.parse('$IP/0DFD4827DD294596A8EC539B7C2A5130/'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'start-at': '$startAt',
  //         'Data-Amount': '$dataAmount',
  //       },
  //     );
  //     if (response.statusCode == 200) {
  //       var jsonResponse = json.decode(response.body);
  //       List<dynamic> data = jsonResponse['data'];
  //       if (data.isNotEmpty) {
  //         for (var item in data) {
  //           dealers.add(Dealer(MPX: item["1MPP"], MNPP: item["25MSP"], TNPP: item["10TSP"], MSP: item["6MNPP"], TSP: item["2TNPP"], PXK: item["1PXK"], LXH: item["4LXH"], SBCX: item["4SBCX"], ghiChu: item["22GC"]));
  //         }
  //         // Chỉ tiếp tục gọi API nếu số lượng dữ liệu trả về = 1000
  //         if (data.length == dataAmount) {
  //           startAt += dataAmount; // Cập nhật chỉ số bắt đầu cho lần yêu cầu tiếp theo
  //         } else {
  //           hasMore = false; // Dừng vòng lặp nếu số lượng dữ liệu trả về < 1000
  //         }
  //       } else {
  //         hasMore = false; // Dừng vòng lặp nếu không còn dữ liệu
  //       }
  //     } else {
  //       throw Exception('Failed to load data');
  //     }
  //   }
  //   return dealers;
  // }

  Future<List<Dealer>> fetchPXKmaKhoData() async {
    String? maKho = await _getmaKhofromSecureStorage();
    List<Dealer> dealers = [];
    int startAt = 0;
    const int dataAmount = 1000;
    bool hasMore = true;
    while (hasMore) {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.IP}/api/B3AD8E0E35964CA4BCBFB24A8F5D4AB7/$maKho'),
        headers: {
          'Content-Type': 'application/json',
          'start-at': '$startAt',
          'Data-Amount': '$dataAmount',
        },
      );
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'];
        if (data.isNotEmpty) {
          for (var item in data) {
            dealers.add(Dealer(
                MPX: item["1MPP"],
                MNPP: item["25MSP"],
                TNPP: item["10TSP"],
                MSP: item["6MNPP"],
                TSP: item["2TNPP"],
                PXK: item["1PXK"],
                LXH: item["4LXH"],
                SBCX: item["4SBCX"],
                ghiChu: item["22GC"]));
          }
          // Chỉ tiếp tục gọi API nếu số lượng dữ liệu trả về = 1000
          if (data.length == dataAmount) {
            startAt +=
                dataAmount; // Cập nhật chỉ số bắt đầu cho lần yêu cầu tiếp theo
          } else {
            hasMore = false; // Dừng vòng lặp nếu số lượng dữ liệu trả về < 1000
          }
        } else {
          hasMore = false; // Dừng vòng lặp nếu không còn dữ liệu
        }
      } else {
        throw Exception('Failed to load data');
      }
    }
    return dealers;
  }

  // Future<List<PXKCode>> fetchExportCodesData() async {
  //   List<PXKCode> exportCodes = [];
  //   int startAt = 0;
  //   const int dataAmount = 1000;
  //   bool hasMore = true;
  //
  //   try {
  //     while (hasMore) {
  //       final response = await http.get(
  //         Uri.parse('$IP/0DFD4827DD294596A8EC539B7C2A5130/'),
  //         headers: {
  //           'Content-Type': 'application/json',
  //           'start-at': '$startAt',
  //           'Data-Amount': '$dataAmount',
  //         },
  //       );
  //
  //       if (response.statusCode == 200) {
  //         var jsonResponse = json.decode(response.body);
  //
  //         // Kiểm tra xem "data" có tồn tại và không phải null
  //         if (jsonResponse != null && jsonResponse['data'] != null && jsonResponse['data'] is List) {
  //           List<dynamic> data = jsonResponse['data'];
  //           for (var item in data) {
  //             // Kiểm tra và xử lý giá trị null trong các trường bạn cần
  //             String maPXK = item["MaPhieuXuatKho"] ?? 'Không có mã PXK';
  //             String pTien = item["PhuongTien"] ?? 'Không có phương tiện';
  //             exportCodes.add(PXKCode(maPXK: maPXK, pTien: pTien));
  //           }
  //
  //           // Kiểm tra nếu số lượng dữ liệu trả về ít hơn "dataAmount", thì dừng vòng lặp
  //           if (data.length == dataAmount) {
  //             startAt += dataAmount;
  //           } else {
  //             hasMore = false;
  //           }
  //         } else {
  //           // Nếu không có dữ liệu hoặc dữ liệu không đúng định dạng, dừng vòng lặp
  //           hasMore = false;
  //         }
  //       } else {
  //         throw Exception('Failed to load data');
  //       }
  //     }
  //   } catch (e) {
  //     // Log lỗi nếu cần thiết
  //     print('Error fetching data: $e');
  //   }
  //
  //   return exportCodes; // Trả về danh sách rỗng nếu có lỗi hoặc không có dữ liệu
  // }
  Future<List<PXKCode>> fetchExportCodesMaKhoData() async {
    print('fetchExportCodesMaKhoData');
    String? maKho = await _getmaKhofromSecureStorage();
    List<PXKCode> exportCodes = [];
    int startAt = 0;
    const int dataAmount = 1000;
    bool hasMore = true;

    try {
      while (hasMore) {
        final response = await http.get(
          Uri.parse(
              '${AppConfig.IP}/api/B3AD8E0E35964CA4BCBFB24A8F5D4AB7/$maKho'),
          headers: {
            'Content-Type': 'application/json',
            'start-at': '$startAt',
            'Data-Amount': '$dataAmount',
          },
        );

        if (response.statusCode == 200) {
          var jsonResponse = json.decode(response.body);

          // Kiểm tra xeurl: m "data" có tồn tại và không phải null
          if (jsonResponse != null &&
              jsonResponse['data'] != null &&
              jsonResponse['data'] is List) {
            List<dynamic> data = jsonResponse['data'];
            print('data: $data');
            print(
                '${AppConfig.IP}/api/B3AD8E0E35964CA4BCBFB24A8F5D4AB7/$maKho');
            for (var item in data) {
              // Kiểm tra và xử lý giá trị null trong các trường bạn cần
              String maPXK = item["MaPhieuXuatKho"] ?? 'Không có mã PXK';
              String pTien = item["PhuongTien"] ?? 'Không có phương tiện';
              exportCodes.add(PXKCode(maPXK: maPXK, pTien: pTien));
            }
            // Kiểm tra nếu số lượng dữ liệu trả về ít hơn "dataAmount", thì dừng vòng lặp
            if (data.length == dataAmount) {
              startAt += dataAmount;
            } else {
              hasMore = false;
            }
          } else {
            // Nếu không có dữ liệu hoặc dữ liệu không đúng định dạng, dừng vòng lặp
            hasMore = false;
          }
        } else {
          throw Exception('Failed to load data');
        }
      }
    } catch (e) {
      // Log lỗi nếu cần thiết
      print('Error fetching data: $e');
    }

    return exportCodes; // Trả về danh sách rỗng nếu có lỗi hoặc không có dữ liệu
  }

  // Future<List<ExportCode>> fetchExportCodesData() async {
  //   // Khởi tạo danh sách exportCodes
  //   exportCodes = [
  //     ExportCode(
  //       maPXK: "PXK001",
  //       maPP: "DN202491800719",
  //       congthuc: "CT1",
  //       lenhGiaoHang: "LGH001",
  //       tenDaiLy: "DL1",
  //       maSanPham: "SP001",
  //       soHoaDon: "HD001",
  //       phuongTien: "xe",
  //       soBaoCanXuat: 600,
  //       soTanCanXuat: 2.5,
  //       ghiChu: "Ghi chú ví dụ 1",
  //     ),
  //     ExportCode(
  //       maPXK: "PXK002",
  //       congthuc: "3",
  //       lenhGiaoHang: "LGH003",
  //       maPP: "DN202491600682",
  //       maSanPham: "SP002",
  //       phuongTien: "xe",
  //       tenDaiLy: "DL1",
  //       soHoaDon: "HD002",
  //       soBaoCanXuat: 6,
  //       soTanCanXuat: 1.2,
  //       ghiChu: "Ghi chú ví dụ 2",
  //     ),
  //     ExportCode(
  //       maPXK: "PXK003",
  //       congthuc: "3",
  //       lenhGiaoHang: "LGH003",
  //       phuongTien: "xe",
  //       maPP: "DN202491600683",
  //       maSanPham: "SP002",
  //       tenDaiLy: "DL1",
  //       soHoaDon: "HD002",
  //       soBaoCanXuat: 10,
  //       soTanCanXuat: 1.2,
  //       ghiChu: "Ghi chú ví dụ 2",
  //     ),
  //   ];
  //   // Trả về danh sách mẫu
  //   return Future.value(exportCodes);
  // }

// với quản lý tài khoản thiết bị
  Future<void> PutDistributionWithAccountCode() async {
    // Đọc các tag đã gửi từ FlutterSecureStorage
    String key = getSentTagsKey(event.id); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureStorage.read(key: key);
    List<String> sentTags =
    sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    String baseUrl = '${AppConfig.IP}/api/CD28896A7B0446A0BF17403745E45C84/';
    List<TagEpc> allRFIDData = await loadData(event.id);
    String selectedMPX = _selectedAgencyNameController.text;
    String? maTK = await _getmaTKfromSecureStorage();
    String? maNPP = await _getmaNPPfromSecureStorage();
    String? tenNPP = await _gettenNPPfromSecureStorage();
    bool networkErrorOccurred = false;
    String ngayPost = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    DateTime now = DateTime.now();
    int milli = now.millisecondsSinceEpoch;
    String milliString = milli.toString();

    // Định dạng chuỗi số để có đủ 18 ký tự, thêm các số 0 vào đầu nếu cần
    String formattedTimestamp = milliString.padLeft(18, '0');

    // Duyệt qua từng mã PXK trong danh sách đã chọn
    for (ExportCode exportCode in _selectedExportCodes) {
      String maPP = exportCode.maPP; // Lấy mã PP từ PXK

      // Kiểm tra nếu tag chưa gửi
      String apiUrl = '$baseUrl/$maPP';
      Map<String, dynamic> data = {
        "15MTK": maTK,
        "3MNPPB": maNPP,
        "2TNPPB": tenNPP,
      };

      try {
        final response = await http.put(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(data),
        );

        if (response.statusCode == 200) {
          print('Đồng bộ thành công cho maPP: $maPP');
        } else {
          print('Đồng bộ thất bại cho maPP: $maPP');
        }
      } catch (e) {
        print('Lỗi khi đồng bộ maPP: $maPP');
        networkErrorOccurred = true;
      }
    }
  }

  Future<String?> _gettenLNPPromSecureStorage() async {
    return await _storageAcountCode.read(key: 'maLNPP');
  }

  Future<String?> _getmaTKfromSecureStorage() async {
    return await _storageAcountCode.read(key: 'maTK');
  }

  Future<String?> _getmaNPPfromSecureStorage() async {
    return await _storageAcountCode.read(key: 'maNPP');
  }

  Future<String?> _gettenNPPfromSecureStorage() async {
    return await _storageAcountCode.read(key: 'tenNPP');
  }

  Future<String?> _getmaKhofromSecureStorage() async {
    return await _storageAcountCode.read(key: 'maKho');
  }

  Future<void> saveFileToDownloads(String data, String fileName) async {
    try {
      final downloadDirectory =
      await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOADS);
      final filePath = '$downloadDirectory/$fileName';
      final file = File(filePath);
      await file.writeAsString(data); // Viết dữ liệu vào tệp
    } catch (e) {
      print('Failed to save file: $e');
    }
  }

  Future<List<TagEpc>> getTagEpcList(String key) async {
    return await loadData(event.id);
  }

  Future<String> formatDataForFileWithTags(String key) async {
    StringBuffer buffer = StringBuffer();
    // Dữ liệu từ các thông tin khác
    buffer.writeln("Lệnh Phân phối: ${event.lenhPhanPhoi}");
    buffer.writeln("Tên đại lý: ${event.tenDaiLy}");
    buffer.writeln("Sản phẩm: ${event.tenSanPham}");
    buffer.writeln("Số lượng quét: $tagCount");
    buffer.writeln("Phiếu xuất kho: ${event.phieuXuatKho}");
    buffer.writeln("Ngày tạo lịch: ${event.time}");
    // Lấy danh sách TagEpcLBD từ loadData
    List<TagEpc> tagEpcList = await getTagEpcList(event.id);
    buffer.writeln("Mã EPC:");
    // Duyệt qua danh sách và thêm từng EPC cùng với ngày lưu vào chuỗi
    for (var tag in tagEpcList) {
      String epcString = CommonFunction().hexToString(tag.epc);
      String savedDateString = tag.saveDate != null
          ? DateFormat('dd/MM/yyyy HH:mm:ss').format(tag.saveDate!)
          : 'Unknown'; // Định dạng ngày
      buffer.writeln(
          '$epcString \n - $savedDateString \n'); // Thêm EPC và ngày lưu vào chuỗi
    }
    return buffer.toString();
  }

  Future<void> saveDataWithTags(String key, String baseFileName) async {
    var permissionStatus = await Permission.storage.request();
    if (permissionStatus.isGranted) {
      String formattedData =
      await formatDataForFileWithTags(event.id); // Lấy chuỗi định dạng
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

  Future<bool> shouldSendTag(String msp, String epcString) async {
    final String apiUrl =
        '${AppConfig.IP}/api/8131F8268F8D4B349AAEE8FF82A63CC0/$msp/$epcString';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Kiểm tra nếu 'data' tồn tại và không rỗng
        if (responseData['data'] != null && responseData['data'].isNotEmpty) {
          for (var data in responseData['data']) {
            // print("ạhshdsh");
            if (data['18MT'] == 'ERROR_0000') {
              return false;
            }
          }
        }
      }
    } catch (e) {
      print('Lỗi khi kiểm tra trạng thái thẻ: $e');
    }
    return true; // Gửi nếu không tìm thấy ERROR_0000
  }

  bool isSuccess = false;

  // Future<Map<String, String>?> _showNoteInputDialog(BuildContext context) async {
  //   TextEditingController _noteController = TextEditingController();
  //   TextEditingController _quantityController = TextEditingController();
  //
  //   // Sử dụng await để đảm bảo giá trị được trả về từ dialog
  //   return await showDialog<Map<String, String>>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(
  //           'Nhập thông tin',
  //           style: TextStyle(
  //             color: AppColor.mainText,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         contentPadding: EdgeInsets.only(top: 5, right: 20, left: 20, bottom: 5),
  //         content: SingleChildScrollView(
  //           padding: EdgeInsets.all(8.0),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextField(
  //                 controller: _quantityController,
  //                 keyboardType: TextInputType.number,
  //                 decoration: InputDecoration(
  //                   labelText: 'Nhập số lượng xuất thực tế',
  //                   labelStyle: TextStyle(
  //                     color: Colors.grey,
  //                     fontWeight: FontWeight.normal,
  //                   ),
  //                   filled: true,
  //                   enabledBorder: OutlineInputBorder(
  //                     borderSide: BorderSide(color: Color(0xFF65a281)),
  //                     borderRadius: BorderRadius.circular(12.0),
  //                   ),
  //                   focusedBorder: OutlineInputBorder(
  //                     borderSide: BorderSide(color: AppColor.mainText),
  //                     borderRadius: BorderRadius.circular(12.0),
  //                   ),
  //                   contentPadding:
  //                   EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
  //                 ),
  //               ),
  //               SizedBox(height: 20),
  //               TextField(
  //                 controller: _noteController,
  //                 minLines: 2,
  //                 maxLines: 4,
  //                 decoration: InputDecoration(
  //                   labelText: 'Nhập ghi chú',
  //                   labelStyle: TextStyle(
  //                     color: Colors.grey,
  //                     fontWeight: FontWeight.normal,
  //                   ),
  //                   filled: true,
  //                   enabledBorder: OutlineInputBorder(
  //                     borderSide: BorderSide(color: Color(0xFF65a281)),
  //                     borderRadius: BorderRadius.circular(12.0),
  //                   ),
  //                   focusedBorder: OutlineInputBorder(
  //                     borderSide: BorderSide(color: AppColor.mainText),
  //                     borderRadius: BorderRadius.circular(12.0),
  //                   ),
  //                   contentPadding:
  //                   EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actionsPadding:
  //         EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 7),
  //         actions: <Widget>[
  //           TextButton(
  //             style: ButtonStyle(
  //               backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //               shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                 RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(10.0),
  //                 ),
  //               ),
  //               fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //             ),
  //             child: Text('Hủy', style: TextStyle(color: Colors.white)),
  //             onPressed: () {
  //               Navigator.of(context).pop(); // Trả về null khi hủy
  //             },
  //           ),
  //           TextButton(
  //             style: ButtonStyle(
  //               backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //               shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                 RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(10.0),
  //                 ),
  //               ),
  //               fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //             ),
  //             child: Text('OK', style: TextStyle(color: Colors.white)),
  //             onPressed: () {
  //               // Trả về dữ liệu từ dialog
  //               Navigator.of(context).pop({
  //                 'note': _noteController.text,
  //                 'quantity': _quantityController.text
  //               });
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  ///.................................................//
  // Future<Map<String, String>?> _showNoteInputDialog(BuildContext context, List<String> selectedMPXs) async {
  //   // Tạo các controller để giữ giá trị nhập vào cho mỗi MPX
  //   Map<String, TextEditingController> noteControllers = {};
  //   Map<String, TextEditingController> quantityControllers = {};
  //
  //   // Khởi tạo controller cho mỗi selectedMPX
  //   for (var mpx in selectedMPXs) {
  //     noteControllers[mpx] = TextEditingController();
  //     quantityControllers[mpx] = TextEditingController();
  //   }
  //
  //   // Sử dụng await để đảm bảo giá trị được trả về từ dialog
  //   return await showDialog<Map<String, String>>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(
  //           'Nhập thông tin',
  //           style: TextStyle(
  //             color: AppColor.mainText,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         contentPadding: EdgeInsets.only(top: 5, right: 20, left: 20, bottom: 5),
  //         content: SingleChildScrollView(
  //           padding: EdgeInsets.all(8.0),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: selectedMPXs.map((mpx) {
  //               return Column(
  //                 children: [
  //                   Text('Mã Phân phối: $mpx',
  //                     style: TextStyle(
  //                       color: AppColor.mainText,
  //                     ),
  //                   ),
  //                   TextField(
  //                     controller: quantityControllers[mpx],
  //                     keyboardType: TextInputType.number,
  //                     decoration: InputDecoration(
  //                       labelText: 'Nhập số lượng xuất thực tế',
  //                       labelStyle: TextStyle(
  //                         color: Colors.grey,
  //                         fontWeight: FontWeight.normal,
  //                       ),
  //                       filled: true,
  //                       enabledBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: Color(0xFF65a281)),
  //                         borderRadius: BorderRadius.circular(12.0),
  //                       ),
  //                       focusedBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: AppColor.mainText),
  //                         borderRadius: BorderRadius.circular(12.0),
  //                       ),
  //                       contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
  //                     ),
  //                   ),
  //                   SizedBox(height: 10),
  //                   TextField(
  //                     controller: noteControllers[mpx],
  //                     minLines: 2,
  //                     maxLines: 4,
  //                     decoration: InputDecoration(
  //                       labelText: 'Nhập ghi chú',
  //                       labelStyle: TextStyle(
  //                         color: Colors.grey,
  //                         fontWeight: FontWeight.normal,
  //                       ),
  //                       filled: true,
  //                       enabledBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: Color(0xFF65a281)),
  //                         borderRadius: BorderRadius.circular(12.0),
  //                       ),
  //                       focusedBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: AppColor.mainText),
  //                         borderRadius: BorderRadius.circular(12.0),
  //                       ),
  //                       contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  //                     ),
  //                   ),
  //                   SizedBox(height: 20),
  //                 ],
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //         actionsPadding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 7),
  //         actions: <Widget>[
  //           TextButton(
  //             style: ButtonStyle(
  //               backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //               shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                 RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(10.0),
  //                 ),
  //               ),
  //               fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //             ),
  //             child: Text('Hủy', style: TextStyle(color: Colors.white)),
  //             onPressed: () {
  //               Navigator.of(context).pop(); // Trả về null khi hủy
  //             },
  //           ),
  //           TextButton(
  //             style: ButtonStyle(
  //               backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //               shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                 RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(10.0),
  //                 ),
  //               ),
  //               fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //             ),
  //             child: Text('OK', style: TextStyle(color: Colors.white)),
  //             onPressed: () {
  //               // Trả về dữ liệu từ dialog
  //               Map<String, String> result = {};
  //               for (var mpx in selectedMPXs) {
  //                 result[mpx + '_note'] = noteControllers[mpx]?.text ?? '';
  //                 result[mpx + '_quantity'] = quantityControllers[mpx]?.text ?? '';
  //               }
  //               Navigator.of(context).pop(result);
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
//............................//

  //..
  //  Future<Map<String, String>?> _showNoteInputDialog(BuildContext context, String mpx) async {
  //    // Tạo các controller để giữ giá trị nhập vào cho MPX
  //    TextEditingController noteController = TextEditingController();
  //    TextEditingController quantityController = TextEditingController();
  //
  //    // Tạo một Map để lưu trạng thái checkbox của MPX
  //    bool selectedCheckbox = false;
  //
  //    // Sử dụng await để đảm bảo giá trị được trả về từ dialog
  //    return await showDialog<Map<String, String>>(
  //      context: context,
  //      barrierDismissible: false,
  //      builder: (BuildContext context) {
  //        return StatefulBuilder(
  //          builder: (context, setState) {
  //            return AlertDialog(
  //              title: Text(
  //                'Nhập thông tin cho $mpx',
  //                style: TextStyle(
  //                  color: AppColor.mainText,
  //                  fontWeight: FontWeight.bold,
  //                ),
  //              ),
  //              contentPadding: EdgeInsets.only(top: 5, right: 20, left: 20, bottom: 5),
  //              content: SingleChildScrollView(
  //                padding: EdgeInsets.all(8.0),
  //                child: Column(
  //                  mainAxisSize: MainAxisSize.min,
  //                  children: [
  //                    // Checkbox cho mã MPX
  //                    Row(
  //                      children: [
  //                        Checkbox(
  //                          value: selectedCheckbox,
  //                          onChanged: (bool? value) {
  //                            setState(() {
  //                              selectedCheckbox = value ?? false;
  //                            });
  //                          },
  //                          activeColor: AppColor.mainText, // Màu sắc của checkbox khi được chọn
  //                          checkColor: Colors.white,
  //                          side: BorderSide(color: AppColor.mainText, width: 2),
  //                        ),
  //                        Text(
  //                          '$mpx',
  //                          style: TextStyle(
  //                            color: AppColor.mainText,
  //                          ),
  //                        ),
  //
  //                      ],
  //                    ),
  //                    // Hiển thị TextField nếu checkbox được chọn
  //                    if (selectedCheckbox) ...[
  //                      // TextField nhập số lượng
  //                      TextField(
  //                        controller: quantityController,
  //                        keyboardType: TextInputType.number,
  //                        decoration: InputDecoration(
  //                          labelText: 'Nhập số lượng xuất thực tế',
  //                          labelStyle: TextStyle(
  //                            color: Colors.grey,
  //                            fontWeight: FontWeight.normal,
  //                          ),
  //                          filled: true,
  //                          enabledBorder: OutlineInputBorder(
  //                            borderSide: BorderSide(color: Color(0xFF65a281)),
  //                            borderRadius: BorderRadius.circular(12.0),
  //                          ),
  //                          focusedBorder: OutlineInputBorder(
  //                            borderSide: BorderSide(color: AppColor.mainText),
  //                            borderRadius: BorderRadius.circular(12.0),
  //                          ),
  //                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
  //                        ),
  //                      ),
  //                      SizedBox(height: 10),
  //                      // TextField nhập ghi chú
  //                      TextField(
  //                        controller: noteController,
  //                        minLines: 2,
  //                        maxLines: 4,
  //                        decoration: InputDecoration(
  //                          labelText: 'Nhập ghi chú',
  //                          labelStyle: TextStyle(
  //                            color: Colors.grey,
  //                            fontWeight: FontWeight.normal,
  //                          ),
  //                          filled: true,
  //                          enabledBorder: OutlineInputBorder(
  //                            borderSide: BorderSide(color: Color(0xFF65a281)),
  //                            borderRadius: BorderRadius.circular(12.0),
  //                          ),
  //                          focusedBorder: OutlineInputBorder(
  //                            borderSide: BorderSide(color: AppColor.mainText),
  //                            borderRadius: BorderRadius.circular(12.0),
  //                          ),
  //                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  //                        ),
  //                      ),
  //                      SizedBox(height: 20),
  //                    ],
  //                  ],
  //                ),
  //              ),
  //              actionsPadding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 7),
  //              actions: <Widget>[
  //                TextButton(
  //                  style: ButtonStyle(
  //                    backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                      RoundedRectangleBorder(
  //                        borderRadius: BorderRadius.circular(10.0),
  //                      ),
  //                    ),
  //                    fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //                  ),
  //                  child: Text('Hủy', style: TextStyle(color: Colors.white)),
  //                  onPressed: () {
  //                    Navigator.of(context).pop(); // Trả về null khi bấm "Hủy" để chuyển đến MPX kế tiếp
  //                  },
  //                ),
  //                TextButton(
  //                  style: ButtonStyle(
  //                    backgroundColor: MaterialStateProperty.all<Color>(AppColor.mainText),
  //                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
  //                      RoundedRectangleBorder(
  //                        borderRadius: BorderRadius.circular(10.0),
  //                      ),
  //                    ),
  //                    fixedSize: MaterialStateProperty.all<Size>(Size(100.0, 30.0)),
  //                  ),
  //                  child: Text('OK', style: TextStyle(color: Colors.white)),
  //                  onPressed: () {
  //                    // Trả về dữ liệu từ dialog
  //                    Map<String, String> result = {};
  //                    if (selectedCheckbox) {
  //                      result[mpx + '_note'] = noteController.text;
  //                      result[mpx + '_quantity'] = quantityController.text;
  //                    }
  //                    Navigator.of(context).pop(result); // Trả về thông tin nhập từ dialog
  //                  },
  //                ),
  //              ],
  //            );
  //          },
  //        );
  //      },
  //    );
  //  }
  Future<Map<String, String>?> _showNoteInputDialog(
      BuildContext context, List<String> selectedMPXs) async {
    // Controllers để lưu các giá trị nhập vào cho từng mã MPX
    Map<String, TextEditingController> noteControllers = {};
    Map<String, TextEditingController> quantityControllers = {};

    // Map để theo dõi trạng thái checkbox của từng mã MPX
    Map<String, bool> selectedCheckboxes = {};

    // Khởi tạo các controllers cho mỗi mã MPX
    for (String mpx in selectedMPXs) {
      noteControllers[mpx] = TextEditingController();
      quantityControllers[mpx] = TextEditingController();
      selectedCheckboxes[mpx] = false;
    }

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Nhập thông tin cho các mã MPX',
                style: TextStyle(
                  color: AppColor.mainText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              contentPadding:
              const EdgeInsets.only(top: 5, right: 20, left: 20, bottom: 5),
              content: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hiển thị danh sách checkbox cho mỗi mã MPX
                    for (String mpx in selectedMPXs) ...[
                      Row(
                        children: [
                          Checkbox(
                            value: selectedCheckboxes[mpx]!,
                            onChanged: (bool? value) {
                              setState(() {
                                selectedCheckboxes[mpx] = value ?? false;
                              });
                            },
                            activeColor: AppColor.mainText,
                            checkColor: Colors.white,
                            side: const BorderSide(
                                color: AppColor.mainText, width: 2),
                          ),
                          Text(
                            mpx,
                            style: const TextStyle(color: AppColor.mainText),
                          ),
                        ],
                      ),
                      // Hiển thị TextField khi checkbox của mã MPX được chọn
                      if (selectedCheckboxes[mpx]!) ...[
                        TextField(
                          controller: quantityControllers[mpx],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Nhập số lượng xuất thực tế cho $mpx',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: Color(0xFF65a281)),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: AppColor.mainText),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 6.0),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteControllers[mpx],
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Nhập ghi chú cho $mpx',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: Color(0xFF65a281)),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: AppColor.mainText),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ],
                ),
              ),
              actionsPadding:
              const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 7),
              actions: <Widget>[
                TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                    ),
                    fixedSize: MaterialStateProperty.all<Size>(
                        const Size(100.0, 30.0)),
                  ),
                  child:
                  const Text('Hủy', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Trả về null khi bấm "Hủy"
                  },
                ),
                TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                    MaterialStateProperty.all<Color>(AppColor.mainText),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                    ),
                    fixedSize: MaterialStateProperty.all<Size>(
                        const Size(100.0, 30.0)),
                  ),
                  child:
                  const Text('OK', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    // Trả về dữ liệu từ dialog
                    Map<String, String> result = {};
                    selectedCheckboxes.forEach((mpx, isSelected) {
                      if (isSelected) {
                        result[mpx + '_note'] =
                            noteControllers[mpx]?.text ?? '';
                        result[mpx + '_quantity'] =
                            quantityControllers[mpx]?.text ?? '';
                      }
                    });
                    Navigator.of(context)
                        .pop(result); // Trả về thông tin nhập từ dialog
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> successCodes = [];
  List<String> failCodes = [];

  // Future<void> PutStatusToComplet(List<String> selectedMPXs) async {
  //   // Gọi và nhận giá trị từ dialog
  //   Map<String, String>? result = await _showNoteInputDialog(context, selectedMPXs);
  //
  //   // Kiểm tra nếu result là null (khi người dùng bấm "Hủy")
  //   if (result == null) {
  //     print("Dialog was canceled.");
  //     return;
  //   }
  //
  //   // Lấy giá trị note và quantity từ result
  //   String? ghiChu = result['note'];
  //   String? SBXTT = result['quantity'];
  //
  //   String baseUrl = '${AppConfig.IP}/api/E53E9AEA163A4DD694B3FB8DFB430314';
  //   List<String> successCodes = [];
  //   List<String> failCodes = [];
  //
  //   for (String selectedMPX in selectedMPXs) {
  //     String apiUrl = '$baseUrl/$selectedMPX';
  //     Map<String, dynamic> data = {
  //       "1MPP": selectedMPX,
  //       "7MTT": "TT003",
  //       "22GC": ghiChu,
  //       "1SBXTT": SBXTT,
  //     };
  //     try {
  //       final response = await http.put(
  //         Uri.parse(apiUrl),
  //         headers: {'Content-Type': 'application/json; charset=UTF-8'},
  //         body: jsonEncode(data),
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final responseJson = json.decode(response.body);
  //         bool isSuccess = false;
  //
  //         if (responseJson["results_of_update"] is List) {
  //           for (var result in responseJson["results_of_update"]) {
  //             if (result is Map && result["7MTT"] == "TT003") {
  //               isSuccess = true;
  //               break;
  //             }
  //           }
  //         }
  //
  //         if (isSuccess) {
  //           successCodes.add(selectedMPX);
  //         } else {
  //           failCodes.add(selectedMPX);
  //         }
  //       } else {
  //         failCodes.add(selectedMPX);
  //       }
  //     } catch (e) {
  //       failCodes.add(selectedMPX);
  //     }
  //   }
  //
  //   // Hiển thị kết quả đồng bộ
  //   String message;
  //   if (successCodes.isNotEmpty) {
  //     message = "Lịch đã được xác nhận hoàn thành thành công: \n${successCodes.join(', ')}";
  //     if (failCodes.isNotEmpty) {
  //       message += "\nCập nhật trạng thái không thành công! \n${failCodes.join(', ')}";
  //     }
  //     _showSyncConfirmationDialog(context, message, true);
  //   } else {
  //     message = "Cập nhật trạng thái không thành công! \n${failCodes.join(', ')}";
  //     _showSyncConfirmationDialog(context, message, false);
  //   }
  // }
  // Future<void> PutStatusToComplet(List<String> selectedMPXs) async {
  //   int currentIndex = 0;
  //
  //   while (currentIndex < selectedMPXs.length) {
  //     String selectedMPX = selectedMPXs[currentIndex];
  //
  //     // Gọi và nhận giá trị từ dialog
  //     Map<String, String>? result = await _showNoteInputDialog(context, [selectedMPX]);
  //
  //     // Kiểm tra nếu result là null (khi người dùng bấm "Hủy")
  //     if (result == null) {
  //       print("Dialog was canceled.");
  //       return;
  //     }
  //
  //     // Lấy giá trị note và quantity từ result
  //     String? ghiChu = result['${selectedMPX}_note'];
  //     String? SBXTT = result['${selectedMPX}_quantity'];
  //
  //     String baseUrl = '${AppConfig.IP}/api/E53E9AEA163A4DD694B3FB8DFB430314';
  //
  //     String apiUrl = '$baseUrl/$selectedMPX';
  //     Map<String, dynamic> data = {
  //       "1MPP": selectedMPX,
  //       "7MTT": "TT003",
  //       "22GC": ghiChu,
  //       "1SBXTT": SBXTT,
  //     };
  //
  //     try {
  //       final response = await http.put(
  //         Uri.parse(apiUrl),
  //         headers: {'Content-Type': 'application/json; charset=UTF-8'},
  //         body: jsonEncode(data),
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final responseJson = json.decode(response.body);
  //         bool isSuccess = false;
  //
  //         if (responseJson["results_of_update"] is List) {
  //           for (var result in responseJson["results_of_update"]) {
  //             if (result is Map && result["7MTT"] == "TT003") {
  //               isSuccess = true;
  //               break;
  //             }
  //           }
  //         }
  //
  //         if (isSuccess) {
  //           successCodes.add(selectedMPX);
  //         } else {
  //           failCodes.add(selectedMPX);
  //         }
  //       } else {
  //         failCodes.add(selectedMPX);
  //       }
  //     } catch (e) {
  //       failCodes.add(selectedMPX);
  //     }
  //
  //     // Tiến đến mã phân phối tiếp theo
  //     currentIndex++;
  //   }
  //
  //   // Hiển thị kết quả đồng bộ
  //   String message;
  //   if (successCodes.isNotEmpty) {
  //     message = "Lịch đã được xác nhận hoàn thành thành công: \n${successCodes.join(', ')}";
  //     if (failCodes.isNotEmpty) {
  //       message += "\nCập nhật trạng thái không thành công! \n${failCodes.join(', ')}";
  //     }
  //     _showSyncConfirmationDialog(context, message, true);
  //   } else {
  //     message = "Cập nhật trạng thái không thành công! \n${failCodes.join(', ')}";
  //     _showSyncConfirmationDialog(context, message, false);
  //   }
  // }
  // Future<void> PutStatusToComplet(List<String> selectedMPXs) async {
  //   List<String> successCodes = [];
  //   List<String> failCodes = [];
  //
  //   for (int currentIndex = 0; currentIndex < selectedMPXs.length; currentIndex++) {
  //     String selectedMPX = selectedMPXs[currentIndex];
  //
  //     // Gọi và nhận giá trị từ dialog cho từng mã MPX
  //     Map<String, String>? result = await _showNoteInputDialog(context, selectedMPX);
  //
  //     // Nếu result là null (người dùng bấm "Hủy"), chuyển sang mã MPX tiếp theo mà không xử lý mã hiện tại
  //     if (result == null) {
  //       print("User canceled for $selectedMPX. Moving to next MPX.");
  //       continue;
  //     }
  //
  //     // Lấy giá trị ghi chú và số lượng từ result
  //     String? ghiChu = result['${selectedMPX}_note'];
  //     String? SBXTT = result['${selectedMPX}_quantity'];
  //
  //     String baseUrl = '${AppConfig.IP}/api/E53E9AEA163A4DD694B3FB8DFB430314';
  //     String apiUrl = '$baseUrl/$selectedMPX';
  //     Map<String, dynamic> data = {
  //       "1MPP": selectedMPX,
  //       "7MTT": "TT003",
  //       "22GC": ghiChu,
  //       "1SBXTT": SBXTT,
  //     };
  //
  //     try {
  //       final response = await http.put(
  //         Uri.parse(apiUrl),
  //         headers: {'Content-Type': 'application/json; charset=UTF-8'},
  //         body: jsonEncode(data),
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final responseJson = json.decode(response.body);
  //         bool isSuccess = false;
  //
  //         if (responseJson["results_of_update"] is List) {
  //           for (var result in responseJson["results_of_update"]) {
  //             if (result is Map && result["7MTT"] == "TT003") {
  //               isSuccess = true;
  //               break;
  //             }
  //           }
  //         }
  //
  //         if (isSuccess) {
  //           successCodes.add(selectedMPX);
  //         } else {
  //           failCodes.add(selectedMPX);
  //         }
  //       } else {
  //         failCodes.add(selectedMPX);
  //       }
  //     } catch (e) {
  //       failCodes.add(selectedMPX);
  //     }
  //   }
  //
  //
  //   // Hiển thị kết quả đồng bộ sau khi hoàn thành tất cả
  //   if (successCodes.isNotEmpty) {
  //     String successMessage = 'Các mã MPX đã hoàn thành: ${successCodes.join(', ')}';
  //     _showSyncConfirmationDialog(context, successMessage, true);
  //   }
  //
  //   if (failCodes.isNotEmpty) {
  //     String failMessage = 'Các mã MPX không thành công: ${failCodes.join(', ')}';
  //     _showSyncConfirmationDialog(context, failMessage, false);
  //   }
  // }
  Future<void> PutStatusToComplet(List<String> selectedMPXs) async {
    List<String> successCodes = [];
    List<String> failCodes = [];

    // Gọi _showNoteInputDialog với danh sách mã MPX
    Map<String, String>? result =
    await _showNoteInputDialog(context, selectedMPXs);

    // Kiểm tra nếu người dùng bấm "Hủy"
    if (result == null) {
      print("User canceled. No MPX data entered.");
      return;
    }

    // Chỉ gửi API cho các mã MPX đã được chọn
    for (String mpx in selectedMPXs) {
      // Kiểm tra nếu mã MPX này đã được chọn (checkbox checked)
      if (result['${mpx}_note'] != null && result['${mpx}_quantity'] != null) {
        String? ghiChu = result['${mpx}_note'];
        String? SBXTT = result['${mpx}_quantity'];

        String baseUrl = '${AppConfig.IP}/api/E53E9AEA163A4DD694B3FB8DFB430314';
        String apiUrl = '$baseUrl/$mpx';
        Map<String, dynamic> data = {
          "1MPP": mpx,
          "7MTT": "TT003",
          "22GC": ghiChu,
          "1SBXTT": SBXTT,
        };

        try {
          final response = await http.put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            final responseJson = json.decode(response.body);
            bool isSuccess = false;

            if (responseJson["results_of_update"] is List) {
              for (var result in responseJson["results_of_update"]) {
                if (result is Map && result["7MTT"] == "TT003") {
                  isSuccess = true;
                  break;
                }
              }
            }

            if (isSuccess) {
              successCodes.add(mpx);
            } else {
              failCodes.add(mpx);
            }
          } else {
            failCodes.add(mpx);
          }
        } catch (e) {
          failCodes.add(mpx);
        }
      }
    }

    // Hiển thị kết quả
    if (successCodes.isNotEmpty) {
      String successMessage =
          'Các mã MPX đã hoàn thành: ${successCodes.join(', ')}';
      _showSyncConfirmationDialog(context, successMessage, true);
    }

    if (failCodes.isNotEmpty) {
      String failMessage =
          'Các mã MPX không thành công: ${failCodes.join(', ')}';
      _showSyncConfirmationDialog(context, failMessage, false);
    }
  }

  void _showSyncConfirmationDialog(
      BuildContext context, String message, bool isSuccess) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isSuccess ? "Thông báo" : "Thông báo",
            style: TextStyle(
                color: isSuccess ?  AppColor.mainText : Colors.red,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: isSuccess ? AppColor.mainText :  Colors.red,
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
                Navigator.of(context).pop(); // Đóng dialog
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  // Hiênr thị mã xuất
  void showSelectExportCodesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            // Sử dụng FutureBuilder nhưng không gọi fetch lại, chỉ dùng giá trị đã lưu
            return FutureBuilder<List<PXKCode>>(
              future: _futureExportCodes, // Đảm bảo Future không được gọi lại
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(AppColor.mainText),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.7,
                    child: Center(
                      child: Text(
                        'Có lỗi xảy ra: ${snapshot.error}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.7, // Giới hạn chiều cao
                    child: Center(
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'Không có mã phiếu xuất kho nào.',
                          style: TextStyle(
                              fontSize: 16, color: AppColor.contentText),
                        ),
                      ),
                    ),
                  );
                }
                List<PXKCode> exportCodes = snapshot.data!;
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  width: 350,
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              child: const Text(
                                'Chọn thông tin đồng bộ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColor.mainText,
                                ),
                              ),
                            ),
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: null,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: DropdownSearch<PXKCode>(
                              selectedItem: _selectedExportCode ?? null,
                              // Chọn item nếu có
                              items: exportCodes,
                              // Dữ liệu từ API
                              itemAsString: (PXKCode? u) => u?.maPXK ?? "",
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 6.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                        color: AppColor.mainText),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: AppColor.mainText, width: 2.0),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: AppColor.mainText),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFEBEDEC),
                                  hintText: 'Chọn Phiếu Xuất Kho',
                                  hintStyle: const TextStyle(
                                    color: AppColor.mainText,
                                    fontSize: 18,
                                  ),
                                ),
                                baseStyle: const TextStyle(
                                  color: AppColor.mainText,
                                  fontSize: 18,
                                ),
                              ),
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    labelText: 'Nhập tìm kiếm',
                                    labelStyle: const TextStyle(
                                      color: AppColor.mainText,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: const BorderSide(
                                          color: AppColor.mainText),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: AppColor.mainText, width: 2.0),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: AppColor.mainText),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                ),
                                itemBuilder:
                                    (context, PXKCode item, isSelected) {
                                  return ListTile(
                                    title: Text(
                                      item.maPXK, // Hiển thị mã PXK
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: AppColor.mainText,
                                      ),
                                    ),
                                    selected: isSelected,
                                  );
                                },
                                emptyBuilder: (context, searchEntry) {
                                  return const Center(
                                    child: Text(
                                      "Không tìm thấy Phiếu xuất kho",
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.grey),
                                    ),
                                  );
                                },
                              ),
                              onChanged: (PXKCode? newValue) {
                                setState(() {
                                  _selectedExportCode =
                                      newValue; // Cập nhật mã PXK đã chọn
                                });
                                if (newValue != null) {
                                  // Hiển thị modal xác nhận sau khi chọn
                                  maPXK = newValue.maPXK;
                                  // fetchmaPPData(maPXK); // Gọi hàm fetchmaPPData với maPXK đã chọn
                                  showConfirmationModal(
                                      newValue.maPXK, modalSetState);
                                }
                              },
                            ),
                          ),
                        ),
                        if (_selectedExportCodes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mã lệnh xuất hàng (Mã lệnh phân phối) đã chọn:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColor.mainText,
                                  ),
                                ),
                                SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.3, // Chiều cao vùng cuộn
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: _selectedExportCodes
                                          .map((exportCode) {
                                        // Hiển thị gộp maPP và lenhGiaoHang
                                        return ListTile(
                                          title: Text(
                                            ' ${exportCode.lenhGiaoHang}(${exportCode.maPP})',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: AppColor.mainText,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        const Spacer(),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:  AppColor.mainText,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0, vertical: 6.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              minimumSize: const Size(
                                  200.0, 40.0), // Kích thước tối thiểu
                            ),
                            onPressed: () {
                            //  _showPopup(context);
                              if (_exportCodesController.text.isEmpty) {
                                // Hiển thị SnackBar nếu TextField rỗng
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
                                        "Vui lòng chọn Mã Phiếu xuất kho.",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: AppColor.mainText,
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                            MaterialStateProperty.all<
                                                Color>(
                                                AppColor.mainText),
                                            shape: MaterialStateProperty.all<
                                                RoundedRectangleBorder>(
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(10.0),
                                              ),
                                            ),
                                            fixedSize:
                                            MaterialStateProperty.all<Size>(
                                                const Size(100.0, 30.0)),
                                          ),
                                          child: const Text(
                                            "Đóng",
                                            style:
                                            TextStyle(color: Colors.white),
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
                                print("Bat dau dong bo 2");
                                PutDistributionWithAccountCode();
                                // Gửi dữ liệu
                                if (tenLNPP == "LNPP202400007") {
                                  print(tenLNPP);
                                  sendDataWithPutRequestWithInternalwarehouseCTPP();
                                } else {
                                  sendDataWithPutRequestWithAgencyCTPPKT();
                                }
                              }
                            },
                            child: const Text(
                              'Bắt đầu đồng bộ',
                              style:
                              TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      // Reset dữ liệu khi modal đóng lại
      setState(() {

        _exportCodesController.clear(); // Xóa dữ liệu trong TextField
        _selectedExportCodes.clear(); // Xóa danh sách PXK đã chọn
        _selectedExportCode = null; // Reset danh sách PXK đã chọn
      });
    });
  }

  // Show option export Sling
  Future<int> _showPopup(BuildContext context) async {
    int selectedOption = 1; // Khởi tạo với giá trị mặc định (ví dụ: 1)

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text("Chọn tùy chọn xuất Sling:", style: TextStyle(
                color: AppColor.mainText
              ),),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: Text("Xuất xuất"),
                    value: 1,
                    activeColor: AppColor.mainText,
                    groupValue: selectedOption,
                    onChanged: (value) {


                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    title: Text("Xuất giữ"),
                    value: 2,
                    groupValue: selectedOption,
                    activeColor: AppColor.mainText,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    title: Text("Xuất đủ"),
                    value: 3,
                    groupValue: selectedOption,
                    activeColor: AppColor.mainText,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedOption); // Trả về giá trị mặc định khi "Hủy"
                  },
                  child: Text("Hủy"),
                ),
                 ElevatedButton(

                  onPressed: () {
                    Navigator.of(context).pop(selectedOption); // Trả về giá trị đã chọn khi "OK"
                    showSyncModal();
                  },
                   style : ElevatedButton.styleFrom(
                     backgroundColor: AppColor.mainText,
                     foregroundColor: Colors.white,
                     textStyle: TextStyle(fontSize: 20),
            ),
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );

    return selectedOption; // Trả về giá trị đã chọn hoặc giá trị mặc định
  }

// Modal to confirm export code selection
  Future<void> showConfirmationModal(
      String selectedCode, StateSetter modalSetState) async {
    // Gọi hàm fetchExportCodesData để lấy danh sách PXK
    // List<PXKCode> exportCodes = await fetchExportCodesData();
    List<PXKCode> exportCodes = await fetchExportCodesMaKhoData();
    // Tìm mã PXK tương ứng với selectedCode, trả về đối tượng mặc định nếu không tìm thấy
    PXKCode matchingPXKCode = exportCodes.firstWhere(
            (code) => code.maPXK == selectedCode,
        orElse: () => PXKCode(
            maPXK: 'Mã không hợp lệ',
            pTien: 'Không có dữ liệu') // Trả về đối tượng mặc định
    );

    // Lấy giá trị pTien từ mã PXK đã tìm thấy hoặc mặc định
    String? pTien = matchingPXKCode.pTien;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Xác nhận mã Phiếu xuất kho',
          style: TextStyle(
            color:  AppColor.mainText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bạn đã chọn mã Phiếu xuất kho: $selectedCode. Tiếp tục để chọn Lệnh giao hàng?',
          style: const TextStyle(
            fontSize: 18,
            color: AppColor.mainText,
          ),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            // Căn đều các nút
            children: [
              TextButton(
                onPressed: () {
                  modalSetState(() {
                    _selectedExportCode = null; // Reset mã PXK trong modal
                    _selectedExportCodes.clear(); // Xóa mã đã chọn
                  });
                  setState(() {
                    _selectedExportCode = null; // Reset mã PXK ngoài modal
                  });
                  Navigator.of(context).pop(); // Đóng dialog
                },
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColor.mainText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {




                  await _showExportCodesSelection(context, modalSetState, selectedCode, pTien!);


                },
                style: TextButton.styleFrom(
                  backgroundColor:AppColor.mainText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: const Text(
                  'Tiếp tục',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // hiển thị mã phân phối
  void showSelectDistributionCodesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.99,
          width: 350,
          child: Container(
            child: Container(
              // color: Color(0xFFDDF6FF  ),
              alignment: Alignment.center,
              margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: const Text(
                          'Chọn thông tin đồng bộ', // Tiêu đề
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColor.mainText,
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColor.mainText,
                            size: 30.0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  GestureDetector(
                    onTap: () =>
                    // print('a'),
                    _showMPXSelection(context),
                    // _showExportCodesSelection(context),
                    child: AbsorbPointer(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: TextField(
                          controller: _selectedAgencyNameController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Chọn mã phân phối',
                            labelStyle: const TextStyle(
                              fontSize: 22,
                              color: AppColor.mainText,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 6.0),
                            suffixIcon: const Icon(
                              Icons.navigate_next,
                              color: AppColor.mainText,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide:
                              const BorderSide(color: AppColor.mainText),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: AppColor.mainText),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              const BorderSide(color: AppColor.mainText),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFEBEDEC),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      controller: _mspTspController,
                      readOnly: true,
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: 'Đại lý/kho',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      readOnly: true,
                      maxLines: null,
                      controller: _MnppTnppController,
                      decoration: InputDecoration(
                        labelText: 'Sản phẩm',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      controller: _PXKController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Phiếu xuất kho',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      controller: _LXHnppController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Lệnh giao hàng',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      controller: _SLXController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Số lương cần xuất',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: TextField(
                      controller: _GCController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        labelStyle: const TextStyle(
                          fontSize: 22,
                          color: AppColor.mainText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                          const BorderSide(color: AppColor.mainText),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFEBEDEC),
                      ),
                    ),
                  ),
                  const Spacer(),



                  // Button Sync
                  Center(
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
                      onPressed: () {
                        print("Bat dau dong bo 1");
                    //    _showPopup(context);
                        PutDistributionWithAccountCode();
                        // sendDataWithPutRequest();
                        if (tenLNPP == "LNPP202400007") {
                          //Loại nhà phân phối là kho nhà máy thì phân phối
                          sendDataWithPutRequestWithInternalwarehouseCTPP();
                        } else {
                          //còn lại sử dụng phân phối kho thuê
                          sendDataWithPutRequestWithAgencyCTPPKT();
                        }

                      },
                      child: const Text(
                        'Bắt đầu đồng bộ',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _closeModal(); // Gọi hàm để đóng modal và cập nhật trạng thái
    });
  }



  Future<void> sendDataWithPutRequestWithInternalwarehouseCTPP() async {
    List<String> syncedMaPPs = [];
    // Hiển thị dialog đang tải
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
                  style: TextStyle(color: AppColor.mainText),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Đọc các tag đã gửi từ FlutterSecureStorage
    String key = getSentTagsKey(event.id); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureStorage.read(key: key);
    List<String> sentTags =
    sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    Set<String> sentTagsSet = sentTags.toSet();
    String? maTK = await _getmaTKfromSecureStorage();
    String baseUrl = '${AppConfig.IP}/api/B176498CF7634D8993453B457AB926CB';
    List<TagEpc> allRFIDData = await loadData(event.id);
    // Sắp xếp danh sách EPC theo thời gian từ cũ đến mới
    allRFIDData.sort((a, b) => a.saveDate!.compareTo(b.saveDate!));
    bool networkErrorOccurred = false;
    String ngayPost = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    event.syncDate = ngayPost;
    DateTime syncDate = DateTime.now();
    String syncDateFormat = DateFormat("dd/MM/yyyy").format(syncDate);
    DateTime now = DateTime.now();
    int milli = now.millisecondsSinceEpoch;
    String milliString = milli.toString();
    List<Future> apiRequests = [];

    // Định dạng chuỗi số để có đủ 18 ký tự
    String formattedTimestamp = milliString.padLeft(18, '0');

    // Giả sử _selectedExportCodes chứa danh sách các PXK đã chọn
    List<ExportCode> selectedExportCodes =
        _selectedExportCodes; // Danh sách mã PXK đã chọn
    int currentIndex = 0;

    // Duyệt qua từng mã PXK đã chọn và phân phối EPC
    for (int i = 0; i < selectedExportCodes.length; i++) {
      ExportCode exportCode = selectedExportCodes[i];
      maPP = exportCode.maPP; // Mã PP cho từng PXK
      String maSP = exportCode.maSanPham;
      if (!syncedMaPPs.contains(maPP)) {
        syncedMaPPs.add(maPP); // Chỉ thêm 1 lần cho mỗi maPP
      }
      // Nếu là mã phân phối cuối cùng thì đồng bộ tất cả các EPC còn lại
      if (i == selectedExportCodes.length - 1) {
        int baoXuatThucTe =
            allRFIDData.length - currentIndex; // Lấy tất cả EPC còn lại
        for (int j = 0; j < baoXuatThucTe; j++) {
          if (networkErrorOccurred) break;

          TagEpc tag = allRFIDData[currentIndex];
          currentIndex++;

          String epcString = CommonFunction().hexToString(tag.epc);
          String scanDate = tag.saveDate?.toIso8601String() ?? ' ';

          if (!sentTagsSet.contains(epcString)) {
            bool shouldSend = await shouldSendTagPP(maPP, epcString);
            if (!shouldSend) {
              SyncCode++;
              failSend++;
            } else {
              String apiUrl = '$baseUrl/$maPP/$epcString';
              Map<String, dynamic> data = {
                "1TTPP": "true",
                "15MT": "",
                "1ME": epcString,
                "11ME": "$epcString${formattedTimestamp}",
                "29NT": scanDate,
                "31MSP": maSP,
                "16MTK": maTK,
                "2MPP": maPP,
                "7MTT": "TT001",
                "2SLĐQ": 1,
                "4SGTC": 0,
                "4SGTB": 0,
                "3SQTC": 1,
                "3SQTB": 0,
                "30TT": "TT001"
              };
              print(apiUrl);
              print(data);
              apiRequests.add(Future(() async {
                try {
                  final response = await http.put(
                    Uri.parse(apiUrl),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: jsonEncode(data),
                  );
                  if (response.statusCode == 200) {
                    sentTags.add(epcString);
                    await secureStorage.write(
                      key: key,
                      value: jsonEncode(sentTags),
                    );
                    final responseJson = json.decode(response.body);
                    for (var result in responseJson['results_of_update']) {
                      if (result['15MT'] != null) {
                        String errorCode = result['15MT'];
                        switch (errorCode) {
                          case 'ERROR_0000':
                            successfulSends++;
                            break;
                          case 'ERROR_0001':
                            alreadyDistributed++;
                            failSend++;
                            break;
                          case 'ERROR_0002':
                            notActivated++;
                            failSend++;
                            break;
                          case 'ERROR_0003':
                            wrongDistribution++;
                            failSend++;
                            break;
                          case 'ERROR_0004':
                            failSend++;
                            makhongtontai++;
                            break;
                          case 'ERROR_0005':
                            failSend++;
                            notPackage++;
                            break;
                          case 'ERROR_0008':
                            failSend++;
                            recallCode++;
                            break;
                          case 'ERROR_0009':
                            failSend++;
                            notwarehouseDistributionYet++;
                            break;
                          case 'ERROR_0010':
                            failSend++;
                            completSchedule++;
                            break;
                          default:
                            failSend++;
                            orthercase++;
                        }
                      }
                    }
                  } else {
                    failSend++;
                  }
                } on SocketException {
                  networkErrorOccurred = true;
                } catch (e) {
                  failSend++;
                }
              }));
            }
          }
        }
      } else {
        // Nếu không phải là mã phân phối cuối cùng, đồng bộ theo số bao cần xuất
        int soBaoCanXuat =
            exportCode.soBaoCanXuat; // Số bao cần xuất cho từng PXK
        for (int j = 0;
        j < soBaoCanXuat && currentIndex < allRFIDData.length;
        j++) {
          if (networkErrorOccurred) break;

          TagEpc tag = allRFIDData[currentIndex];
          currentIndex++;

          String epcString = CommonFunction().hexToString(tag.epc);
          String scanDate = tag.saveDate?.toIso8601String() ?? ' ';

          if (!sentTagsSet.contains(epcString)) {
            bool shouldSend = await shouldSendTagPP(maPP, epcString);
            if (!shouldSend) {
              SyncCode++;
              failSend++;
            } else {
              String apiUrl = '$baseUrl/$maPP/$epcString';
              Map<String, dynamic> data = {
                "1TTPP": "true",
                "15MT": "",
                "1ME": epcString,
                "11ME": "$epcString${formattedTimestamp}",
                "29NT": scanDate,
                "31MSP": maSP,
                "16MTK": maTK,
                "2MPP": maPP,
                "7MTT": "TT001",
                "2SLĐQ": 1,
                "4SGTC": 0,
                "4SGTB": 0,
                "3SQTC": 1,
                "3SQTB": 0,
                "30TT": "TT001"
              };
              print(apiUrl);
              print(data);
              apiRequests.add(Future(() async {
                try {
                  final response = await http.put(
                    Uri.parse(apiUrl),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: jsonEncode(data),
                  );
                  if (response.statusCode == 200) {
                    // Nếu đồng bộ thành công, thêm maPP vào danh sách đã đồng bộ
                    sentTags.add(epcString);
                    await secureStorage.write(
                      key: key,
                      value: jsonEncode(sentTags),
                    );
                    final responseJson = json.decode(response.body);
                    for (var result in responseJson['results_of_update']) {
                      if (result['15MT'] != null) {
                        String errorCode = result['15MT'];
                        switch (errorCode) {
                          case 'ERROR_0000':
                            successfulSends++;
                            break;
                          case 'ERROR_0001':
                            alreadyDistributed++;
                            failSend++;
                            break;
                          case 'ERROR_0002':
                            notActivated++;
                            failSend++;
                            break;
                          case 'ERROR_0003':
                            wrongDistribution++;
                            failSend++;
                            break;
                          case 'ERROR_0004':
                            failSend++;
                            makhongtontai++;
                            break;
                          case 'ERROR_0005':
                            failSend++;
                            notPackage++;
                            break;
                          case 'ERROR_0008':
                            failSend++;
                            recallCode++;
                            break;
                          case 'ERROR_0009':
                            failSend++;
                            notwarehouseDistributionYet++;
                            break;
                          case 'ERROR_0010':
                            failSend++;
                            completSchedule++;
                            break;
                          default:
                            failSend++;
                            orthercase++;
                        }
                      }
                    }
                  } else {
                    failSend++;
                  }
                } on SocketException {
                  networkErrorOccurred = true;
                } catch (e) {
                  failSend++;
                }
              }));
            }
          }
        }
      }
    }
    await Future.wait(apiRequests);
    final dbHelper = CalendarDatabaseHelper();
    Navigator.pop(context);
    dadongbo = true;

    if (!networkErrorOccurred) {
      await dbHelper.syncEvent(event,tableName: "Sling"); // Cập nhật cơ sở dữ liệu
      await dbHelper.updateTimeById(event.id, ngayPost,tableName: "Sling");
      resetInputFields(); // Hàm này sẽ đặt lại các trường nhập liệu
      Navigator.pop(context); // Đóng dialog đồng bộ thành công
    }

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
            content: const Text(
              "Vui lòng kiểm tra kết nối mạng.",
              style: TextStyle(
                fontSize: 18,
                color: AppColor.mainText,
              ),
            ),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                  MaterialStateProperty.all<Color>( AppColor.mainText),
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
            content: const Text(
              "Bạn có muốn xác nhận Hoàn thành Lịch Phân phối này?",
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
                  'Hủy',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
                },
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
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                  print(syncedMaPPs);
                  PutStatusToComplet(syncedMaPPs);
                },
              )
            ],
          );
        },
      );
    }
    setState(() {
      saveCountsPackageInfToStorage(
        event.id,
        successfulSends,
        failSend,
        alreadyDistributed,
        notActivated,
        wrongDistribution,
        makhongtontai,
        notPackage,
        recallCode,
        completSchedule,
        orthercase,
        SyncCode,
        notwarehouseDistributionYet,
        syncDateFormat,
      );
    });
  }

  Future<bool> shouldSendTagPP(String msp, String epcString) async {
    final String apiUrl =
        '${AppConfig.IP}/api/3D1E76F5CB80481982319DAD95A83B03/$msp/$epcString';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Kiểm tra nếu 'data' tồn tại và không rỗng
        if (responseData['data'] != null && responseData['data'].isNotEmpty) {
          for (var data in responseData['data']) {
            if (data['15MT'] == 'ERROR_0000') {
              return false;
            }
          }
        }
      }
    } catch (e) {
      print('Lỗi khi kiểm tra trạng thái thẻ: $e');
    }
    return true; // Gửi nếu không tìm thấy ERROR_0000
  }

  Future<void> sendDataWithPutRequestWithAgencyCTPPKT() async {
    List<String> syncedMaPPs = [];
    // Hiển thị dialog đang tải
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
                  style: TextStyle(color: AppColor.mainText),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Đọc các tag đã gửi từ FlutterSecureStorage
    String key = getSentTagsKey(event.id); // Tạo khóa duy nhất dựa trên ID lịch
    String? sentTagsJson = await secureStorage.read(key: key);
    List<String> sentTags =
    sentTagsJson != null ? List<String>.from(jsonDecode(sentTagsJson)) : [];
    Set<String> sentTagsSet = sentTags.toSet();
    String? maTK = await _getmaTKfromSecureStorage();
    String baseUrl = '${AppConfig.IP}/api/4479FF93AA8B4721A3664FA7B3B2A2D3';
    List<TagEpc> allRFIDData = await loadData(event.id);
    // Sắp xếp danh sách EPC theo thời gian từ cũ đến mới
    allRFIDData.sort((a, b) => a.saveDate!.compareTo(b.saveDate!));
    bool networkErrorOccurred = false;
    String ngayPost = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    event.syncDate = ngayPost;
    DateTime syncDate = DateTime.now();
    String syncDateFormat = DateFormat("dd/MM/yyyy").format(syncDate);
    DateTime now = DateTime.now();
    int milli = now.millisecondsSinceEpoch;
    String milliString = milli.toString();
    List<Future> apiRequests = [];

    // Định dạng chuỗi số để có đủ 18 ký tự
    String formattedTimestamp = milliString.padLeft(18, '0');

    // Giả sử _selectedExportCodes chứa danh sách các PXK đã chọn
    List<ExportCode> selectedExportCodes =
        _selectedExportCodes; // Danh sách mã PXK đã chọn
    int currentIndex = 0;

    // Duyệt qua từng mã PXK đã chọn và phân phối EPC
    for (int i = 0; i < selectedExportCodes.length; i++) {
      ExportCode exportCode = selectedExportCodes[i];
      maPP = exportCode.maPP; // Mã PP cho từng PXK
      String maSP = exportCode.maSanPham;
      if (!syncedMaPPs.contains(maPP)) {
        syncedMaPPs.add(maPP); // Chỉ thêm 1 lần cho mỗi maPP
      }
      // Nếu là mã phân phối cuối cùng thì đồng bộ tất cả các EPC còn lại
      if (i == selectedExportCodes.length - 1) {
        int baoXuatThucTe =
            allRFIDData.length - currentIndex; // Lấy tất cả EPC còn lại
        for (int j = 0; j < baoXuatThucTe; j++) {
          if (networkErrorOccurred) break;

          TagEpc tag = allRFIDData[currentIndex];
          currentIndex++;

          String epcString = CommonFunction().hexToString(tag.epc);
          String scanDate = tag.saveDate?.toIso8601String() ?? ' ';

          if (!sentTagsSet.contains(epcString)) {
            bool shouldSend = await shouldSendTagPP(maPP, epcString);
            if (!shouldSend) {
              SyncCode++;
              failSend++;
            } else {
              String apiUrl = '$baseUrl/$maPP/$epcString';
              Map<String, dynamic> data = {
                "1TTPPKT": "true",
                "18MT": "",
                "8ME": epcString,
                "13ME": "$epcString$formattedTimestamp",
                "31NT": scanDate, // Đã cứng giá trị này
                "33MSP": maSP,
                "18MTK": maTK,
                "3MPPKT": maPP,
                "7MTT": "TT001",
                "2SLĐQ": 1,
                "4SGTC": 0,
                "4SGTB": 0,
                "3SQTC": 1,
                "3SQTB": 0,
                "30TT": "TT001",
              };
              print('PPKT: $apiUrl');
              print('PPKT: $data');
              apiRequests.add(Future(() async {
                try {
                  final response = await http.put(
                    Uri.parse(apiUrl),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: jsonEncode(data),
                  );
                  if (response.statusCode == 200) {
                    sentTags.add(epcString);
                    await secureStorage.write(
                      key: key,
                      value: jsonEncode(sentTags),
                    );
                    final responseJson = json.decode(response.body);
                    for (var result in responseJson['results_of_update']) {
                      if (result['18MT'] != null) {
                        String errorCode = result['18MT'];
                        switch (errorCode) {
                          case 'ERROR_0000':
                            successfulSends++;
                            break;
                          case 'ERROR_0001':
                            alreadyDistributed++;
                            failSend++;
                            break;
                          case 'ERROR_0002':
                            notActivated++;
                            failSend++;
                            break;
                          case 'ERROR_0003':
                            wrongDistribution++;
                            failSend++;
                            break;
                          case 'ERROR_0004':
                            failSend++;
                            makhongtontai++;
                            break;
                          case 'ERROR_0005':
                            failSend++;
                            notPackage++;
                            break;
                          case 'ERROR_0008':
                            failSend++;
                            recallCode++;
                            break;
                          case 'ERROR_0009':
                            failSend++;
                            notwarehouseDistributionYet++;
                            break;
                          case 'ERROR_0010':
                            failSend++;
                            completSchedule++;
                            break;
                          default:
                            failSend++;
                            orthercase++;
                        }
                      }
                    }
                  } else {
                    failSend++;
                  }
                } on SocketException {
                  networkErrorOccurred = true;
                } catch (e) {
                  failSend++;
                }
              }));
            }
          }
        }
      } else {
        // Nếu không phải là mã phân phối cuối cùng, đồng bộ theo số bao cần xuất
        int soBaoCanXuat =
            exportCode.soBaoCanXuat; // Số bao cần xuất cho từng PXK
        for (int j = 0;
        j < soBaoCanXuat && currentIndex < allRFIDData.length;
        j++) {
          if (networkErrorOccurred) break;

          TagEpc tag = allRFIDData[currentIndex];
          currentIndex++;

          String epcString = CommonFunction().hexToString(tag.epc);
          String scanDate = tag.saveDate?.toIso8601String() ?? ' ';

          if (!sentTagsSet.contains(epcString)) {
            bool shouldSend = await shouldSendTagPP(maPP, epcString);
            if (!shouldSend) {
              SyncCode++;
              failSend++;
            } else {
              String apiUrl = '$baseUrl/$maPP/$epcString';
              Map<String, dynamic> data = {
                "1TTPPKT": "true",
                "18MT": "",
                "8ME": epcString,
                "13ME": "$epcString$formattedTimestamp",
                "31NT": scanDate, // Đã cứng giá trị này
                "33MSP": maSP,
                "18MTK": maTK,
                "3MPPKT": maPP,
                "7MTT": "TT001",
                "2SLĐQ": 1,
                "4SGTC": 0,
                "4SGTB": 0,
                "3SQTC": 1,
                "3SQTB": 0,
                "30TT": "TT001",
              };
              // print(apiUrl);
              // print(data);
              apiRequests.add(Future(() async {
                try {
                  final response = await http.put(
                    Uri.parse(apiUrl),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: jsonEncode(data),
                  );
                  if (response.statusCode == 200) {
                    // Nếu đồng bộ thành công, thêm maPP vào danh sách đã đồng bộ
                    sentTags.add(epcString);
                    await secureStorage.write(
                      key: key,
                      value: jsonEncode(sentTags),
                    );
                    final responseJson = json.decode(response.body);
                    for (var result in responseJson['results_of_update']) {
                      if (result['18MT'] != null) {
                        String errorCode = result['18MT'];
                        switch (errorCode) {
                          case 'ERROR_0000':
                            successfulSends++;
                            break;
                          case 'ERROR_0001':
                            alreadyDistributed++;
                            failSend++;
                            break;
                          case 'ERROR_0002':
                            notActivated++;
                            failSend++;
                            break;
                          case 'ERROR_0003':
                            wrongDistribution++;
                            failSend++;
                            break;
                          case 'ERROR_0004':
                            failSend++;
                            makhongtontai++;
                            break;
                          case 'ERROR_0005':
                            failSend++;
                            notPackage++;
                            break;
                          case 'ERROR_0008':
                            failSend++;
                            recallCode++;
                            break;
                          case 'ERROR_0009':
                            failSend++;
                            notwarehouseDistributionYet++;
                            break;
                          case 'ERROR_0010':
                            failSend++;
                            completSchedule++;
                            break;
                          default:
                            failSend++;
                            orthercase++;
                        }
                      }
                    }
                  } else {
                    failSend++;
                  }
                } on SocketException {
                  networkErrorOccurred = true;
                } catch (e) {
                  failSend++;
                }
              }));
            }
          }
        }
      }
    }
    await Future.wait(apiRequests);
    final dbHelper = CalendarDatabaseHelper();
    Navigator.pop(context);
    dadongbo = true;

    if (!networkErrorOccurred) {
      await dbHelper.syncEvent(event,tableName: "Sling"); // Cập nhật cơ sở dữ liệu
      await dbHelper.updateTimeById(event.id, ngayPost,tableName: "Sling");
      resetInputFields(); // Hàm này sẽ đặt lại các trường nhập liệu
      Navigator.pop(context); // Đóng dialog đồng bộ thành công
    }

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
            content: const Text(
              "Vui lòng kiểm tra kết nối mạng.",
              style: TextStyle(
                fontSize: 18,
                color: AppColor.mainText,
              ),
            ),
            actions: <Widget>[
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                  MaterialStateProperty.all<Color>( AppColor.mainText),
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
            content: const Text(
              "Bạn có muốn xác nhận Hoàn thành Lịch Phân phối kho thuê này?",
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
                  'Hủy',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
                },
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
                child: const Text("OK", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop();
                  print(syncedMaPPs);
                  PutStatusToComplet(syncedMaPPs);
                },
              )
            ],
          );
        },
      );
    }
    setState(() {
      saveCountsPackageInfToStorage(
        event.id,
        successfulSends,
        failSend,
        alreadyDistributed,
        notActivated,
        wrongDistribution,
        makhongtontai,
        notPackage,
        recallCode,
        completSchedule,
        orthercase,
        SyncCode,
        notwarehouseDistributionYet,
        syncDateFormat,
      );
    });
  }

  void resetInputFields() {
    setState(() {
      _selectedAgencyNameController.text = '';
      _mspTspController.text = '';
      _MnppTnppController.text = '';
      _PXKController.text = '';
      _LXHnppController.text = '';
      _SLXController.text = '';
    });
  }

// Hàm tạo khóa dựa trên ID sự kiện
  String getSentTagsKey(String eventId) {
    return 'sent_tags_$eventId';
  }

  Future<void> saveTagState(TagEpc tag) async {
    final storage = const FlutterSecureStorage();
    String key = 'tag_${tag.epc}';
    String json = jsonEncode(tag.toJson());
    await storage.write(key: key, value: json);
  }

  String getKey(String eventId, String id) {
    return '$eventId-$id';
  }

  Future<void> saveCountsPackageInfToStorage(
      String id,
      int successfulSends,
      int failSend,
      int alreadyDistributed,
      int notActivated,
      int wrongDistribution,
      int makhongtontai,
      int notPackage,
      int recallCode,
      int completSchedule,
      int orthercase,
      int SyncCode,
      int notwarehouseDistributionYet,
      String syncDateFormat) async {
    // Các khóa để lấy dữ liệu
    List<String> keys = [
      "successfulSends",
      "failSend",
      "alreadyDistributed",
      "notActivated",
      "wrongDistribution",
      "makhongtontai",
      "notPackage",
      "recallCode",
      "completSchedule",
      "orthercase",
      "SyncCode",
      "notwarehouseDistributionYet",
      "syncDateFormat",
    ];

    // Đọc giá trị hiện tại từ bộ nhớ và cộng dồn giá trị mới
    for (String key in keys) {
      String storageKey = getKey(key, id);
      String? value = await distributionStorage.read(key: storageKey);
      int currentValue = int.tryParse(value ?? '') ??
          0; // Sử dụng 0 làm giá trị mặc định nếu không phải số

      // Cộng dồn giá trị mới với giá trị đã lưu
      switch (key) {
        case "successfulSends":
          currentValue += successfulSends;
          break;
        case "failSend":
          currentValue += failSend;
          break;
        case "alreadyDistributed":
          currentValue += alreadyDistributed;
          break;
        case "notActivated":
          currentValue += notActivated;
          break;
        case "wrongDistribution":
          currentValue += wrongDistribution;
          break;
        case "makhongtontai":
          currentValue += makhongtontai;
          break;
        case "notPackage":
          currentValue += notPackage;
          break;
        case "recallCode":
          currentValue += recallCode;
          break;
        case "completSchedule":
          currentValue += completSchedule;
          break;
        case "orthercase":
          currentValue += orthercase;
          break;
        case "SyncCode":
          currentValue += SyncCode;
          break;
        case "notwarehouseDistributionYet":
          currentValue += notwarehouseDistributionYet;
          break;
        case "syncDateFormat":
          await distributionStorage.write(
              key: storageKey, value: syncDateFormat);
          continue; // Bỏ qua bước lưu số vì đã lưu chuỗi ngày
      }
      // Lưu giá trị đã cộng dồn trở lại vào bộ nhớ
      await distributionStorage.write(
          key: storageKey, value: currentValue.toString());
    }
  }

  void _closeModal() {
    setState(() {
      isShowModal = false;
    });
  }

  void showSyncModal() async {
    setState(() {
      isShowModal = true;
    });
    if (successfullySaved == 0 && tagCount == 0) {
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
            content: const Text("Vui lòng kiểm tra lại số lượng quét.",
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
      _closeModal();
      showSelectExportCodesModal();

    }
    ;
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return WillPopScope(
        onWillPop: () async {
          if (tagCount > 0 || dadongbo) {
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
            // leading: Padding(
            //   padding: EdgeInsets.only(left: screenWidth * 0.03), // Khoảng cách từ mép trái
            //   child: Container(
            //   ),
            // ),
            leading: IconButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.arrow_back)),
            centerTitle: true,
            title: Text(
              'Lịch xuất Sling',
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
                    SizedBox(width: screenWidth * 0.03),
                    // Khoảng cách giữa hai nút
                    InkWell(
                      onTap: () async {
                        ;
                        saveDataWithTags(event.id, "${event.lenhPhanPhoi}");
                      },
                      child: Image.asset(
                        'assets/image/download.png',
                        width: screenWidth * 0.085, // Chiều rộng hình ảnh
                        height: screenHeight * 0.085, // Chiều cao hình ảnh
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
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
                        width: screenWidth * 0.085, // Chiều rộng hình ảnh
                        height: screenHeight * 0.085, // Chiều cao hình ảnh
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(screenWidth * 0.05,
                      screenHeight * 0.02, 0, screenHeight * 0.012),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: screenWidth * 0.065,
                        color: AppColor.contentText,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Sản phẩm\n',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColor.mainText),
                        ),
                        TextSpan(
                          text: '${event.tenSanPham}',
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: double.infinity,
                    // padding: EdgeInsets.fromLTRB(20, 15, 0, 12),
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
                          color: AppColor.contentText,
                        ),
                        children: [
                          TextSpan(
                            text: 'Phiếu xuất kho \n',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                // fontSize: 24,
                                fontSize: screenWidth * 0.065,
                                color: AppColor.mainText),
                          ),
                          TextSpan(
                            text: '${event.phieuXuatKho}',
                          ),
                        ],
                      ),
                    )),
                Container(
                    width: double.infinity,
                    // padding: EdgeInsets.fromLTRB(20, 15, 0, 12),
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
                          color: AppColor.contentText,
                        ),
                        children: [
                          TextSpan(
                            text: 'Tên đại lý/Kho phân phối\n',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.065,
                                color: AppColor.mainText),
                          ),
                          TextSpan(
                            text: '${event.tenDaiLy}',
                          ),
                        ],
                      ),
                    )),
                Container(
                    width: double.infinity,
                    // padding: EdgeInsets.fromLTRB(20, 15, 0, 12),
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
                          color: AppColor.contentText,
                        ),
                        children: [
                          TextSpan(
                            text: 'Lệnh giao hàng\n',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.065,
                                color: AppColor.mainText),
                          ),
                          TextSpan(
                            text: '${event.lenhPhanPhoi}',
                          ),
                        ],
                      ),
                    )),
                Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(screenWidth * 0.05,
                        screenHeight * 0.012, 0, screenHeight * 0.012),
                    // padding: EdgeInsets.fromLTRB(20, 15, 0, 12),
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
                          color: AppColor.contentText,
                        ),
                        children: [
                          TextSpan(
                            text: 'Số lượng\n',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.065,
                                color: AppColor.mainText),
                          ),
                          TextSpan(
                            text: '${event.soLuong}',
                          ),
                        ],
                      ),
                    )),
                GestureDetector(
                  onTap: () {
                    _showSlingInformation(context, event.id);
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
                                  color: AppColor.contentText),
                              children: [
                                TextSpan(
                                  text: 'Số lượng quét Sling\n',
                                  style: TextStyle(
                                      color: AppColor.mainText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.065),
                                ),
                                TextSpan(
                                  // Kiểm tra trạng thái quét để quyết định hiển thị giá trị nào
                                  text: isScanning
                                      ? '$successfullySaved'
                                      : '$tagCount',
                                  // text: '$tagCount',
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
                GestureDetector(
                  onTap: () {
                    _showChipInformation(context, event.id);
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
                                  color: AppColor.contentText),
                              children: [
                                TextSpan(
                                  text: 'Số lượng quét RFID\n',
                                  style: TextStyle(
                                      color: AppColor.mainText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.065),
                                ),
                                TextSpan(
                                  // Kiểm tra trạng thái quét để quyết định hiển thị giá trị nào
                                  text: isScanning
                                      ? '$successfullySaved'
                                      : '$tagCount',
                                  // text: '$tagCount',
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
                // SizedBox(height:10,),
              ],
            ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      (_isContinuousCall) ? Colors.red : AppColor.mainText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      fixedSize: const Size(150.0, 50.0),
                    ),
                    onPressed: () async {
                      await checkCurrentDevice();
                    },
                    child: (_isContinuousCall)
                        ? Text('Dừng quét',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.06))
                        : Text('Bắt đầu quét',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.06)),
                  ),
                  ElevatedButton(
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
                      _showPopup(context);

                    },
                    child: const Text(
                      'Đồng bộ',
                      style: TextStyle(fontSize: 22, color: Colors.white),
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
