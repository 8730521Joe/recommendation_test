// 置信度计算器 - 统一的场景分析逻辑
class ConfidenceCalculator {
  
  /// 分析场景并返回评分结果
  static List<ResultScene> analyzeScenes(List<Scene> scenes, Map<String, dynamic> userInput) {
    List<ResultScene> scoredScenes = [];
    
    for (var scene in scenes) {
      double score = 0;

      // 检查五个分类并计算分数
      // 1. strong_correlation_index: +3分
      double strongScore = _calculateCategoryScore(scene.strongCorrelationIndex, userInput, 3);
      score += strongScore;
      
      // 2. related_index: +1分
      double relatedScore = _calculateCategoryScore(scene.relatedIndex, userInput, 1);
      score += relatedScore;
      
      // 3. unrelated: 0分 (不需要处理)
      
      // 4. negative_correlation_index: -1分
      double negativeScore = _calculateCategoryScore(scene.negativeCorrelationIndex, userInput, -1);
      score += negativeScore;
      
      // 5. exclusion_index: -3分
      double exclusionScore = _calculateCategoryScore(scene.exclusionIndex, userInput, -5);
      score += exclusionScore;

      // 应用特殊规则调整
      double specialRuleAdjustment = _applySpecialRules(scene.sceneName, userInput);
      score += specialRuleAdjustment;

      // 调试信息
      if (strongScore != 0 || relatedScore != 0 || negativeScore != 0 || exclusionScore != 0 || specialRuleAdjustment != 0) {
        print('场景: ${scene.sceneName}, 强相关: $strongScore, 相关: $relatedScore, 负相关: $negativeScore, 排除: $exclusionScore, 特殊规则: $specialRuleAdjustment, 总分: $score');
      }

      scoredScenes.add(ResultScene(scene.sceneName, score));
    }

    // 按分数降序排列
    scoredScenes.sort((a, b) => b.score.compareTo(a.score));
    
    return scoredScenes.take(10).toList(); // 返回前10个结果
  }

  /// 应用特殊规则调整
  static double _applySpecialRules(String sceneName, Map<String, dynamic> userInput) {
    double adjustment = 0;
    final questionnaireInfo = userInput['questionnaire_info']?.toString() ?? '';
    
    // 规则1: 若用户不是"母婴用户"，"婴儿安睡"的置信度减10，"准妈妈胎教"的置信度减5
    if (questionnaireInfo != '母婴用户') {
      if (sceneName == '婴儿安睡') {
        adjustment -= 10;
        print('特殊规则调整: ${sceneName} - 非母婴用户，减10分');
      } else if (sceneName == '准妈妈胎教') {
        adjustment -= 5;
        print('特殊规则调整: ${sceneName} - 非母婴用户，减5分');
      }
    }
    
    // 规则2: 若用户不是"女性"，"婴儿安睡"的置信度减5，"准妈妈胎教"的置信度减10
    if (questionnaireInfo != '女性') {
      if (sceneName == '婴儿安睡') {
        adjustment -= 5;
        print('特殊规则调整: ${sceneName} - 非女性用户，减5分');
      } else if (sceneName == '准妈妈胎教') {
        adjustment -= 10;
        print('特殊规则调整: ${sceneName} - 非女性用户，减10分');
      } else if (sceneName == '经期舒缓') {
        adjustment -= 15;
        print('特殊规则调整: ${sceneName} - 非女性用户，减15分');
      }
    }
    
    // 规则3: 若用户不是"养宠物"，则"宠物陪伴"的置信度减5
    if (questionnaireInfo != '养宠物') {
      if (sceneName == '宠物陪伴') {
        adjustment -= 5;
        print('特殊规则调整: ${sceneName} - 非养宠物用户，减5分');
      }
    }
    
    // 规则4: 基于时间的特殊规则
    final timePeriod = userInput['time_period']?.toString() ?? '';
    if (timePeriod.isNotEmpty) {
      final currentHour = _parseHourFromTime(timePeriod);
      
      // 若时间不处于21:00-06:59，则"深度睡眠"的置信度减10
      if (sceneName == '深度睡眠') {
        if (!_isInTimeRange(currentHour, 21, 6, true)) {
          adjustment -= 10;
          print('特殊规则调整: ${sceneName} - 非睡眠时间段(21:00-06:59)，减10分');
        }
      }
      
      // 若时间不处于12:00-15:59，则"睡个午觉"的置信度减10
      if (sceneName == '睡个午觉') {
        if (!_isInTimeRange(currentHour, 12, 15, false)) {
          adjustment -= 10;
          print('特殊规则调整: ${sceneName} - 非午休时间段(12:00-15:59)，减10分');
        }
      }
      
      // 若时间不处于20:00-03:59，则"深夜emo"的置信度减10
      if (sceneName == '深夜emo') {
        if (!_isInTimeRange(currentHour, 20, 3, true)) {
          adjustment -= 10;
          print('特殊规则调整: ${sceneName} - 非深夜时间段(20:00-03:59)，减10分');
        }
      }
    }
    
    // 规则5: 基于日期类型的特殊规则
    final dateType = userInput['date_type']?.toString() ?? '';
    
    // 若日期类型不是"工作日"，则"沉浸工作"的置信度减10
    if (sceneName == '沉浸工作' && dateType != '工作日') {
      adjustment -= 10;
      print('特殊规则调整: ${sceneName} - 非工作日(${dateType})，减10分');
    }
    
    // 若日期类型不是"工作日"，则"工作通勤"的置信度减10
    if (sceneName == '工作通勤' && dateType != '工作日') {
      adjustment -= 10;
      print('特殊规则调整: ${sceneName} - 非工作日(${dateType})，减10分');
    }
    
    return adjustment;
  }
  
