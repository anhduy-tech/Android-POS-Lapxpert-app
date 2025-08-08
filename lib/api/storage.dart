import 'package:http/http.dart' as http;
import 'axios_api.dart';
import 'dart:convert';

class StorageApi {
  static Future<String> getPresignedUrl(String bucket, String objectName) async {
    try {
      // Sử dụng http.get trực tiếp để kiểm soát response
      final uri = Uri.parse('${Api.baseUrl}/storage/url').replace(queryParameters: {
        'bucket': bucket,
        'objectName': objectName,
      });
      final response = await http.get(uri);
      
      print('Response from /storage/url: ${response.body}'); // Log để debug

      if (response.statusCode == 200) {
        // Response body là chuỗi URL trực tiếp, không cần parse JSON
        final body = response.body.trim();
        if (body.startsWith('http')) {
          return body;
        } else {
          // Nếu response là JSON (trường hợp dự phòng)
          try {
            final jsonResponse = jsonDecode(body);
            return jsonResponse['url']?.toString() ?? body;
          } catch (e) {
            print('Failed to parse JSON, using raw response: $e');
            return body;
          }
        }
      } else {
        throw Exception('Failed to get presigned URL: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting presigned URL: $e');
      throw Exception('Failed to get presigned URL: $e');
    }
  }

  static Future<List<String>> uploadFiles(List<http.MultipartFile> files, String bucket) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('${Api.baseUrl}/storage/upload'));
      request.fields['bucket'] = bucket;
      request.files.addAll(files);
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData.body);
        return (jsonResponse as List<dynamic>).map((e) => e.toString()).toList();
      } else {
        throw Exception('Failed to upload files: ${responseData.body}');
      }
    } catch (e) {
      throw Exception('File upload error: $e');
    }
  }

  static Future<String?> uploadFile(http.MultipartFile file, String bucket) async {
    final result = await uploadFiles([file], bucket);
    return result.isNotEmpty ? result[0] : null;
  }
}