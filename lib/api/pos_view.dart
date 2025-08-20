// file: lib/api/pos_view.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';

// Địa chỉ URL cố định để mô phỏng chính xác "ws://localhost:8080/ws"
const String _wsUrl = 'ws://100.109.192.7:8080/ws';
const String _apiBaseUrl = 'http://100.109.192.7:8080';

StompClient? stompClient;
int reconnectAttempts = 0;
const int maxReconnectAttempts = 5;
const int baseReconnectDelay = 1000; // 1 giây

/**
 * Kết nối đến WebSocket STOMP server với backoff logic
 */
void connectWebSocket({
  required Function(Map<String, dynamic> msg) onPosUpdate,
  required Function() onConnected,
  required Function(String error) onError,
}) {
  debugPrint('STOMP: Đang cố gắng kết nối đến $_wsUrl');
  // Tạo một instance mới của StompClient mỗi lần kết nối
  stompClient = StompClient(
    config: StompConfig(
      url: _wsUrl,
      // Tự động kết nối lại với độ trễ tăng dần
      onConnect: (StompFrame frame) {
        debugPrint('STOMP: Đã kết nối thành công!');
        reconnectAttempts = 0; // Reset số lần thử lại
        onConnected();

        // Đăng ký (subscribe) vào topic sau khi kết nối thành công
        // Backend của bạn có thể sử dụng topic này để gửi tin nhắn
        stompClient?.subscribe(
          destination: '/topic/pos-app/1', // Thay đổi nếu cần
          callback: (StompFrame frame) {
            // **Dòng debug mới**
            debugPrint('STOMP: Đã nhận được tin nhắn từ /topic/pos-app/1');
            if (frame.body != null) {
              try {
                final message = jsonDecode(frame.body!) as Map<String, dynamic>;
                debugPrint('STOMP: Nhận tin nhắn cập nhật POS: $message');
                onPosUpdate(message);
              } catch (e) {
                onError('STOMP: Lỗi giải mã JSON: $e');
              }
            }
          },
        );
      },
      // Xử lý lỗi
      onWebSocketError: (dynamic error) {
        debugPrint('STOMP: Lỗi WebSocket: $error');
        onError('Lỗi kết nối WebSocket: $error');
        _reconnectWithBackoff(onPosUpdate: onPosUpdate, onConnected: onConnected, onError: onError);
      },
      // Xử lý mất kết nối
      onStompError: (StompFrame frame) {
        debugPrint('STOMP: Lỗi STOMP: ${frame.body}');
        onError('Lỗi STOMP từ server: ${frame.body}');
      },
      onDisconnect: (StompFrame frame) {
        debugPrint('STOMP: Đã ngắt kết nối.');
        // onDisconnect không nên tự động thử lại để tránh vòng lặp vô hạn nếu server từ chối kết nối
        onError('Đã ngắt kết nối.');
      },

      reconnectDelay: const Duration(milliseconds: baseReconnectDelay),
      onUnhandledFrame: (StompFrame frame) {
        debugPrint('STOMP: Unhandled frame received: ${frame.command}');
      },
    ),
  );

  // Bắt đầu kết nối
  stompClient?.activate();
}

/**
 * Logic kết nối lại với backoff
 */
void _reconnectWithBackoff({
  required Function(Map<String, dynamic> msg) onPosUpdate,
  required Function() onConnected,
  required Function(String error) onError,
}) {
  if (reconnectAttempts < maxReconnectAttempts) {
    reconnectAttempts++;
    final delay = baseReconnectDelay * (1 << reconnectAttempts);
    debugPrint('STOMP: Đang thử kết nối lại lần $reconnectAttempts sau ${delay}ms...');
    Future.delayed(Duration(milliseconds: delay), () {
      connectWebSocket(onPosUpdate: onPosUpdate, onConnected: onConnected, onError: onError);
    });
  } else {
    debugPrint('STOMP: Đã đạt giới hạn số lần kết nối lại. Hủy.');
    onError('Đã đạt giới hạn số lần kết nối lại.');
  }
}

/**
 * Ngắt kết nối WebSocket và dọn dẹp
 */
void disconnectWebSocket() {
  if (stompClient != null && stompClient!.connected) {
    debugPrint('STOMP: Ngắt kết nối.');
    stompClient!.deactivate();
    stompClient = null;
  }
}

/**
 * Gửi cập nhật POS qua API
 * @param {Object} data - Dữ liệu cập nhật
 * @returns {Future} - Future từ http
 */
Future<void> sendPosUpdate(Map<String, dynamic> data) async {
  try {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/pos/pos-app/send?roomId=1'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(milliseconds: 10000));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to send data: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    throw Exception('Không thể gửi cập nhật POS: $e');
  }
}