  /// 从时间字符串中解析小时数
  static int _parseHourFromTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 1) {
        return int.parse(parts[0]);
      }
    } catch (e) {
      print('解析时间失败: $timeString');
    }
    return 0;
  }
  
  /// 判断当前小时是否在指定时间范围内
  /// [currentHour] 当前小时 (0-23)
  /// [startHour] 开始小时
  /// [endHour] 结束小时
  /// [crossMidnight] 是否跨越午夜 (如21:00-06:59)
  static bool _isInTimeRange(int currentHour, int startHour, int endHour, bool crossMidnight) {
    if (crossMidnight) {
      // 跨越午夜的情况 (如21:00-06:59)
      return currentHour >= startHour || currentHour <= endHour;
    } else {
      // 不跨越午夜的情况 (如12:00-15:59)
      return currentHour >= startHour && currentHour <= endHour;
    }
  }

  /// 计算单个分类的分数
  static double _calculateCategoryScore(Map<String, dynamic>? category, Map<String, dynamic> userInput, double scoreValue) {
    if (category == null) return 0;
    
    double totalScore = 0;
    
    category.forEach((key, value) {
      final userValue = userInput[key];
      if (userValue == null || (userValue is String && userValue.isEmpty)) {
        return;
      }
      
      if (value is List) {
        for (var v in value) {
          if (_isMatch(userValue.toString(), v.toString(), key)) {
            totalScore += scoreValue;
            print('匹配成功: $key = ${userValue.toString()} 匹配 ${v.toString()}, 得分: $scoreValue');
            break; // 每个参数只计算一次分数
          }
        }
      }
    });
    
    return totalScore;
  }

  /// 判断用户输入是否匹配场景条件
  static bool _isMatch(String userInput, String sceneCondition, String parameterType) {
    // 处理空值和默认值
    if (userInput.isEmpty || userInput == '' || userInput == 'null') {
      return false;
    }
    
    // 时间段特殊处理 - 24小时制，精确到分钟
    if (parameterType == 'time_period') {
      return _isTimeMatch(userInput, sceneCondition);
    }
    
    // 其他参数直接比较
    bool match = userInput == sceneCondition;
    if (match) {
      print('直接匹配: $userInput == $sceneCondition');
    }
    return match;
  }

  /// 时间匹配逻辑
  static bool _isTimeMatch(String userTime, String timeRange) {
    try {
      // 解析用户输入的时间 (HH:MM 格式)
      final userTimeParts = userTime.split(':');
      if (userTimeParts.length != 2) return false;
      
      final userHour = int.parse(userTimeParts[0]);
      final userMinute = int.parse(userTimeParts[1]);
      final userTotalMinutes = userHour * 60 + userMinute;
      
      // 解析时间范围 (HH:MM-HH:MM 格式)
      final rangeParts = timeRange.split('-');
      if (rangeParts.length != 2) return false;
      
      final startParts = rangeParts[0].split(':');
      final endParts = rangeParts[1].split(':');
      
      if (startParts.length != 2 || endParts.length != 2) return false;
      
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final startTotalMinutes = startHour * 60 + startMinute;
      
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      final endTotalMinutes = endHour * 60 + endMinute;
      
      // 检查是否在时间范围内
      if (endTotalMinutes < startTotalMinutes) {
        // 跨天的情况 (如 22:00-06:00)
        return userTotalMinutes >= startTotalMinutes || userTotalMinutes <= endTotalMinutes;
      } else {
        // 同一天的情况
        return userTotalMinutes >= startTotalMinutes && userTotalMinutes <= endTotalMinutes;
      }
    } catch (e) {
      return false;
    }
  }
}

/// 场景数据模型
class Scene {
  final String sceneName;
  final Map<String, dynamic>? strongCorrelationIndex;
  final Map<String, dynamic>? relatedIndex;
  final Map<String, dynamic>? unrelated;
  final Map<String, dynamic>? negativeCorrelationIndex;
  final Map<String, dynamic>? exclusionIndex;

  Scene.fromJson(Map<String, dynamic> json)
      : sceneName = json['scene_name'],
        strongCorrelationIndex = json['strong_correlation_index'],
        relatedIndex = json['related_index'],
        unrelated = json['unrelated'],
        negativeCorrelationIndex = json['negative_correlation_index'],
        exclusionIndex = json['exclusion_index'];
}

/// 结果场景数据模型
class ResultScene {
  final String name;
  final double score;

  ResultScene(this.name, this.score);
}