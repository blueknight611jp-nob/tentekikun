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
  frequentOrder('よく使う順'); // ← 追加

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
  MasterSortType _currentSortType = MasterSortType.frequentOrder; // 初期値を「よく使う順」にすると便利です

  List<InfusionMaster> _masterList = [];
  final List<SelectedInfusionItem> _selectedItems = [];
  Map<String, int> _usageCounts = {}; // ← 使用回数保存用マップ

  @override
  void initState() {
    super.initState();
    _loadUsageCounts().then((_) {
      _loadMasterList();
    });
  }

  // 使用回数のロード
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

  // 使用回数のセーブ
  Future<void> _saveUsageCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('master_usage_counts', jsonEncode(_usageCounts));
  }

  // ローカルストレージまたはアセットからマスターリストを読み込み
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

  // アセットから初期マスターを読み込み
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

  // ローカルストレージへ保存
  Future<void> _saveMasterList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _masterList.map((m) => m.toJson()).toList();
    await prefs.setString('custom_master_list', jsonEncode(jsonList));
  }

  // 初期状態へリセット
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
                await prefs.remove('master_usage_counts'); // 使用回数もリセット
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
      case MasterSortType.frequentOrder: // ← よく使う順のソートロジック
        list.sort((a, b) {
          final countA = _usageCounts[a.id] ?? 0;
          final countB = _usageCounts[b.id] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA); // 使用回数が多いものを上へ
          }
          // 回数が同じ場合は追加が新しいものを上へ
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
      // カウントをインクリメントして保存
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

    Color volColor = Colors.teal;
    if (_selectedItems.isNotEmpty) {
      if (volPerKg > 35) volColor = Colors.red;
      else if (volPerKg < 25) volColor = Colors.blue.shade700;
    }

    Color calColor = Colors.teal;
    if (_selectedItems.isNotEmpty) {
      if (calPerKg > 30) calColor = Colors.red;
      else if (calPerKg < 20) calColor = Colors.blue.shade700;
    }

    Color npcColor = Colors.teal;
    if (_selectedItems.isNotEmpty) {
      if (npcPerKg > 25) npcColor = Colors.red;
      else if (npcPerKg < 15) npcColor = Colors.blue.shade700;
    }

    Color npcNColor = Colors.teal;
    if (_selectedItems.isNotEmpty && _totalNitrogen > 0) {
      if (_npcNitrogenRatio > 175) npcNColor = Colors.red;
      else if (_npcNitrogenRatio < 120) npcNColor = Colors.blue.shade700;
    }

    Color lipidColor = Colors.teal;
    if (_selectedItems.isNotEmpty && _totalLipid > 0) {
      if (_lipidEnergyRatio > 30) lipidColor = Colors.red;
      else if (_lipidEnergyRatio < 20) lipidColor = Colors.blue.shade700;
    }

    Color naColor = Colors.teal;
    if (_selectedItems.isNotEmpty) {
      if (naPerKg > 2.0) naColor = Colors.red;
      else if (naPerKg < 1.0) naColor = Colors.blue.shade700;
    }

    Color kColor = Colors.teal;
    if (_selectedItems.isNotEmpty) {
      if (kPerKg > 1.0) kColor = Colors.red;
      else if (kPerKg < 0.5) kColor = Colors.blue.shade700;
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
                _buildRowSummaryCard('水分量', '${_totalVolume.toStringAsFixed(0)}mL', '${volPerKg.toStringAsFixed(1)} /kg', volColor),
                _buildRowSummaryCard('カロリー', '${_totalCalories.toStringAsFixed(0)}kcal', '${calPerKg.toStringAsFixed(1)} /kg', calColor),
                _buildRowSummaryCard('非蛋白熱量', '${_totalNpc.toStringAsFixed(0)}kcal', '${npcPerKg.toStringAsFixed(1)} /kg', npcColor),
                _buildRowSummaryCard('NPC/N比', _npcNitrogenRatio > 0 ? _npcNitrogenRatio.toStringAsFixed(1) : '-', '', npcNColor),
                _buildRowSummaryCard('脂肪量', lipidStr, '', lipidColor),
                _buildRowSummaryCard('Na', '${_totalNa.toStringAsFixed(1)}mEq', '${naPerKg.toStringAsFixed(2)} /kg', naColor),
                _buildRowSummaryCard('K', '${_totalK.toStringAsFixed(1)}mEq', '${kPerKg.toStringAsFixed(2)} /kg', kColor),
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
                final count = _usageCounts[master.id] ?? 0; // 使用回数を表示に絡めることも可能
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

  Widget _buildRowSummaryCard(String label, String value1, String value2, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500)),
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
  }
}