import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../Utils/app_config.dart';

class WebviewProducts extends StatefulWidget {
  final String product_id;
  const WebviewProducts({super.key, required this.product_id});



  @override
  State<WebviewProducts> createState() => _WebviewProductsState();
}

class _WebviewProductsState extends State<WebviewProducts> {
  late final WebViewController _controller;
  bool isLoading = true;
  final TextEditingController _urlController =  TextEditingController(text: "http://flutter.dev");


  @override
  void initState() {
    super.initState();
 //   String url_product = '${AppConfig.IP}/check/${widget.product_id}'.trim();
    //String output = widget.product_id.replaceAll("RCM", "RDM"); // Thay thế RCM thành RPM
    String url_product = 'https://dpm-saas.mylanhosting.com/check/${widget.product_id}'.trim();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url_product));
  }

  void _loadUrl() {
    String url = '${AppConfig.IP}/check/${widget.product_id}'.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    setState(() {
      isLoading = true;
    });
    _controller.loadRequest(Uri.parse(url));
  }


  @override
  Widget build(BuildContext context) {
   // print("Load webview");
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.product_id),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: () {
      //         _controller.reload();
      //       },
      //     ),
      //   ],
      // ),
      body: Column(
        children: [
          const SizedBox(height: 10), // Adds 20 pixels of vertical space
          // // Input URL and Button
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: TextField(
          //           controller: _urlController,
          //           decoration: const InputDecoration(
          //             hintText: 'Nhập địa chỉ web...',
          //             border: OutlineInputBorder(),
          //           ),
          //           keyboardType: TextInputType.url,
          //           textInputAction: TextInputAction.go,
          //           onSubmitted: (value) => _loadUrl(),
          //         ),
          //       ),
          //       const SizedBox(width: 8),
          //       ElevatedButton(
          //         onPressed: _loadUrl,
          //         child: const Text('Duyệt web'),
          //       ),
          //     ],
          //   ),
          // ),
          // WebView and Loading Spinner
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          Text('Mã sản phẩm:  ${widget.product_id}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),),
        ],
      ),
    );
  }
}

