import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/model.dart';

class StorageService {
  static const String _fileName = 'localdatabase.json';

  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<void> saveRAMSDataPost(RAMSDataPost ramsDataPost) async {
    try {
      final file = await _getLocalFile();
      final ramsDataPosts = await loadRAMSDataPosts();
      final index = ramsDataPosts.indexWhere(
        (m) =>
            m.projectId == ramsDataPost.projectId &&
            m.chainageStart == ramsDataPost.chainageStart &&
            m.distressId == ramsDataPost.distressId,
      );
      if (index != -1) {
        ramsDataPosts[index] = ramsDataPost;
      } else {
        ramsDataPosts.add(ramsDataPost);
      }
      final jsonList = ramsDataPosts.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> saveAllRAMSDataPosts(
    List<RAMSDataPost> ramsDataPosts,
  ) async {
    try {
      final file = await _getLocalFile();
      final jsonList = ramsDataPosts.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<RAMSDataPost>> loadRAMSDataPosts() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return [];
      final List<dynamic> decoded = json.decode(contents);
      return decoded.map((json) => RAMSDataPost.fromJson(json)).toList();
    } catch (e) {
      print('Error loading RAMSDataPosts: $e');
      return [];
    }
  }

  static Future<void> clearRAMSDataPosts() async {
    final file = await _getLocalFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteRAMSDataPostById(
    String projectId,
    String chainageStart,
    String distressId,
  ) async {
    try {
      final ramsDataPosts = await loadRAMSDataPosts();
      final updated =
          ramsDataPosts
              .where(
                (m) =>
                    m.projectId != projectId ||
                    m.chainageStart != chainageStart ||
                    m.distressId != distressId,
              )
              .toList();
      await saveAllRAMSDataPosts(updated);
    } catch (e) {
      rethrow;
    }
  }

  static Future<RAMSDataPost?> getRAMSDataPostById(
    String projectId,
    String chainageStart,
    String distressId,
  ) async {
    try {
      final list = await loadRAMSDataPosts();
      final match =
          list
              .where(
                (m) =>
                    m.projectId == projectId &&
                    m.chainageStart == chainageStart &&
                    m.distressId == distressId,
              )
              .toList();
      return match.isNotEmpty ? match.first : null;
    } catch (e) {
      print('Error getting RAMSDataPost by ID: $e');
      return null;
    }
  }

  static Future<List<RAMSDataPost>> getRAMSDataPostsByType(String type) async {
    try {
      final ramsDataPosts = await loadRAMSDataPosts();
      return ramsDataPosts
          .where(
            (m) => m.distressType.toLowerCase().contains(type.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print('Error filtering RAMSDataPosts by type: $e');
      return [];
    }
  }

  static Future<int> getRAMSDataPostCount() async {
    try {
      final ramsDataPosts = await loadRAMSDataPosts();
      return ramsDataPosts.length;
    } catch (e) {
      print('Error getting RAMSDataPost count: $e');
      return 0;
    }
  }

  static Future<bool> ramsDataPostExists(
    String projectId,
    String chainageStart,
    String distressId,
  ) async {
    try {
      final ramsDataPost = await getRAMSDataPostById(
        projectId,
        chainageStart,
        distressId,
      );
      return ramsDataPost != null;
    } catch (e) {
      print('Error checking if RAMSDataPost exists: $e');
      return false;
    }
  }

  static Future<List<RAMSDataPost>> getRAMSDataPostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final ramsDataPosts = await loadRAMSDataPosts();
      return ramsDataPosts
          .where(
            (m) =>
                DateTime.tryParse(
                      m.timestamp ?? '',
                    )?.isAfter(startDate.subtract(const Duration(days: 1))) ==
                    true &&
                DateTime.tryParse(
                      m.timestamp ?? '',
                    )?.isBefore(endDate.add(const Duration(days: 1))) ==
                    true,
          )
          .toList();
    } catch (e) {
      print('Error filtering RAMSDataPosts by date range: $e');
      return [];
    }
  }
}
