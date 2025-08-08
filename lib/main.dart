import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'api/pos_view.dart';
import 'api/storage.dart';

// Lớp provider để quản lý trạng thái
class OrderProvider extends ChangeNotifier {
  Map<String, dynamic> _latestUpdate = {
    'orderId': null, 
    'data': {}, 
    'timestamp': DateTime.now().millisecondsSinceEpoch
  };
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, String> _imageUrlCache = {};

  Map<String, dynamic> get latestUpdate => _latestUpdate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setUpdate(Map<String, dynamic> msg) async {
    final message = msg.cast<String, dynamic>();

    if (message['action'] == 'UPDATE_CART') {
      _latestUpdate = {
        'orderId': message['orderId'] ?? 'N/A',
        'data': (message['data'] as Map).cast<String, dynamic>(),
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      };
      await _preloadProductImages();
      _isLoading = false;
      notifyListeners();
    } else if (message['action'] == 'PRICE_UPDATE') {
      final productList = _latestUpdate['data']['sanPhamList'] as List?;
      if (productList != null) {
        final product = productList.firstWhere(
          (item) => (item as Map)['sanPhamChiTiet']?['id'] == message['productId'],
          orElse: () => null,
        );
        if (product != null) {
          (product as Map)['giaBan'] = message['newPrice'];
          notifyListeners();
        }
      }
    } else if (message['action'] == 'STOCK_UPDATE') {
      final productList = _latestUpdate['data']['sanPhamList'] as List?;
      if (productList != null) {
        final product = productList.firstWhere(
          (item) => (item as Map)['sanPhamChiTiet']?['id'] == message['productId'],
          orElse: () => null,
        );
        if (product != null) {
          (product as Map)['tonKho'] = message['stock'];
          notifyListeners();
        }
      }
    }
  }

  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  String formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (now.difference(date).inDays == 0) {
      return DateFormat('HH:mm:ss').format(date);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<void> _preloadProductImages() async {
    final productList = _latestUpdate['data']?['sanPhamList'] as List?;
    if (productList != null) {
      for (final item in productList) {
        final productDetail = (item as Map)['sanPhamChiTiet'] as Map?;
        if (productDetail != null) {
          // Log toàn bộ sanPham để debug
          print('sanPham data: ${productDetail['sanPham']}');
          // Kiểm tra sanPhamChiTiet.hinhAnh và sanPham.hinhAnh
          final dynamic hinhAnhValue = productDetail['sanPham'] != null &&
                  productDetail['sanPham']['hinhAnh'] != null &&
                  productDetail['sanPham']['hinhAnh'] is List &&
                  (productDetail['sanPham']['hinhAnh'] as List).isNotEmpty
              ? productDetail['sanPham']['hinhAnh']
              : (productDetail['hinhAnh'] is List && (productDetail['hinhAnh'] as List).isNotEmpty
                  ? productDetail['hinhAnh']
                  : null);
          String? imageName;

          print('hinhAnhValue for product ${productDetail['sanPham']?['tenSanPham'] ?? 'Unknown'}: $hinhAnhValue');

          if (hinhAnhValue is String && hinhAnhValue.isNotEmpty) {
            imageName = hinhAnhValue;
          } else if (hinhAnhValue is List && hinhAnhValue.isNotEmpty && hinhAnhValue.first is String && hinhAnhValue.first.isNotEmpty) {
            imageName = hinhAnhValue.first;
          }

          if (imageName != null && imageName.isNotEmpty) {
            if (!_imageUrlCache.containsKey(imageName)) {
              try {
                print('Attempting to load image: $imageName from bucket: products');
                final url = await StorageApi.getPresignedUrl('products', imageName);
                if (url != null && url.isNotEmpty) {
                  _imageUrlCache[imageName] = url;
                  print('Successfully loaded image URL: $url');
                } else {
                  print('Received null or empty URL for image: $imageName');
                  _imageUrlCache[imageName] = 'https://placehold.co/100x100/E5E7EB/4B5563?text=Ảnh Lỗi';
                }
              } catch (e) {
                print('Lỗi lấy URL ảnh cho $imageName: $e');
                _imageUrlCache[imageName] = 'https://placehold.co/100x100/E5E7EB/4B5563?text=Ảnh Lỗi';
              }
            }
          } else {
            print('No valid image name found for product: ${productDetail['sanPham']?['tenSanPham'] ?? 'Unknown'}');
            _imageUrlCache['default_${productDetail['id']}'] = 'https://placehold.co/100x100/E5E7EB/4B5563?text=Ảnh Lỗi';
          }
        }
      }
    }
  }

  String? getImageUrl(String? imageName) {
    if (imageName == null || imageName.isEmpty) {
      print('Image name is null or empty, returning default placeholder');
      return 'https://placehold.co/100x100/E5E7EB/4B5563?text=Ảnh Lỗi';
    }
    final url = _imageUrlCache[imageName] ?? 'https://placehold.co/100x100/E5E7EB/4B5563?text=Ảnh Lỗi';
    print('Returning image URL for $imageName: $url');
    return url;
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Inter',
      ),
      home: const PosViewPage(),
    );
  }
}

