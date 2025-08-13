import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'confidence_calculator.dart'; // 确保导入

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});

  @override
  _SimulatorPageState createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  List<Scene> _scenes = [];
  List<ResultScene> _resultScenes = [];

  // Input values - 更新为新的参数列表
  final TextEditingController _timeController = TextEditingController();
  String? _dateType = '工作日';
  String? _poiType = '住宅区';
  String? _movementStatus = '静止';
  String? _weather = '晴';
  String? _physicalActivity = '静止';
  String? _heartRateLevel = '静息';
  String? _networkStatus = 'wifi';
  String? _bluetoothConnection = '无';
  String? _questionnaireInfo = '';

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
      'questionnaire_info': _questionnaireInfo,
    };

    // 使用统一的置信度计算器
    final results = ConfidenceCalculator.analyzeScenes(_scenes, userInput);

    setState(() {
      _resultScenes = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模拟测试'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(_timeController, '时段 (24小时制，格式: HH:MM，如 14:30)'),
            _buildDropdown('日期类型', _dateType, ['周末', '假日', '工作日'], (val) => setState(() => _dateType = val)),
            _buildDropdown('地点类型', _poiType, ['住宅区', '商场', '酒店', '餐厅', '公园', '写字楼', '机场', '图书馆', '海边', '户外', '在途', '高铁站', '地铁站'], (val) => setState(() => _poiType = val)),
            _buildDropdown('移动状态', _movementStatus, ['静止', '慢速', '中速', '高速'], (val) => setState(() => _movementStatus = val)),
            _buildDropdown('天气', _weather, ['晴', '阴', '雨'], (val) => setState(() => _weather = val)),
            _buildDropdown('物理活动', _physicalActivity, ['静止', '步行', '跑步', '驾车', '骑行'], (val) => setState(() => _physicalActivity = val)),
            _buildDropdown('心率水平', _heartRateLevel, ['静息', '稍高', '高', '波动'], (val) => setState(() => _heartRateLevel = val)),
            _buildDropdown('网络状态', _networkStatus, ['wifi', '蜂窝数据', '无网络', '飞行模式', '蜂窝数据（弱）'], (val) => setState(() => _networkStatus = val)),
            _buildDropdown('蓝牙状态', _bluetoothConnection, ['有线耳机', '无线耳机', '其他蓝牙', '无', '车载'], (val) => setState(() => _bluetoothConnection = val)),
            _buildDropdown('其他用户信息', _questionnaireInfo, ['', '母婴用户', '女性', '养宠物', '学生'], (val) => setState(() => _questionnaireInfo = val)),
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
                trailing: Text('置信度: ${scene.score.toStringAsFixed(1)}'),
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
          hintText: '例如: 14:30',
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

// 移除这里的 Scene 和 ResultScene 类定义