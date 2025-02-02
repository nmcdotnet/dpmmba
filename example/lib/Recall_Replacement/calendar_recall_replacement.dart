import 'package:flutter/material.dart';
import 'dart:async';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../Assign_Packing_Information/database_package_inf.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../Utils/app_color.dart';
import 'recall_replacement_model.dart';
import 'recall_replacement_database.dart';
import 'recall_replacement_offline_list.dart';

class CreateCalendarRecallReplacement extends StatefulWidget {
  final String taiKhoan;
  const CreateCalendarRecallReplacement({
    Key? key,
    required this.taiKhoan,
  }) : super(key: key);

  @override
  State<CreateCalendarRecallReplacement> createState() => _CreateCalendarRecallReplacementState();
}

class _CreateCalendarRecallReplacementState extends State<CreateCalendarRecallReplacement> {

  final dbHelper = CalendarRecallReplacementDatabaseHelper();
  final TextEditingController _ghiChuController = TextEditingController();
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ghiChuController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thêm lịch thu hồi thành công!'),
        backgroundColor: Color(0xFF4EB47D),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void navigateToOfflineRecallManage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OfflineRecallReplacemantList(taiKhoan: widget.taiKhoan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9EBF1),
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.5),
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Tạo lịch thu hồi thay thế',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColor.mainText,
          ),
        ),
        actions: [],
      ),
      body: Container(
        padding: const EdgeInsets.fromLTRB(30, 15, 30, 0),
        constraints: const BoxConstraints.expand(),
        color: const Color(0xFFFAFAFA),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const Text(
                'Nhập thông tin lịch',
                style: TextStyle(
                  fontSize: 26,
                  color: AppColor.mainText,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                width: 320,
                child: TextField(
                  controller: _ghiChuController,
                  decoration: InputDecoration(
                    labelText: 'Nội dung thu hồi',
                    labelStyle: const TextStyle(
                        color: Color(0xFFA2A4A8),
                        fontWeight: FontWeight.normal,
                        fontSize: 22

                    ),
                    filled: true,
                    fillColor: const Color(0xFFEBEDEC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFFEBEDEC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFEBEDEC)),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFEBEDEC)),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 0, 0),
                      child: Text(
                        '(*)',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 15),
          child: ElevatedButton(
            onPressed: () {
              // Xử lý sự kiện khi nút "Thêm" được nhấn
              if (_ghiChuController.text.isNotEmpty ) {
                _addEvent(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đủ thông tin.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColor.mainText,
              padding: const EdgeInsets.symmetric(horizontal: 70.0, vertical: 6.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              fixedSize: const Size(320.0, 40.0),
            ),
            child: const Text(
              'Thêm',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addEvent(BuildContext context) async {
    final DateTime now = DateTime.now(); // Lấy thời gian hiện tại
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    // Tạo một UUID ngẫu nhiên
    String idLTHTT = const Uuid().v4();
    final event = CalendarRecallReplacement(
      idLTHTT: idLTHTT,
      ghiChuLTHTT: _ghiChuController.text,
      taiKhoanTTID: widget.taiKhoan,
      ngayTaoLTHTT: formattedTime,
    );
    await dbHelper.insertEvent(event, widget.taiKhoan);
    _showSuccessMessage(context);
    navigateToOfflineRecallManage(context);
  }

  void someFunction() async {
    CalendarDistributionInfDatabaseHelper dbHelper = CalendarDistributionInfDatabaseHelper();
    await dbHelper.printCalendarDistributionInfData();
  }

}