class PosViewPage extends StatefulWidget {
  const PosViewPage({Key? key}) : super(key: key);

  @override
  _PosViewPageState createState() => _PosViewPageState();
}

class _PosViewPageState extends State<PosViewPage> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OrderProvider>(context, listen: false);
    connectWebSocket(
      onPosUpdate: (msg) {
        provider.setUpdate(msg);
      },
      onConnected: () {
        print('Kết nối WebSocket đã thành công!');
        provider.setLoading(false);
      },
      onError: (error) {
        print('Lỗi kết nối WebSocket: $error');
        provider.setErrorMessage(error);
        provider.setLoading(true);
      },
    );
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'POS View',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          final latestUpdate = provider.latestUpdate;
          final order = (latestUpdate['data'] as Map).cast<String, dynamic>();
          final products = order['sanPhamList'] as List<dynamic>?;
          final timestamp = latestUpdate['timestamp'];
          final customer = order['khachHang'];
          final shippingAddress = order['diaChiGiaoHang'] as Map<String, dynamic>?;

          final totalAmount = order['tongThanhToan'] ?? 0;
          final subtotal = order['tongTienHang'] ?? 0;
          final voucherDiscount = order['giaTriGiamGiaVoucher'] ?? 0;
          final shippingFee = order['phiVanChuyen'] ?? 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thẻ mã hóa đơn
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Mã hóa đơn: ${order['maHoaDon'] ?? 'N/A'}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (provider.isLoading)
                            const CircularProgressIndicator()
                          else if (provider.errorMessage != null)
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Align(
                              alignment: Alignment.topRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timestamp != null
                                        ? provider.formatTimestamp(timestamp)
                                        : 'N/A',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Thẻ thông tin khách hàng
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Khách hàng: ${customer?['hoTen'] ?? 'Khách hàng vãng lai'}',
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Thẻ địa chỉ giao hàng
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Địa chỉ giao hàng',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shippingAddress != null
                                ? '${shippingAddress['duong']}, ${shippingAddress['phuongXa']}, ${shippingAddress['quanHuyen']}, ${shippingAddress['tinhThanh']}'
                                : 'Lấy hàng tại quầy',
                            style: shippingAddress != null
                                ? Theme.of(context).textTheme.bodyMedium
                                : Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Thẻ tổng quan thanh toán
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng tiền hàng: ${currencyFormatter.format(subtotal)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (voucherDiscount > 0)
                            Text(
                              'Giảm giá voucher: -${currencyFormatter.format(voucherDiscount)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                            ),
                          Text(
                            'Phí vận chuyển: ${currencyFormatter.format(shippingFee)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Divider(),
                          Text(
                            'Tổng thanh toán: ${currencyFormatter.format(totalAmount)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Danh sách sản phẩm
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: (products == null || products.isEmpty)
                          ? const Center(child: Text('Không có sản phẩm nào'))
                          : SizedBox(
                              height: 300, // Giới hạn chiều cao để tránh chiếm quá nhiều không gian
                              child: ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                itemBuilder: (context, index) {
                                  final productData = (products[index] as Map).cast<String, dynamic>();
                                  final productDetail = (productData['sanPhamChiTiet'] as Map).cast<String, dynamic>();
                                  // Kiểm tra sanPham.hinhAnh trước
                                  final dynamic hinhAnhValue = productDetail['sanPham'] != null &&
                                          productDetail['sanPham']['hinhAnh'] != null &&
                                          productDetail['sanPham']['hinhAnh'] is List &&
                                          (productDetail['sanPham']['hinhAnh'] as List).isNotEmpty
                                      ? productDetail['sanPham']['hinhAnh']
                                      : (productDetail['hinhAnh'] is List && (productDetail['hinhAnh'] as List).isNotEmpty
                                          ? productDetail['hinhAnh']
                                          : null);
                                  String? imageName;
                                  if (hinhAnhValue is String && hinhAnhValue.isNotEmpty) {
                                    imageName = hinhAnhValue;
                                  } else if (hinhAnhValue is List && hinhAnhValue.isNotEmpty && hinhAnhValue.first is String && hinhAnhValue.first.isNotEmpty) {
                                    imageName = hinhAnhValue.first;
                                  }
                                  final imageUrl = provider.getImageUrl(imageName);
                                  print('Image URL for product ${productDetail['sanPham']?['tenSanPham'] ?? 'Unknown'}: $imageUrl');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: imageUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  memCacheHeight: 160,
                                                  memCacheWidth: 160,
                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                  placeholder: (context, url) => const CircularProgressIndicator(),
                                                  errorWidget: (context, url, error) {
                                                    print('Error loading image $url: $error');
                                                    return const Icon(Icons.broken_image, color: Colors.grey);
                                                  },
                                                )
                                              : Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productDetail['sanPham']?['tenSanPham'] ?? 'Tên sản phẩm',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text('Số lượng: ${productData['soLuong']}', style: Theme.of(context).textTheme.bodySmall),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Giá: ${currencyFormatter.format(productData['donGia'])}',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.deepOrange),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}