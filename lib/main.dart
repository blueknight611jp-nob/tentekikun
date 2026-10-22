import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TentekikunApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class TentekikunApp extends StatelessWidget {
  const TentekikunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '点滴くん',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const TentekiHomePage(),
    );
  }
}

class InfusionMaster {
  final String id;
  final String name;
  final String category;
  final double volume;
  final double totalCalories;
  final double aminoAcid;
  final double lipid;
  final double glucose;
  final double na;
  final double k;
  final double cl;
  final double ca;
  final double mg;
  final double p;
  final DateTime createdAt;

  InfusionMaster({
    required this.id,
    required this.name,
    required this.category,
    required this.volume,
    required this.totalCalories,
    required this.aminoAcid,
    required this.lipid,
    required this.glucose,
    required this.na,
    required this.k,
    required this.cl,
    required this.ca,
    required this.mg,
    required this.p,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get npc => totalCalories - (aminoAcid * 4.0);
  double get nitrogen => aminoAcid / 6.25;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'volume': volume,
        'totalCalories': totalCalories,
        'aminoAcid': aminoAcid,
        'lipid': lipid,
        'glucose': glucose,
        'na': na,
        'k': k,
        'cl': cl,
        'ca': ca,
        'mg': mg,
        'p': p,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InfusionMaster.fromJson(Map<String, dynamic> json) => InfusionMaster(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        volume: (json['volume'] as num).toDouble(),
        totalCalories: (json['totalCalories'] as num).toDouble(),
        aminoAcid: (json['aminoAcid'] as num).toDouble(),
        lipid: (json['lipid'] as num).toDouble(),
        glucose: (json['glucose'] as num).toDouble(),
        na: (json['na'] as num).toDouble(),
        k: (json['k'] as num).toDouble(),
        cl: (json['cl'] as num).toDouble(),
        ca: (json['ca'] as num).toDouble(),
        mg: (json['mg'] as num).toDouble(),
        p: (json['p'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class SelectedInfusionItem {
  final String instanceId;
  final InfusionMaster master;

  SelectedInfusionItem({
    required this.instanceId,
    required this.master,
  });
}

enum MasterSortType {
  addedOrder('追加順'),
  nameOrder('名前順'),
  categoryOrder('種別順'),
  frequentOrder('よく使う順');

  final String label;
  const MasterSortType(this.label);
}

class TentekiHomePage extends StatefulWidget {
  const TentekiHomePage({super.key});

  @override
  State<TentekiHomePage> createState() => _TentekiHomePageState();
}

class _TentekiHomePageState extends State<TentekiHomePage> {
  final ScrollController _selectedListScrollController = ScrollController();
  final ScrollController _masterListScrollController = ScrollController();

  double _weight = 60.0;
  MasterSortType _currentSortType = MasterSortType.frequentOrder;

  List<InfusionMaster> _masterList = [];
  final List<SelectedInfusionItem> _selectedItems = [];
  Map<String, int> _usageCounts = {};

  @override
  void initState() {
    super.initState();
    _loadUsageCounts().then((_) {
      _loadMasterList();
    });
  }

  Future<void> _loadUsageCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('master_usage_counts');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _usageCounts = decoded.map((key, value) => MapEntry(key, value as int));
        });
      } catch (e) {
        debugPrint('使用回数読み込みエラー: $e');
      }
    }
  }

  Future<void> _saveUsageCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('master_usage_counts', jsonEncode(_usageCounts));
  }

