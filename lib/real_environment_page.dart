import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'dart:async';
import 'confidence_calculator.dart';
import 'holiday_service.dart'; // 导入节假日服务
import 'settings_page.dart'; // 导入设置页面

class RealEnvironmentPage extends StatefulWidget {
  const RealEnvironmentPage({super.key});

  @override
  _RealEnvironmentPageState createState() => _RealEnvironmentPageState();
}

class _RealEnvironmentPageState extends State<RealEnvironmentPage> {
  List<Scene> _scenes = [];
  List<ResultScene> _resultScenes = [];
  bool _isLoadingDateType = false; // 添加加载状态
  
  // 活动识别相关状态
  bool _activityPermissionEnabled = false;
  String _currentActivity = '未知';
  StreamSubscription<Activity>? _activitySubscription;
  
  // 30秒内活动历史记录
  List<ActivityRecord> _activityHistory = [];
  Timer? _cleanupTimer;

  // Input values - 更新为新的参数列表
  String _currentTime = '';
  String? _dateType = '工作日';
  String? _poiType = '住宅区';
  String? _movementStatus = '静止';
  String? _weather = '晴';
  String? _physicalActivity = '静止'; // 现在自动填写
  String? _heartRateLevel = '静息';
  String? _networkStatus = 'wifi';
  String? _bluetoothConnection = '无';
  String? _questionnaireInfo = '';

