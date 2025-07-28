import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '场景感知模拟器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SceneSimulatorPage(),
    );
  }
}

class SceneSimulatorPage extends StatefulWidget {
  const SceneSimulatorPage({super.key});

  @override
  _SceneSimulatorPageState createState() => _SceneSimulatorPageState();
}

class _SceneSimulatorPageState extends State<SceneSimulatorPage> {
  List<Scene> _scenes = [];
  List<ResultScene> _resultScenes = [];

  // Input values
  final TextEditingController _timeController = TextEditingController();
  String? _dateType = '皆可';
  String? _poiType = '家';
  String? _movementStatus = '静止';
  String? _weather = '--';
  String? _physicalActivity = '静止';
  String? _heartRateLevel = '静息';
  String? _networkStatus = '家用Wi-Fi';
  String? _bluetoothConnection = '无';
  final TextEditingController _calendarKeywordsController = TextEditingController();
  String? _questionnaireInfo = '--';

  @override
  void initState() {
    super.initState();
    _loadScenes();
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
      'time_period': _timeController.text,
      'date_type': _dateType,
      'poi_type': _poiType,
      'movement_status': _movementStatus,
      'weather': _weather,
      'physical_activity': _physicalActivity,
      'heart_rate_level': _heartRateLevel,
      'network_status': _networkStatus,
      'bluetooth_connection': _bluetoothConnection,
      'calendar_keywords': _calendarKeywordsController.text,
      'questionnaire_info': _questionnaireInfo,
    };

    List<ResultScene> scoredScenes = [];
    for (var scene in _scenes) {
      double score = 0;
      bool excluded = false;

      // Check for exclusions
      if (scene.exclude != null) {
        scene.exclude!.forEach((key, value) {
          final userValue = userInput[key];
          if (userValue == null || (userValue is String && userValue.isEmpty)) {
            return;
          }
          if (value is List) {
            for (var v in value) {
              if (_isMatch(userValue.toString(), v.toString())) {
                excluded = true;
                break;
              }
            }
          } else if (value is String) {
            if (_isMatch(userValue.toString(), value)) {
              excluded = true;
            }
          }
          if (excluded) return;
        });
      }

      if (excluded) {
        scoredScenes.add(ResultScene(scene.sceneName, -1)); // Assign a very low score
        continue;
      }

      // Calculate score based on conditions
      scene.conditions.forEach((key, value) {
        final userValue = userInput[key];
        if (userValue == null || (userValue is String && userValue.isEmpty)) {
          return;
        }

        final sceneValue = value;

        if (sceneValue is List) {
          for (var v in sceneValue) {
            if (_isMatch(userValue.toString(), v.toString())) {
              if (v.toString().startsWith('*')) {
                score += 3; // Strong association
              } else {
                score += 1;
              }
            }
          }
        } else if (sceneValue is String) {
          if (_isMatch(userValue.toString(), sceneValue)) {
            if (sceneValue.startsWith('*')) {
              score += 3; // Strong association
            } else {
              score += 1;
            }
          }
        }
      });
      scoredScenes.add(ResultScene(scene.sceneName, score));
    }

    scoredScenes.sort((a, b) => b.score.compareTo(a.score));

    setState(() {
      _resultScenes = scoredScenes.where((s) => s.score >= 0).take(5).toList();
    });
  }

  bool _isMatch(String userInput, String sceneCondition) {
    if (sceneCondition == '--' || sceneCondition == '皆可') {
      return true; // Weak or any
    }

    if (sceneCondition.startsWith('!=')) {
      return userInput != sceneCondition.substring(2);
    }

    String cleanCondition = sceneCondition.startsWith('*') ? sceneCondition.substring(1) : sceneCondition;
    
    // Time period logic
    if (cleanCondition.contains('点')) {
        // Simplified time logic, checks if user input hour is within any of the ranges
        try {
            int userHour = int.parse(userInput);
            final parts = cleanCondition.replaceAll('点', '').split('-');
            if (parts.length == 2) {
                int start = int.parse(parts[0]);
                int end = int.parse(parts[1]);
                if (end < start) { // overnight
                    if (userHour >= start || userHour < end) return true;
                } else {
                    if (userHour >= start && userHour < end) return true;
                }
            }
            return false;
        } catch (e) {
            return false; // Not a valid integer for time
        }
    }

    return userInput == cleanCondition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('场景感知模拟器'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(_timeController, '时间-时段 (输入0-23的整数)'),
            _buildDropdown('时间-日期类型', _dateType, ['皆可', '周末', '假日', '工作日'], (val) => setState(() => _dateType = val)),
            _buildDropdown('地理-地点类型', _poiType, ['家', '酒店', '餐厅', '公园', '图书馆', '书店', '公司', '办公室', '健身房', '户外公园', '在途', '地铁站', '沿线', '机场', '酒吧', '酒馆', '咖啡馆', '自然环境', '寺庙', '茶馆', '户外', '自然', '营地', '室内', '海滩', '海边', '工作室', '早教中心'], (val) => setState(() => _poiType = val)),
            _buildDropdown('地理-移动状态', _movementStatus, ['静止', '慢速移动', '跑步', '高活动度', '高速移动', '候机', '飞行', '步行', '站立'], (val) => setState(() => _movementStatus = val)),
            _buildDropdown('环境-天气', _weather, ['--', '晴', '多云', '雨'], (val) => setState(() => _weather = val)),
            _buildDropdown('生理-物理活动', _physicalActivity, ['静止', '站立', '静坐', '在车上', '跑步', '步行', '高活动度'], (val) => setState(() => _physicalActivity = val)),
            _buildDropdown('生理-心率水平', _heartRateLevel, ['静息', '稍高', '高', '极高', '稳定偏高', '波动', '上升', '下降'], (val) => setState(() => _heartRateLevel = val)),
            _buildDropdown('设备-网络状态', _networkStatus, ['家用Wi-Fi', '公共Wi-Fi', '蜂窝数据', '公司Wi-Fi', '机场Wi-Fi', '无网络', 'Wi-Fi', '蜂窝数据(弱)'], (val) => setState(() => _networkStatus = val)),
            _buildDropdown('设备-蓝牙连接', _bluetoothConnection, ['音响', '耳机', '无', '车载', '车载蓝牙'], (val) => setState(() => _bluetoothConnection = val)),
            _buildTextField(_calendarKeywordsController, '用户-日历关键词'),
            _buildDropdown('用户-问卷信息', _questionnaireInfo, ['--', '是母婴用户', '创意工作者', '养宠物', '女性'], (val) => setState(() => _questionnaireInfo = val)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _analyzeScenes,
              child: const Text('分析场景'),
            ),
            const SizedBox(height: 20),
            const Text('分析结果:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ..._resultScenes.map((scene) => Card(
              child: ListTile(
                title: Text(scene.name),
                trailing: Text('置信度: ${scene.score.toStringAsFixed(2)}'),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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

class Scene {
  final String sceneName;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic>? exclude;

  Scene.fromJson(Map<String, dynamic> json)
      : sceneName = json['scene_name'],
        conditions = json['conditions'] ?? _extractConditions(json),
        exclude = json['exclude'];

  static Map<String, dynamic> _extractConditions(Map<String, dynamic> json) {
    final conditions = Map<String, dynamic>.from(json);
    conditions.remove('scene_name');
    conditions.remove('exclude');
    return conditions;
  }
}

class ResultScene {
  final String name;
  final double score;

  ResultScene(this.name, this.score);
}