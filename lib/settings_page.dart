import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart' as activity_recognition;
import 'package:shared_preferences/shared_preferences.dart';  // 新增导入
import 'dart:async';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _locationPermission = false;
  bool _activityPermission = false;
  bool _healthPermission = false;
  bool _isLoading = false;
  StreamSubscription<activity_recognition.Activity>? _activitySubscription;

  // SharedPreferences 键名
  static const String _locationPermissionKey = 'location_permission_enabled';
  static const String _activityPermissionKey = 'activity_permission_enabled';
  static const String _healthPermissionKey = 'health_permission_enabled';

  @override
  void initState() {
    super.initState();
    _loadPermissionSettings();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  // 加载保存的权限设置
  Future<void> _loadPermissionSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 从本地存储读取权限开关状态，默认为 false（关闭）
      bool locationEnabled = prefs.getBool(_locationPermissionKey) ?? false;
      bool activityEnabled = prefs.getBool(_activityPermissionKey) ?? false;
      bool healthEnabled = prefs.getBool(_healthPermissionKey) ?? false;
      
      setState(() {
        _locationPermission = locationEnabled;
        _activityPermission = activityEnabled;
        _healthPermission = healthEnabled;
        _isLoading = false;
      });
      
      // 如果活动权限开关是开启状态，检查系统权限并开始监听
      if (activityEnabled) {
        _checkAndStartActivityRecognition();
      }
    } catch (e) {
      print('加载权限设置失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 保存权限设置到本地存储
  Future<void> _savePermissionSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      print('保存权限设置失败: $e');
    }
  }

  // 检查并开始活动识别（仅在开关开启时）
  Future<void> _checkAndStartActivityRecognition() async {
    try {
      final activityPermission = await activity_recognition.FlutterActivityRecognition.instance.checkPermission();
      if (activityPermission == activity_recognition.ActivityPermission.GRANTED) {
        _startActivityRecognitionSilently();
      }
    } catch (e) {
      print('检查活动权限失败: $e');
    }
  }

  // 请求地理位置权限
  Future<void> _requestLocationPermission(bool value) async {
    // 保存开关状态
    await _savePermissionSetting(_locationPermissionKey, value);
    
    setState(() {
      _locationPermission = value;
    });

    if (!value) {
      _showErrorSnackBar('地理位置功能已关闭');
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _showSuccessSnackBar('地理位置权限已开启');
      } else if (permission == LocationPermission.deniedForever) {
        // 权限被永久拒绝，但保持开关状态，让用户知道需要手动设置
        _showErrorSnackBar('地理位置权限被永久拒绝，请在系统设置中手动开启');
      } else {
        // 权限被拒绝，关闭开关
        await _savePermissionSetting(_locationPermissionKey, false);
        setState(() {
          _locationPermission = false;
        });
        _showErrorSnackBar('地理位置权限被拒绝');
      }
    } catch (e) {
      print('请求地理位置权限失败: $e');
      await _savePermissionSetting(_locationPermissionKey, false);
      setState(() {
        _locationPermission = false;
      });
      _showErrorSnackBar('请求地理位置权限失败');
    }
  }

  // 请求活动识别权限
  Future<void> _requestActivityPermission(bool value) async {
    // 保存开关状态
    await _savePermissionSetting(_activityPermissionKey, value);
    
    setState(() {
      _activityPermission = value;
    });

    if (!value) {
      _activitySubscription?.cancel();
      _showErrorSnackBar('活动识别功能已关闭');
      return;
    }

    try {
      // 检查并请求权限
      activity_recognition.ActivityPermission permission = await activity_recognition.FlutterActivityRecognition.instance.checkPermission();
      
      if (permission == activity_recognition.ActivityPermission.PERMANENTLY_DENIED) {
        _showErrorSnackBar('活动识别权限已被永久拒绝，请在系统设置中手动开启');
        return;
      }
      
      if (permission == activity_recognition.ActivityPermission.DENIED) {
        permission = await activity_recognition.FlutterActivityRecognition.instance.requestPermission();
      }
      
      if (permission == activity_recognition.ActivityPermission.GRANTED) {
        _showSuccessSnackBar('活动识别权限已开启');
        _startActivityRecognitionSilently();
      } else {
        // 权限被拒绝，关闭开关
        await _savePermissionSetting(_activityPermissionKey, false);
        setState(() {
          _activityPermission = false;
        });
        _showErrorSnackBar('活动识别权限被拒绝');
      }
    } catch (e) {
      print('请求活动识别权限失败: $e');
      await _savePermissionSetting(_activityPermissionKey, false);
      setState(() {
        _activityPermission = false;
      });
      _showErrorSnackBar('请求活动识别权限失败');
    }
  }

  // 静默开始活动识别（不显示结果）
  void _startActivityRecognitionSilently() {
    _activitySubscription?.cancel(); // 先取消之前的订阅
    _activitySubscription = activity_recognition.FlutterActivityRecognition.instance.activityStream.listen(
      (activity_recognition.Activity activity) {
        // 只在控制台输出，不在界面显示
        print('检测到活动状态: ${activity.type}');
        print('置信度: ${activity.confidence}');
        
        // 这里可以添加其他业务逻辑，比如保存到数据库等
        // 但不在设置界面显示结果
      },
      onError: (error) {
        print('活动识别错误: $error');
      },
    );
  }

  // 获取活动描述（保留此方法以备将来使用）
  String _getActivityDescription(activity_recognition.ActivityType type) {
    switch (type) {
      case activity_recognition.ActivityType.STILL:
        return '静止状态（坐着或站着）';
      case activity_recognition.ActivityType.WALKING:
        return '步行';
      case activity_recognition.ActivityType.RUNNING:
        return '跑步';
      case activity_recognition.ActivityType.IN_VEHICLE:
        return '在车辆中';
      case activity_recognition.ActivityType.ON_BICYCLE:
        return '骑行';
      case activity_recognition.ActivityType.UNKNOWN:
      default:
        return '未知活动';
    }
  }

  // 请求健康数据权限（修复版）
  Future<void> _requestHealthPermission(bool value) async {
    // 保存开关状态
    await _savePermissionSetting(_healthPermissionKey, value);
    
    setState(() {
      _healthPermission = value;
    });

    if (!value) {
      _showErrorSnackBar('健康数据功能已关闭');
      return;
    }

    try {
      // 定义需要的健康数据类型
      final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.WORKOUT,
        HealthDataType.HEART_RATE,
      ];

      // 请求权限
      bool requested = await Health().requestAuthorization(types);
      
      if (requested) {
        // 等待一段时间让系统更新权限状态
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 尝试读取一些基本的健康数据来验证权限
        bool hasWorkingPermission = false;
        
        try {
          // 尝试读取步数数据（最基本的健康数据）
          final now = DateTime.now();
          final yesterday = now.subtract(const Duration(days: 1));
          
          List<HealthDataPoint> healthData = await Health().getHealthDataFromTypes(
            types: [HealthDataType.STEPS],
            startTime: yesterday,
            endTime: now,
          );
          
          // 如果能成功获取数据（即使是空数据），说明有权限
          hasWorkingPermission = true;
          print('成功获取健康数据，权限验证通过');
        } catch (e) {
          print('健康数据读取测试失败: $e');
          
          // 如果读取失败，尝试使用hasPermissions检查
          try {
            bool hasStepsPermission = await Health().hasPermissions([HealthDataType.STEPS]) ?? false;
            hasWorkingPermission = hasStepsPermission;
            print('使用hasPermissions检查结果: $hasStepsPermission');
          } catch (e2) {
            print('hasPermissions检查也失败: $e2');
            hasWorkingPermission = false;
          }
        }
        
        if (hasWorkingPermission) {
          _showSuccessSnackBar('健康数据权限已开启');
        } else {
          // 权限验证失败，但给用户一个更友好的提示
          _showErrorSnackBar('健康数据权限可能未完全生效，请稍后重试或重启应用');
          // 不自动关闭开关，让用户决定
        }
      } else {
        // 权限请求失败
        await _savePermissionSetting(_healthPermissionKey, false);
        setState(() {
          _healthPermission = false;
        });
        _showErrorSnackBar('健康数据权限请求失败');
      }
    } catch (e) {
      print('请求健康数据权限失败: $e');
      _showErrorSnackBar('健康数据权限请求出错: ${e.toString()}');
      // 发生异常时不自动关闭开关，让用户重试
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('权限设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '应用权限管理',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '请根据需要开启相应的权限功能：',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  _buildPermissionTile(
                    title: '地理位置权限',
                    subtitle: '用于获取当前位置信息',
                    value: _locationPermission,
                    onChanged: _requestLocationPermission,
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionTile(
                    title: '活动识别权限',
                    subtitle: '用于检测用户的活动状态（步行、跑步等）',
                    value: _activityPermission,
                    onChanged: _requestActivityPermission,
                    icon: Icons.directions_run,
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionTile(
                    title: '健康数据权限',
                    subtitle: '用于读取健康和健身数据',
                    value: _healthPermission,
                    onChanged: _requestHealthPermission,
                    icon: Icons.favorite,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          color: value ? Colors.green : Colors.grey,
          size: 30,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ),
    );
  }
}