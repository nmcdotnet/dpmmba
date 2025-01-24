import 'package:flutter/material.dart';
import '../Helpers/calendar_database_helper.dart';
import '../utils/app_color.dart';
import '../utils/app_config.dart';
import '../Configuration/configuration_page.dart';
import 'homepage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../Models/model.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController taiKhoanController = TextEditingController();
  final TextEditingController matKhauController = TextEditingController();
  final dbHelper = CalendarDatabaseHelper();
  final FlutterSecureStorage _storagemoi = const FlutterSecureStorage();
  FlutterSecureStorage storage = const FlutterSecureStorage();
  final FlutterSecureStorage _storageAcountCode = const FlutterSecureStorage();
  bool _passwordVisible = false;
  String? maQuyen = '';
  String selectedDevice = '';

  @override
  void initState() {
    super.initState();
    _addNewAccount();
    _readAccountFromSecureStorage();
    _loadIPFromStorage();
    _loadSelectedDevice();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSelectedDevice() async {
    String? savedDevice = await storage.read(key: 'selected_device');
    setState(() {
      selectedDevice = savedDevice ?? 'C5'; // Nếu không có giá trị, mặc định là C5
    });
  }

  Future<void> _loadIPFromStorage() async {
    FlutterSecureStorage storage = const FlutterSecureStorage();
    String? savedIP = await storage.read(key: 'app_ip');
    if (savedIP != null && savedIP.isNotEmpty) {
      setState(() {
        AppConfig.IP = savedIP;  // Cập nhật AppConfig.IP
      });
    }
  }

  Future<void> _saveAccountToSecureStorage(String taiKhoan, String matKhau) async {
    await _storagemoi.write(key: 'taiKhoan', value: taiKhoan);
    await _storagemoi.write(key: 'matKhau', value: matKhau);
  }

  Future<void> _saveAccountCodeToSecureStorage(String maLNPP, String tenLNPP, String maTK, String maKho, String tenKho, String maNPP, String tenNPP, String maQuyen) async {
    await _storageAcountCode.write(key: 'maLNPP', value: maLNPP);
    await _storageAcountCode.write(key: 'tenLNPP', value: tenLNPP);
    await _storageAcountCode.write(key: 'maTK', value: maTK);
    await _storageAcountCode.write(key: 'maKho', value: maKho);
    await _storageAcountCode.write(key: 'tenKho', value: tenKho);
    await _storageAcountCode.write(key: 'maNPP', value: maNPP);
    await _storageAcountCode.write(key: 'tenNPP', value: tenNPP);
    await _storageAcountCode.write(key: 'maQuyen', value: maQuyen);
  }

  Future<void> _savemaCNSecureStorage(List<String> maCNList) async {
    // Lưu danh sách mã chức năng vào Secure Storage
    await _storageAcountCode.write(key: 'maCNList', value: maCNList.join(','));
  }

  Future<void> _readAccountFromSecureStorage() async {
    String? taiKhoan = await _storagemoi.read(key: 'taiKhoan');
    String? matKhau = await _storagemoi.read(key: 'matKhau');
    if (taiKhoan != null && matKhau != null) {
      taiKhoanController.text = taiKhoan;
      matKhauController.text = matKhau;
    }
  }

  Future<void> _addNewAccount() async {
    TaiKhoan newAccount = TaiKhoan(taiKhoan: "Administrator", matKhau: "Jvf@2024", quyen: "MQ0008", danhsachChucNang:  ["CNKTSP", "CNPP","CNDB", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount2 = TaiKhoan(taiKhoan: "pdanhamay", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount3 = TaiKhoan(taiKhoan: "pprfid", matKhau: "123456@", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount4 = TaiKhoan(taiKhoan: "Comexim", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount5 = TaiKhoan(taiKhoan: "Danacam", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount6 = TaiKhoan(taiKhoan: "dongbao", matKhau: "123456", quyen: "MQ0013", danhsachChucNang: ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN"]);
    // Tài khoản Offline line thêm cho ver1.0.0.5 (NPF.DP24-00008)
    TaiKhoan newAccount7 = TaiKhoan(taiKhoan: "pdaxuathang1", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount8 = TaiKhoan(taiKhoan: "pdaxuathang2", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount9 = TaiKhoan(taiKhoan: "pdaxuathang3", matKhau: "123456", quyen: "MQ0012", danhsachChucNang: ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);
    TaiKhoan newAccount10 = TaiKhoan(taiKhoan: "pdadongbao1", matKhau: "123456", quyen: "MQ0013", danhsachChucNang: ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN"]);
    TaiKhoan newAccount11 = TaiKhoan(taiKhoan: "pdadongbao2", matKhau: "123456", quyen: "MQ0013", danhsachChucNang: ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN"]);

    // TaiKhoan newAccount = TaiKhoan(taiKhoan: "Administrator", matKhau: "Jvf@2024");
    // TaiKhoan newAccount2 = TaiKhoan(taiKhoan: "pdanhamay", matKhau: "123456");
    // TaiKhoan newAccount3 = TaiKhoan(taiKhoan: "pprfid", matKhau: "123456@");
    // TaiKhoan newAccount4 = TaiKhoan(taiKhoan: "Comexim", matKhau: "123456");
    // TaiKhoan newAccount5 = TaiKhoan(taiKhoan: "Danacam", matKhau: "123456");
    // TaiKhoan newAccount6 = TaiKhoan(taiKhoan: "dongbao", matKhau: "123456");

    await dbHelper.insertAccount(newAccount);
    await dbHelper.insertAccount(newAccount2);
    await dbHelper.insertAccount(newAccount3);
    await dbHelper.insertAccount(newAccount4);
    await dbHelper.insertAccount(newAccount5);
    await dbHelper.insertAccount(newAccount6);
    //
    await dbHelper.insertAccount(newAccount7);
    await dbHelper.insertAccount(newAccount8);
    await dbHelper.insertAccount(newAccount9);
    await dbHelper.insertAccount(newAccount10);
    await dbHelper.insertAccount(newAccount11);

    await dbHelper.updateAccountCN(newAccount.taiKhoan, ["CNKTSP", "CNPP","CNDB", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]); // Cập nhật quyền cho "Administrator"
    await dbHelper.updateAccountCN(newAccount2.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]); // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount3.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]); // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount4.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);  // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount5.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);  // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount6.taiKhoan, ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN"]);// Cập nhật quyền cho "pdanhamay"
    //
    await dbHelper.updateAccountCN(newAccount7.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);  // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount8.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);  // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount9.taiKhoan, ["CNKTSP", "CNPP", "CNKK","CNQLTH","CNQLTHH","CNQLTHN", "CNTHTT"]);  // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount10.taiKhoan, ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN"]); // Cập nhật quyền cho "pdanhamay"
    await dbHelper.updateAccountCN(newAccount11.taiKhoan, ["CNKTSP", "CNDB", "CNQLTH","CNQLTHH","CNQLTHN",]); // Cập nhật quyền cho "pdanhamay"
  }

  void _navigateToHomePage(BuildContext context, String taiKhoan) async {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(taiKhoan: taiKhoan, )),
      );
  }


  Future<bool> getAccount(String taiKhoan, String matKhau) async {
    // Construct the URL with the provided username and password
    // var url = 'http://192.168.19.69:5088/api/2A7368DFF9DE4EFB9B353522D0D0B262/$taiKhoan/$matKhau';
    // var url = 'http://192.168.19.180:5088/api/2A7368DFF9DE4EFB9B353522D0D0B262/$taiKhoan/$matKhau';
    var url = '${AppConfig.IP}/api/2A7368DFF9DE4EFB9B353522D0D0B262/$taiKhoan/$matKhau';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);

        List<AccountInf> dealers = [];
        if (jsonResponse is Map<String, dynamic> && jsonResponse['data'] is List) {
          List<dynamic> data = jsonResponse['data'];
          print(data);

          for (var item in data) {
            AccountInf dealer = AccountInf(
                maTK: item["1MTK"],
                maLNPP: item["1MLN"],
                tenLNPP: item["1TLN"],
                maKho: item["19MK"],
                tenKho: item["4TK"],
                maNPP: item["2MNPP"],
                tenNPP: item["2TNPP"],
                maQuyen: item["6MQ"],
            );
            dealers.add(dealer);
            // Save each dealer's data to secure storage
            await _saveAccountCodeToSecureStorage(dealer.maLNPP!, dealer.tenLNPP!, dealer.maTK, dealer.maKho!, dealer.tenKho!, dealer.maNPP!, dealer.tenNPP!, dealer.maQuyen!);
            getMCN(dealer.maQuyen!);
          }
        }
        // Check the "total" field to determine if login is allowed
        if (jsonResponse['total'] == 1) {
          return true;
        }
      } else {
        print('Failed to load data with status code: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching accounts from API1: $e");
    }
    return false;  // Default to not permitting login if conditions are not met
  }

  Future<bool> getMCN(String maQuyen) async {
    var url = '${AppConfig.IP}/api/5AE20C24F87149D7BAF9EC743C329896/$maQuyen';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);

        // Kiểm tra cấu trúc dữ liệu trả về
        if (jsonResponse is Map<String, dynamic> && jsonResponse['data'] is List) {
          List<dynamic> data = jsonResponse['data'];
          print('cn: $data');

          // Tạo một danh sách để chứa các mã chức năng
          List<String> maCNList = [];

          // Duyệt qua dữ liệu trả về và lấy các mã chức năng
          for (var item in data) {
            String maCN = item['MaChucNang'];  // Lấy mã chức năng từ API
            maCNList.add(maCN);  // Thêm mã chức năng vào danh sách
          }

          print('Danh sách mã chức năng1: $maCNList');

          // Lưu vào Secure Storage một lần duy nhất
          await _savemaCNSecureStorage(maCNList);

          // Nếu danh sách chức năng không rỗng, trả về true (tức là lấy được quyền truy cập)
          if (maCNList.isNotEmpty) {
            return true;
          }
        }
      } else {
        print('Failed to load data with status code: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching data from API: $e");
    }

    // Nếu không lấy được dữ liệu hợp lệ, trả về false
    return false;
  }

  // Check login with API response
  Future<bool> checkLogin(String taiKhoan, String matKhau) async {
    bool onlineCheck = false;
    try {
      // First, try to check against the API.
      onlineCheck = await getAccount(taiKhoan, matKhau);
      print(onlineCheck);
      if (onlineCheck) {
        return true; // If online check is successful, return true immediately.
      }
    } catch (e) {
      // Catching any exceptions during the online check (e.g., connection refused)
      print("Error fetching accounts from API: $e");
      print("Switching to offline login.");
    }

    // If no match found online or an error occurs, check the local database (offline).
    List<TaiKhoan> taiKhoanList = await dbHelper.getTaiKhoanTable(); // Get list of TaiKhoan objects

    for (var account in taiKhoanList) {
      if (account.taiKhoan == taiKhoan && account.matKhau == matKhau) {
        // Get other details from the TaiKhoan object
        String maLNPP = account.quyen; // Assuming 'quyen' is used as 'maLNPP'
        String tenLNPP = account.quyen; // Assuming 'quyen' is used as 'tenLNPP'
        String maTK = account.taiKhoan;
        String maKho = ''; // Assuming you might have this data available in your TaiKhoan class or need to fetch it elsewhere
        String tenKho = '';
        String maNPP = '';
        String tenNPP = '';
        String maQuyen = account.quyen; // Assuming 'quyen' is the role, you can adjust as needed
        List<String> danhsachChucNang = account.danhsachChucNang;

        // Save these details to secure storage
        await _saveAccountCodeToSecureStorage(maLNPP, tenLNPP, maTK, maKho, tenKho, maNPP, tenNPP, maQuyen);
        _savemaCNSecureStorage(danhsachChucNang);

        return true; // Local match found
      }
    }

    // If no match is found either online or locally, return false.
    return false;
  }


  void _login(BuildContext context) async {
    String username = taiKhoanController.text.trim();
    String password = matKhauController.text.trim();
    bool loggedIn = await checkLogin(username, password);
    if (loggedIn) {
      await _saveAccountToSecureStorage(username, password);
      _navigateToHomePage(context, username);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập không thành công. Vui lòng kiểm tra lại tài khoản đăng nhập.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2), // Thời gian hiển thị
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight*0.05),
        child: AppBar(
          actions: [
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConfigurationPage()),
                );
                if (result != null) {
                  setState(() {
                  });
                }
              },
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColor.mainText
              ),
            ),
          ],
        ),
      ),
      resizeToAvoidBottomInset: true,  // Bật tính năng cuộn khi bàn phím xuất hiện
      body: Column(
        children: <Widget>[
          Expanded(  // Expanded để phần cuộn chiếm không gian còn lại
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                   const SizedBox(height: 30,),
                    Image.asset(
                      'assets/image/logoJVF_RFID.png',
                      fit: BoxFit.contain, // Đảm bảo ảnh hiển thị toàn bộ
                       width: screenWidth * 0.6,
                       height: screenHeight * 0.15,
                    ),
                   SizedBox(height: screenHeight * 0.01),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start, // Căn giữa theo trục dọc
                      crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa theo trục ngang
                      children: [
                        Text(
                          'PVFCCo RFID',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: AppColor.logoText,

                          ),
                          textAlign: TextAlign.center, // Căn giữa chữ

                        ),
                        // Padding(
                        //   padding: const EdgeInsets.only(left: 0),
                        //   child: Text(
                        //     'TỔNG CÔNG TY',
                        //     style: TextStyle(
                        //       fontSize: screenWidth * 0.045,
                        //       fontWeight: FontWeight.bold,
                        //       color: AppColor.logoText,
                        //     ),
                        //     textAlign: TextAlign.center, // Căn giữa chữ
                        //   ),
                        // ),
                        // Text(
                        //   'PHÂN BÓN VÀ HÓA CHẤT DẦU KHÍ',
                        //   style: TextStyle(
                        //     fontSize: screenWidth * 0.045,
                        //     fontWeight: FontWeight.bold,
                        //     color: AppColor.logoText,
                        //   ),
                        //   textAlign: TextAlign.center, // Căn giữa chữ
                        // ),
                      ],
                    ),
                    SizedBox(
                      height: screenHeight * 0.06, // 6% của chiều cao màn hình
                      width: screenWidth * 0.01, // 2% của chiều rộng màn hình
                    ),
                    Container(
                      width: screenWidth * 0.8,
                      child: TextField(
                        controller: taiKhoanController,
                        style: TextStyle(fontSize: screenWidth * 0.06, color: AppColor.contentText), // Màu chữ chính
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColor.mainText),
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColor.mainText),
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          labelText: 'Tài khoản',
                          labelStyle: TextStyle(color: AppColor.mainText, fontSize: screenWidth * 0.06), // Màu chữ của label
                          prefixIcon: const Icon(
                            Icons.person_2_outlined,
                            color: AppColor.contentText,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.02),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                    Container(
                      width: screenWidth * 0.8,
                      child: TextField(
                        controller: matKhauController,
                        style: TextStyle(fontSize: screenWidth * 0.06, color: AppColor.contentText), // Màu chữ chính
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColor.mainText),
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColor.mainText),
                            borderRadius: BorderRadius.circular(screenWidth * 0.048),
                          ),
                          labelText: 'Mật khẩu',
                          labelStyle: TextStyle(color: AppColor.mainText, fontSize: screenWidth * 0.06), // Màu chữ của label
                          prefixIcon: const Icon(
                            Icons.lock_outlined,
                            color: AppColor.contentText,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible ? Icons.visibility : Icons.visibility_off,
                              color: AppColor.contentText,
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.08),

                    // Login button
                    TextButton(
                      onPressed: () => _login(context),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColor.mainText,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.2, vertical: screenHeight * 0.022),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.048),
                        ),
                        minimumSize: Size(screenWidth * 0.8, 0),
                      ),
                      child: Text(
                        'Đăng nhập',
                        style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.06, color: AppColor.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Đảm bảo phần Text luôn bám vào đáy màn hình
          Align(
            alignment: Alignment.center,
            child:
            Padding(
            padding: EdgeInsets.only(left: screenWidth*0.1, right:  screenWidth*0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text(
                  'v1.0.0.0 | ',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.grey,
                  ),
                ),
                Flexible(
                  child: Text(
                    'Server: ${AppConfig.IP}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey,
                      overflow: TextOverflow.ellipsis, // Cắt bớt nếu văn bản quá dài
                    ),
                  ),
                ),
              ],
            )
          ),
          )
        ],
      ),
    );
  }
}