  Future<void> _loadMasterList() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('custom_master_list');
    
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _masterList = decoded.map((item) => InfusionMaster.fromJson(item)).toList();
        });
        return;
      } catch (e) {
        debugPrint('マスター読み込みエラー: $e');
      }
    }

    await _loadAssetMasterList();
  }

  Future<void> _loadAssetMasterList() async {
    try {
      final String jsonStringFromAsset = await rootBundle.loadString('assets/master_data.json');
      final List<dynamic> decoded = jsonDecode(jsonStringFromAsset);
      setState(() {
        _masterList = decoded.map((item) => InfusionMaster.fromJson(item)).toList();
      });
    } catch (e) {
      debugPrint('アセットからのマスター読み込みエラー: $e');
      setState(() {
        _masterList = [];
      });
    }
  }

  Future<void> _saveMasterList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _masterList.map((m) => m.toJson()).toList();
    await prefs.setString('custom_master_list', jsonEncode(jsonList));
  }

  Future<void> _resetMasterList() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('マスターデータの初期化', style: TextStyle(fontSize: 16)),
          content: const Text('カスタム追加・編集・削除した内容をすべてリセットし、初期のマスターデータに戻しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('custom_master_list');
                await prefs.remove('master_usage_counts');
                setState(() {
                  _usageCounts.clear();
                });
                await _loadAssetMasterList();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('マスターデータと使用頻度を初期状態にリセットしました')),
                  );
                }
              },
              child: const Text('リセットする'),
            ),
          ],
        );
      },
    );
  }

  List<InfusionMaster> get _sortedMasterList {
    final list = List<InfusionMaster>.from(_masterList);
    switch (_currentSortType) {
      case MasterSortType.addedOrder:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MasterSortType.nameOrder:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case MasterSortType.categoryOrder:
        list.sort((a, b) => a.category.compareTo(b.category));
        break;
      case MasterSortType.frequentOrder:
        list.sort((a, b) {
          final countA = _usageCounts[a.id] ?? 0;
          final countB = _usageCounts[b.id] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return list;
  }

  void _addSingleInfusion(InfusionMaster master) {
    setState(() {
      _selectedItems.add(
        SelectedInfusionItem(
          instanceId: DateTime.now().microsecondsSinceEpoch.toString(),
          master: master,
        ),
      );
      _usageCounts[master.id] = (_usageCounts[master.id] ?? 0) + 1;
    });
    _saveUsageCounts();
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedItems.clear();
    });
  }

  void _showWeightInputDialog() {
    final textVal = _weight.toStringAsFixed(0);
    final TextEditingController controller = TextEditingController(text: textVal)
      ..selection = TextSelection(baseOffset: 0, extentOffset: textVal.length);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('患者体重の入力', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '体重 (kg)',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null && val > 0) {
                  setState(() {
                    _weight = val;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCustomMasterDialog({InfusionMaster? editTarget, InfusionMaster? copyFrom}) {
    final baseData = editTarget ?? copyFrom;

    final nameController = TextEditingController(
      text: baseData != null ? (editTarget != null ? baseData.name : '${baseData.name} (コピー)') : '',
    );
    final categoryController = TextEditingController(
      text: baseData != null ? baseData.category : 'カスタム',
    );
    final volumeController = TextEditingController(
      text: baseData != null ? baseData.volume.toStringAsFixed(0) : '500',
    );
    final calController = TextEditingController(
      text: baseData != null ? baseData.totalCalories.toStringAsFixed(0) : '0',
    );
    final aaController = TextEditingController(
      text: baseData != null ? baseData.aminoAcid.toStringAsFixed(1) : '0',
    );
    final lipidController = TextEditingController(
      text: baseData != null ? baseData.lipid.toStringAsFixed(1) : '0',
    );
    final naController = TextEditingController(
      text: baseData != null ? baseData.na.toStringAsFixed(1) : '0',
    );
    final kController = TextEditingController(
      text: baseData != null ? baseData.k.toStringAsFixed(1) : '0',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            editTarget != null ? '製剤マスターの編集' : (copyFrom != null ? '製剤マスターの複製・追加' : '新しい製剤のカスタム追加'),
            style: const TextStyle(fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: '製剤名 (例: ○○輸液 500mL)')),
                  TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'カテゴリ (例: 維持液 / 電解質液)')),
                  TextField(controller: volumeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '容量 (mL)')),
                  TextField(controller: calController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '総カロリー (kcal)')),
                  TextField(controller: aaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'アミノ酸量 (g)')),
                  TextField(controller: lipidController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '脂質/脂肪量 (g)')),
                  TextField(controller: naController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Na (mEq)')),
                  TextField(controller: kController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'K (mEq)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                if (editTarget != null) {
                  setState(() {
                    final index = _masterList.indexWhere((m) => m.id == editTarget.id);
                    if (index != -1) {
                      _masterList[index] = InfusionMaster(
                        id: editTarget.id,
                        name: name,
                        category: categoryController.text.trim().isEmpty ? 'カスタム' : categoryController.text.trim(),
                        volume: double.tryParse(volumeController.text) ?? 0,
                        totalCalories: double.tryParse(calController.text) ?? 0,
                        aminoAcid: double.tryParse(aaController.text) ?? 0,
                        lipid: double.tryParse(lipidController.text) ?? 0,
                        glucose: editTarget.glucose,
                        na: double.tryParse(naController.text) ?? 0,
                        k: double.tryParse(kController.text) ?? 0,
                        cl: editTarget.cl,
                        ca: editTarget.ca,
                        mg: editTarget.mg,
                        p: editTarget.p,
                        createdAt: editTarget.createdAt,
                      );
                    }
                  });
                } else {
                  final newMaster = InfusionMaster(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    category: categoryController.text.trim().isEmpty ? 'カスタム' : categoryController.text.trim(),
                    volume: double.tryParse(volumeController.text) ?? 0,
                    totalCalories: double.tryParse(calController.text) ?? 0,
                    aminoAcid: double.tryParse(aaController.text) ?? 0,
                    lipid: double.tryParse(lipidController.text) ?? 0,
                    glucose: 0,
                    na: double.tryParse(naController.text) ?? 0,
                    k: double.tryParse(kController.text) ?? 0,
                    cl: 0,
                    ca: 0,
                    mg: 0,
                    p: 0,
                    createdAt: DateTime.now(),
                  );

                  setState(() {
                    _masterList.add(newMaster);
                  });
                }

                await _saveMasterList();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「$name」を保存しました')),
                  );
                }
              },
              child: Text(editTarget != null ? '更新する' : '追加する'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMasterItem(InfusionMaster master) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('マスターデータの削除', style: TextStyle(fontSize: 16)),
          content: Text('「${master.name}」をマスターから削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                setState(() {
                  _masterList.removeWhere((m) => m.id == master.id);
                  _usageCounts.remove(master.id);
                });
                await _saveMasterList();
                await _saveUsageCounts();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「${master.name}」を削除しました')),
                  );
                }
              },
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
  }

  // --- 解説ポップアップを表示するメソッド ---
  void _showExplanationDialog(String title, String statusType, String description) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                statusType == '過剰 (赤字)' ? Icons.warning_amber_rounded : Icons.info_outline,
                color: statusType == '過剰 (赤字)' ? Colors.red : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title [$statusType]',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  double get _totalVolume => _selectedItems.fold(0, (sum, item) => sum + item.master.volume);
  double get _totalCalories => _selectedItems.fold(0, (sum, item) => sum + item.master.totalCalories);
  double get _totalNpc => _selectedItems.fold(0, (sum, item) => sum + item.master.npc);
  double get _totalNitrogen => _selectedItems.fold(0, (sum, item) => sum + item.master.nitrogen);
  
  double get _npcNitrogenRatio {
    final n = _totalNitrogen;
    if (n <= 0) return 0;
    return _totalNpc / n;
  }

  double get _totalLipid => _selectedItems.fold(0, (sum, item) => sum + item.master.lipid);
  
  double get _lipidEnergyRatio {
    final cal = _totalCalories;
    if (cal <= 0) return 0;
    final lipidCal = _totalLipid * 9.0;
    return (lipidCal / cal) * 100.0;
  }

  double get _totalNa => _selectedItems.fold(0, (sum, item) => sum + item.master.na);
  double get _totalK => _selectedItems.fold(0, (sum, item) => sum + item.master.k);

  @override
  void dispose() {
    _selectedListScrollController.dispose();
    _masterListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('点滴くん - 栄養・輸液積算ツール'),
        actions: [
          if (_selectedItems.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text('全クリア', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 330,
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: _buildSummaryWindow(),
                ),
                const VerticalDivider(width: 2, thickness: 2),
                Expanded(
                  child: _buildSelectedListWindow(),
                ),
              ],
            ),
          ),
          const Divider(height: 2, thickness: 2),
          Expanded(
            child: _buildMasterSelectionWindow(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryWindow() {
    final lipidStr = _totalLipid > 0
        ? '${_totalLipid.toStringAsFixed(1)}g (${_lipidEnergyRatio.toStringAsFixed(1)}%)'
        : '0.0g (0.0%)';

    final volPerKg = _weight > 0 ? _totalVolume / _weight : 0.0;
    final calPerKg = _weight > 0 ? _totalCalories / _weight : 0.0;
    final npcPerKg = _weight > 0 ? _totalNpc / _weight : 0.0;
    final naPerKg = _weight > 0 ? _totalNa / _weight : 0.0;
    final kPerKg = _weight > 0 ? _totalK / _weight : 0.0;

    // --- 各項目の判定と解説テキストの定義 (14パターン) ---
    Color volColor = Colors.teal;
    String? volStatus;
    String? volDesc;
    if (_selectedItems.isNotEmpty) {
      if (volPerKg > 35) {
        volColor = Colors.red;
        volStatus = '過剰 (赤字)';
        volDesc = '水分量が推奨上限（35 mL/kg）を超えています。\n\n【臨床的注意】\n輸液過負荷によるうっ血性心不全、肺水腫、胸水貯留、下腿浮腫などに十分注意してください。';
      } else if (volPerKg < 25) {
        volColor = Colors.blue.shade700;
        volStatus = '不足 (青字)';
        volDesc = '水分量が推奨下限（25 mL/kg）を下回っています。\n\n【臨床的注意】\n脱水、腎血流量低下、BUN/Cr比の上昇（腎前性腎不全）や電解質異常のリスクに注意してください。';
      }
    }

    Color calColor = Colors.teal;
    String? calStatus;
    String? calDesc;
    if (_selectedItems.isNotEmpty) {
      if (calPerKg > 30) {
        calColor = Colors.red;
        calStatus = '過剰 (赤字)';
        calDesc = 'カロリーが推奨上限（30 kcal/kg）を超えています。\n\n【臨床的注意】\n過剰投与による高血糖、高トリグリセリド血症、肝機能障害（脂肪肝 / AFLD・PNALD）のリスクに注意してください。';
      } else if (calPerKg < 20) {
        calColor = Colors.blue.shade700;
        calStatus = '不足 (青字)';
        calDesc = 'カロリーが推奨下限（20 kcal/kg）を下回っています。\n\n【臨床的注意】\n低栄養状態、蛋白異化の亢進、免疫力低下や創傷治癒の遅延に注意してください。';
      }
    }

    Color npcColor = Colors.teal;
    String? npcStatus;
    String? npcDesc;
    if (_selectedItems.isNotEmpty) {
      if (npcPerKg > 25) {
        npcColor = Colors.red;
        npcStatus = '過剰 (赤字)';
        npcDesc = '非蛋白熱量（NPC）が推奨上限（25 kcal/kg）を超過しています。\n\n【臨床的注意】\n糖質や脂肪の過剰負荷による高血糖やインスリン抵抗性の増大に注意してください。';
      } else if (npcPerKg < 15) {
        npcColor = Colors.blue.shade700;
        npcStatus = '不足 (青字)';
        npcDesc = '非蛋白熱量（NPC）が推奨下限（15 kcal/kg）を下回っています。\n\n【臨床的注意】\nエネルギー不足により、投与されたアミノ酸が効率よく蛋白合成に使われずエネルギー源として消費されてしまう可能性があります。';
      }
    }

    Color npcNColor = Colors.teal;
    String? npcNStatus;
    String? npcNDesc;
    if (_selectedItems.isNotEmpty && _totalNitrogen > 0) {
      if (_npcNitrogenRatio > 175) {
        npcNColor = Colors.red;
        npcNStatus = '過剰 (赤字)';
        npcDesc = 'NPC/N比が推奨上限（175）を超えています（糖質・カロリー過剰傾向）。\n\n【臨床的注意】\n熱量に対して窒素源（アミノ酸）が相対的に不足している可能性があり、十分な同化・蛋白合成が得られないことがあります。';
      } else if (_npcNitrogenRatio < 120) {
        npcNColor = Colors.blue.shade700;
        npcNStatus = '不足 (青字)';
        npcDesc = 'NPC/N比が推奨下限（120）を下回っています（窒素源過剰傾向）。\n\n【臨床的注意】\nアミノ酸量に対してエネルギー（糖質・脂肪）が相対的に不足しており、アミノ酸が有効に利用されない可能性があります。';
      }
    }

    Color lipidColor = Colors.teal;
    String? lipidStatus;
    String? lipidDesc;
    if (_selectedItems.isNotEmpty && _totalLipid > 0) {
      if (_lipidEnergyRatio > 30) {
        lipidColor = Colors.red;
        lipidStatus = '過剰 (赤字)';
        lipidDesc = '脂質エネルギー比率が推奨上限（30%）を超えています。\n\n【臨床的注意】\n高脂血症、細網内皮系の機能低下、脂肪塞栓や肝障害のリスクに注意してください。';
      } else if (_lipidEnergyRatio < 20) {
        lipidColor = Colors.blue.shade700;
        lipidStatus = '不足 (青字)';
        lipidDesc = '脂質エネルギー比率が推奨下限（20%）を下回っています。\n\n【臨床的注意】\n必須脂肪酸（リノール酸・アラキドン酸等）の欠乏や、エネルギー補給における糖質偏重による高血糖リスクに注意してください。';
      }
    }

    Color naColor = Colors.teal;
    String? naStatus;
    String? naDesc;
    if (_selectedItems.isNotEmpty) {
      if (naPerKg > 2.0) {
        naColor = Colors.red;
        naStatus = '過剰 (赤字)';
        naDesc = 'ナトリウム投与量が推奨上限（2.0 mEq/kg）を超えています。\n\n【臨床的注意】\n塩分・水分の過剰貯留による高血圧、浮腫、心負荷の増加に注意してください。';
      } else if (naPerKg < 1.0) {
        naColor = Colors.blue.shade700;
        naStatus = '不足 (青字)';
        naDesc = 'ナトリウム投与量が推奨下限（1.0 mEq/kg）を下回っています。\n\n【臨床的注意】\n低ナトリウム血症、倦怠感、食欲低下、重篤な場合は意識障害等に注意してください。';
      }
    }

    Color kColor = Colors.teal;
    String? kStatus;
    String? kDesc;
    if (_selectedItems.isNotEmpty) {
      if (kPerKg > 1.0) {
        kColor = Colors.red;
        kStatus = '過剰 (赤字)';
        kDesc = 'カリウム投与量が推奨上限（1.0 mEq/kg）を超えています。\n\n【臨床的注意】\n高カリウム血症による不整脈や心停止のリスクに厳重な注意が必要です（特に腎機能低下例）。';
      } else if (kPerKg < 0.5) {
        kColor = Colors.blue.shade700;
        kStatus = '不足 (青字)';
        kDesc = 'カリウム投与量が推奨下限（0.5 mEq/kg）を下回っています。\n\n【臨床的注意】\n低カリウム血症による筋力低下、便秘、心電図変化（U波の出現等）や不整脈に注意してください。';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      color: Colors.teal.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('患者体重:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Row(
                  children: [
                    InkWell(
                      onTap: _showWeightInputDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Text(
                          '${_weight.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _weight += 1),
                          child: const Icon(Icons.arrow_drop_up, size: 18, color: Colors.teal),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            if (_weight > 1) _weight -= 1;
                          }),
                          child: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRowSummaryCard('水分量', '${_totalVolume.toStringAsFixed(0)}mL', '${volPerKg.toStringAsFixed(1)} /kg', volColor, volStatus != null ? () => _showExplanationDialog('水分量', volStatus!, volDesc!) : null),
                _buildRowSummaryCard('カロリー', '${_totalCalories.toStringAsFixed(0)}kcal', '${calPerKg.toStringAsFixed(1)} /kg', calColor, calStatus != null ? () => _showExplanationDialog('カロリー', calStatus!, calDesc!) : null),
                _buildRowSummaryCard('非蛋白熱量', '${_totalNpc.toStringAsFixed(0)}kcal', '${npcPerKg.toStringAsFixed(1)} /kg', npcColor, npcStatus != null ? () => _showExplanationDialog('非蛋白熱量 (NPC)', npcStatus!, npcDesc!) : null),
                _buildRowSummaryCard('NPC/N比', _npcNitrogenRatio > 0 ? _npcNitrogenRatio.toStringAsFixed(1) : '-', '', npcNColor, npcNStatus != null ? () => _showExplanationDialog('NPC/N比', npcNStatus!, npcNDesc!) : null),
                _buildRowSummaryCard('脂肪量', lipidStr, '', lipidColor, lipidStatus != null ? () => _showExplanationDialog('脂肪量', lipidStatus!, lipidDesc!) : null),
                _buildRowSummaryCard('Na', '${_totalNa.toStringAsFixed(1)}mEq', '${naPerKg.toStringAsFixed(2)} /kg', naColor, naStatus != null ? () => _showExplanationDialog('ナトリウム (Na)', naStatus!, naDesc!) : null),
                _buildRowSummaryCard('K', '${_totalK.toStringAsFixed(1)}mEq', '${kPerKg.toStringAsFixed(2)} /kg', kColor, kStatus != null ? () => _showExplanationDialog('カリウム (K)', kStatus!, kDesc!) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedListWindow() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '処方点滴リスト (計 ${_selectedItems.length} 本)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
          ),
          Expanded(
            child: _selectedItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '下の薬剤行をタップして点滴を追加してください',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _selectedListScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _selectedListScrollController,
                      itemCount: _selectedItems.length,
                      itemBuilder: (context, index) {
                        final item = _selectedItems[index];
                        final master = item.master;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          elevation: 1.0,
                          child: ListTile(
                            dense: true,
                            onTap: () => _removeItem(index),
                            leading: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                            title: Text(
                              master.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSelectionWindow() {
    final displayList = _sortedMasterList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.teal.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '薬剤マスター選択',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: _resetMasterList,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 12, color: Colors.red),
                          SizedBox(width: 2),
                          Text('初期化', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<MasterSortType>(
                        value: _currentSortType,
                        icon: const Icon(Icons.sort, size: 16, color: Colors.teal),
                        style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                        onChanged: (MasterSortType? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _currentSortType = newValue;
                            });
                          }
                        },
                        items: MasterSortType.values.map((MasterSortType type) {
                          return DropdownMenuItem<MasterSortType>(
                            value: type,
                            child: Text(type.label),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showAddCustomMasterDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.white),
                          SizedBox(width: 2),
                          Text('新規製剤', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _masterListScrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _masterListScrollController,
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final master = displayList[index];
                final count = _usageCounts[master.id] ?? 0;
                return InkWell(
                  onTap: () => _addSingleInfusion(master),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        master.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal, fontSize: 13),
                      ),
                      subtitle: Text(
                        '[${master.category}] ${master.volume}mL ${count > 0 ? "(使用回数: $count)" : ""}',
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal, size: 16),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            tooltip: 'この製剤を編集',
                            onPressed: () => _showAddCustomMasterDialog(editTarget: master),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.teal, size: 16),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            tooltip: 'この製剤をコピーして新規追加',
                            onPressed: () => _showAddCustomMasterDialog(copyFrom: master),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            tooltip: 'この製剤を削除',
                            onPressed: () => _deleteMasterItem(master),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- タップ可能なサマリー行ウィジェット ---
  Widget _buildRowSummaryCard(String label, String value1, String value2, Color textColor, VoidCallback? onTap) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: onTap != null ? textColor.withOpacity(0.5) : Colors.teal.shade100,
          width: onTap != null ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500)),
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.help_outline, size: 10, color: textColor),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value1,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor),
              ),
              if (value2.isNotEmpty)
                Text(
                  value2,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8)),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: cardContent,
      );
    }
    return cardContent;
  }
}