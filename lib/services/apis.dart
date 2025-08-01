import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartRequest, MultipartFile;
import '../models/model.dart';

class ApiService {
  static const String _baseApi =
      'https://ramsnhit.com/planeteye_staging/index.php/api';
  String? jwtToken;

  // -------------------------
  // Login
  // -------------------------
  Future<Map<String, dynamic>?> loginUser(
    String username,
    String password,
  ) async {
    final url = Uri.parse('$_baseApi/user/login/check_login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': username, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        debugPrint('Login response: $body');
        if (body['status'] == true && body['token'] != null) {
          jwtToken = body['token'];
          return body;
        }
      } else {
        debugPrint('Login failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }
    return null;
  }

  Map<String, String> _headers({bool isJson = true}) {
    final headers = <String, String>{
      if (isJson) 'Content-Type': 'application/json',
      if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
    };
    return headers;
  }

  // -------------------------
  // GET Single & List Endpoints
  // -------------------------
  Future<List<dynamic>?> getProjectList() async {
    final url = Uri.parse('$_baseApi/master/project/get_project_list');
    try {
      final resp = await http.get(url, headers: _headers());
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        debugPrint('Projects: $body');
        return body as List<dynamic>;
      }
      debugPrint('getProjectList failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('Error in getProjectList: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getAllDistressImages() async {
    final url = Uri.parse('$_baseApi/master/project/get_distress_img_list');
    try {
      final resp = await http.get(url, headers: _headers());
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        debugPrint('Distress list: $body');
        return body as List<dynamic>;
      }
      debugPrint('getAllDistressImages failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('Error in getAllDistressImages: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getDistressImagesByProject(int projectId) async {
    final url = Uri.parse(
      '$_baseApi/master/project/get_distress_img/$projectId',
    );
    try {
      final resp = await http.get(url, headers: _headers());
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        debugPrint('Distress images by project: $body');
        return body as List<dynamic>;
      }
      debugPrint('getDistressImagesByProject failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('Error in getDistressImagesByProject: $e');
    }
    return null;
  }

  // -------------------------
  // POST multipart with image
  // -------------------------
  Future<Map<String, dynamic>?> addDistressImage(
    RAMSDataPost data,
    String filePath,
  ) async {
    final uri = Uri.parse('$_baseApi/master/project/add_distress_img');
    final request =
        MultipartRequest('POST', uri)
          ..headers.addAll(_headers(isJson: false))
          ..fields.addAll({
            'project_id': data.projectId.toString(),
            'chainage_start': data.chainageStart.toString(),
            'chainage_end': data.chainageEnd.toString(),
            'distress_type': data.distressType,
            'distress_unit': data.distressUnit,
            'distress_id': data.distressId.toString(),
            'unit': data.unit,
            'area': data.area.toString(),
            'volumn': data.volume.toString(),
            'latitude': data.latitude ?? '',
            'longitude': data.longitude ?? '',
            'dimensions': data.dimensions ?? '',
            'note': data.note ?? '',
          })
          ..files.add(
            await MultipartFile.fromPath('distress_image_name', filePath),
          );

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body);
        debugPrint('addDistressImage response: $body');
        return body as Map<String, dynamic>;
      }
      debugPrint('addDistressImage failed: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('Error in addDistressImage: $e');
    }
    return null;
  }

  // -------------------------
  // DELETE distress image by id
  // -------------------------
  Future<bool> deleteDistressImage(int distressId) async {
    final url = Uri.parse(
      '$_baseApi/master/project/delete_distress_img/$distressId',
    );
    try {
      final resp = await http.post(url, headers: _headers());
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint('Deleted distress id $distressId successfully.');
        return true;
      }
      debugPrint('deleteDistressImage failed: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('Error deleting distress: $e');
    }
    return false;
  }
}