  @override
  void initState() {
    super.initState();
    _loadScenes();
    _updateCurrentTimeAndDateType();
    _checkActivityPermissionStatus();
    _startCleanupTimer();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // 启动定时清理器，每5秒清理一次过期的活动记录
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _cleanupOldActivities();
    });
  }

  // 清理30秒前的活动记录
  void _cleanupOldActivities() {
    final now = DateTime.now();
    _activityHistory.removeWhere((record) => 
        now.difference(record.timestamp).inSeconds > 30);
    _updatePhysicalActivityFromHistory();
  }

  // 根据活动历史更新物理活动字段
  void _updatePhysicalActivityFromHistory() {
    if (_activityHistory.isEmpty) {
      setState(() {
        _physicalActivity = '静止';
      });
      return;
    }

    // 统计各活动类型的出现次数
    Map<String, int> activityCount = {};
    for (var record in _activityHistory) {
      if (record.activity != '未知活动') { // 忽略UNKNOWN
        activityCount[record.activity] = (activityCount[record.activity] ?? 0) + 1;
      }
    }

    if (activityCount.isEmpty) {
      setState(() {
        _physicalActivity = '静止';
      });
      return;
    }

    // 找出出现次数最多的活动
    String mostFrequentActivity = activityCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    setState(() {
      _physicalActivity = mostFrequentActivity;
    });
  }

  // 检查活动识别权限状态
  Future<void> _checkActivityPermissionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('activity_permission_enabled') ?? false;
      
      setState(() {
        _activityPermissionEnabled = isEnabled;
      });
      
      if (isEnabled) {
        _startActivityRecognition();
      }
    } catch (e) {
      print('检查活动识别权限状态失败: $e');
    }
  }

  // 开始活动识别监听
  void _startActivityRecognition() async {
    try {
      final activityStream = FlutterActivityRecognition.instance.activityStream;
      _activitySubscription = activityStream.listen((Activity activity) {
        final activityDescription = _getActivityDescription(activity.type);
        
        setState(() {
          _currentActivity = activityDescription;
        });
        
        // 添加到活动历史记录
        _activityHistory.add(ActivityRecord(
          activity: activityDescription,
          timestamp: DateTime.now(),
        ));
        
        // 立即更新物理活动字段
        _updatePhysicalActivityFromHistory();
      });
    } catch (e) {
      print('开始活动识别失败: $e');
      setState(() {
        _currentActivity = '识别失败';
      });
    }
  }

  // 获取活动描述
  String _getActivityDescription(ActivityType type) {
    switch (type) {
      case ActivityType.STILL:
        return '静止';
      case ActivityType.WALKING:
        return '步行';
      case ActivityType.RUNNING:
        return '跑步';
      case ActivityType.ON_BICYCLE:
        return '骑行';
      case ActivityType.IN_VEHICLE:
        return '驾车';
      default:
        return '未知活动';
    }
  }

  // 构建活动识别状态显示组件
  Widget _buildActivityRecognitionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4.0),
          color: _activityPermissionEnabled ? Colors.green.shade50 : Colors.red.shade50,
        ),
        child: Row(
          children: [
            Icon(
              _activityPermissionEnabled ? Icons.directions_run : Icons.block,
              color: _activityPermissionEnabled ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '活动识别状态',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_activityPermissionEnabled)
                    Text(
                      '当前活动: $_currentActivity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        ).then((_) {
                          // 从设置页面返回后重新检查权限状态
                          _checkActivityPermissionStatus();
                        });
                      },
                      child: const Text(
                        '权限未开启 (点击设置)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_activityPermissionEnabled)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.green),
                onPressed: () {
                  _activitySubscription?.cancel();
                  _startActivityRecognition();
                },
                tooltip: '刷新活动识别',
              ),
          ],
        ),
      ),
    );
  }

  // 构建物理活动自动显示组件
  Widget _buildPhysicalActivityDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4.0),
          color: Colors.blue.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '物理活动 (自动识别)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _physicalActivity ?? '静止',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (_activityPermissionEnabled && _activityHistory.isNotEmpty)
                    Text(
                      '基于过去30秒内${_activityHistory.length}次检测结果',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCurrentTimeAndDateType() async {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _isLoadingDateType = true;
    });

    // 异步获取日期类型
    try {
      final dateType = await HolidayService.getDateType(now);
      setState(() {
        _dateType = dateType;
        _isLoadingDateType = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDateType = false;
      });
    }
  }

  Future<void> _loadScenes() async {
    final String response = await rootBundle.loadString('source/scene.json');
    final data = await json.decode(response) as List;
    setState(() {
      _scenes = data.map((json) => Scene.fromJson(json)).toList();
    });
  }

  void _analyzeScenes() {
    final userInput = {
      'time_period': _currentTime,
      'date_type': _dateType,
      'poi_type': _poiType,
      'movement_status': _movementStatus,
      'weather': _weather,
      'physical_activity': _physicalActivity,
      'heart_rate_level': _heartRateLevel,
      'network_status': _networkStatus,
      'bluetooth_connection': _bluetoothConnection,
      'questionnaire_info': _questionnaireInfo,
    };

    // 使用统一的置信度计算器
    final results = ConfidenceCalculator.analyzeScenes(_scenes, userInput);

    setState(() {
      _resultScenes = results;
    });
  }

  Widget _buildTimeDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '当前时间: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  _currentTime,
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _updateCurrentTimeAndDateType,
                  tooltip: '刷新时间和日期类型',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '日期类型: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (_isLoadingDateType)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDateTypeColor(_dateType),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _dateType ?? '未知',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                const Spacer(),
                const Text(
                  '(自动检测)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getDateTypeColor(String? dateType) {
    switch (dateType) {
      case '工作日':
        return Colors.blue;
      case '周末':
        return Colors.green;
      case '假日':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('真实环境'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimeDisplay(),
            _buildDropdown('地点类型', _poiType, ['住宅区', '商场', '酒店', '餐厅', '公园', '写字楼', '机场', '图书馆', '海边', '户外', '在途', '高铁站', '地铁站'], (val) => setState(() => _poiType = val)),
            _buildDropdown('移动状态', _movementStatus, ['静止', '慢速', '中速', '高速'], (val) => setState(() => _movementStatus = val)),
            _buildDropdown('天气', _weather, ['晴', '阴', '雨'], (val) => setState(() => _weather = val)),
            // 活动识别状态显示
            _buildActivityRecognitionStatus(),
            // 物理活动自动显示（替换原来的下拉框）
            _buildPhysicalActivityDisplay(),
            _buildDropdown('心率水平', _heartRateLevel, ['静息', '稍高', '高', '波动'], (val) => setState(() => _heartRateLevel = val)),
            _buildDropdown('网络状态', _networkStatus, ['wifi', '蜂窝数据', '无网络', '飞行模式', '蜂窝数据（弱）'], (val) => setState(() => _networkStatus = val)),
            _buildDropdown('蓝牙状态', _bluetoothConnection, ['有线耳机', '无线耳机', '其他蓝牙', '无', '车载'], (val) => setState(() => _bluetoothConnection = val)),
            _buildDropdown('其他用户信息', _questionnaireInfo, ['', '母婴用户', '女性', '养宠物', '学生'], (val) => setState(() => _questionnaireInfo = val)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _updateCurrentTimeAndDateType(); // 分析前更新时间和日期类型
                _analyzeScenes();
              },
              child: const Text('分析场景'),
            ),
            const SizedBox(height: 20),
            const Text('分析结果:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ..._resultScenes.map((scene) => Card(
              child: ListTile(
                title: Text(scene.name),
                trailing: Text('置信度: ${scene.score.toStringAsFixed(1)}'),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// 活动记录类
class ActivityRecord {
  final String activity;
  final DateTime timestamp;

  ActivityRecord({
    required this.activity,
    required this.timestamp,
  });
}