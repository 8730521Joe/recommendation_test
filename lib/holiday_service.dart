import 'dart:convert';
import 'package:http/http.dart' as http;

class HolidayService {
  static const String _baseUrl = 'https://timor.tech/api/holiday';
  
  /// 获取指定日期的节假日信息
  /// 返回值：'工作日', '周末', '假日'
  static Future<String> getDateType(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final url = '$_baseUrl/info/$dateStr';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter App'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API返回数据: $data'); // 调试信息
        
        // 安全地获取type字段
        int type = 0;
        if (data['type'] != null) {
          if (data['type'] is int) {
            type = data['type'];
          } else if (data['type'] is String) {
            type = int.tryParse(data['type']) ?? 0;
          }
        }
        
        final bool holiday = data['holiday'] != null && data['holiday'] != false;
        
        // 根据API文档判断日期类型
        if (holiday || type == 2) {
          return '假日';
        } else if (type == 1) {
          return '周末';
        } else {
          return '工作日';
        }
      } else {
        print('API调用失败，状态码: ${response.statusCode}');
        return _getLocalDateType(date);
      }
    } catch (e) {
      print('节假日API调用失败: $e');
      // 网络错误或超时，使用本地逻辑
      return _getLocalDateType(date);
    }
  }
  
  /// 本地日期类型判断（备用方案）
  static String _getLocalDateType(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return '周末';
    }
    return '工作日';
  }
  
  /// 批量获取一年的节假日数据（可选，用于缓存）
  static Future<Map<String, String>> getYearHolidays(int year) async {
    try {
      final url = '$_baseUrl/year/$year';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter App'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, String> holidays = {};
        
        // 解析返回的节假日数据
        if (data['holiday'] != null && data['holiday'] is Map) {
          final holidayMap = data['holiday'] as Map<String, dynamic>;
          for (String dateKey in holidayMap.keys) {
            holidays['$year-$dateKey'] = '假日';
          }
        }
        
        return holidays;
      }
    } catch (e) {
      print('获取年度节假日数据失败: $e');
    }
    
    return {};
  }
}