// ===============================
//        IMPORTS
// ===============================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path/path.dart' as path_package;
import 'package:intl/intl.dart';

// ===============================
//      CLASS LABELS LIST
// ===============================
const List<String> marineClasses = [
  "Coral Reefs",
  "Deep Sea",
  "Estuaries",
  "Hydrothermal Vents",
  "Kelp Forest",
  "Mangrove Forest",
  "Open Ocean",
  "Polar Seas",
  "Seagrass Beds",
  "Tide Pools",
];

// ===============================
//        MAIN ENTRY
// ===============================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marine Ecosystem',
      theme: ThemeData(
        primaryColor: Colors.brown,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: Color(0xFFFFF2CC), // light yellow
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFFF2CC),
        ),
        cardColor: Colors.white,
      ),
      home: const MyHomePage(),
    );
  }
}

// ===============================
//     DATABASE HELPER CLASS
// ===============================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static final ValueNotifier<int> scanNotifier = ValueNotifier<int>(0);

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scan_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = path_package.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        confidence REAL NOT NULL,
        image_path TEXT NOT NULL,
        date_time TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertScan(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = await db.insert('scan_history', row);
    scanNotifier.value = scanNotifier.value + 1;
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllScans() async {
    final db = await instance.database;
    return await db.query('scan_history', orderBy: 'id ASC');
  }
}

// ===============================
//           HOME PAGE
// ===============================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String label = "";
  double confidence = 0.0;

  @override
  void initState() {
    super.initState();
    _tfiteInit();
  }

  Future<void> _tfiteInit() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    );
  }

  Future<void> _saveToHistory() async {
    if (filePath != null && label.isNotEmpty) {
      await DatabaseHelper.instance.insertScan({
        'label': label,
        'confidence': confidence,
        'image_path': filePath!.path,
        'date_time': DateTime.now().toIso8601String(),
      });
    }
  }

  pickImageGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    await _processImage(File(image.path));
  }

  pickImageCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    await _processImage(File(image.path));
  }

  Future<void> _processImage(File imageFile) async {
    filePath = imageFile;
    setState(() {});
    var recognitions = await Tflite.runModelOnImage(
      path: imageFile.path,
      imageMean: 0.0,
      imageStd: 255.0,
      numResults: 2,
      threshold: 0.2,
      asynch: true,
    );
    if (recognitions == null || recognitions.isEmpty) return;
    setState(() {
      confidence = recognitions[0]['confidence'] * 100;
      label = recognitions[0]['label'];
    });
    await _saveToHistory();
  }

  void _navigateToHistory() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const HistoryPage()));
  }

  void _navigateToStats() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const StatisticsPage()));
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Drawer buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.brown),
            child: const Center(
              child: Text(
                "Marine Ecosystem",
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.brown),
            title: const Text("Home"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.brown),
            title: const Text("History"),
            onTap: _navigateToHistory,
          ),
          ListTile(
            leading: const Icon(Icons.show_chart, color: Colors.brown),
            title: const Text("Statistics"),
            onTap: _navigateToStats,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(title: const Text("Marine Ecosystem Scanner")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Card(
                elevation: 20,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        height: 280,
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/upload.jpg'),
                          ),
                        ),
                        child: filePath == null
                            ? const SizedBox.shrink()
                            : Image.file(filePath!, fit: BoxFit.fill),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Accuracy: ${confidence.toStringAsFixed(0)}%",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                onPressed: pickImageCamera,
                child: const Text("Take a Photo",
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                onPressed: pickImageGallery,
                child: const Text("Pick From Gallery",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================
//        HISTORY PAGE
// ===============================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];
  late VoidCallback _notifierListener;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _notifierListener = () {
      _loadHistory();
    };
    DatabaseHelper.scanNotifier.addListener(_notifierListener);
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.getAllScans();
    setState(() => _history = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan History")),
      body: ListView.builder(
        itemCount: marineClasses.length,
        itemBuilder: (context, index) {
          final className = marineClasses[index];
          final classHistory =
              _history.where((item) => item['label'] == className).toList();

          return ExpansionTile(
            leading: Image.asset(
              "assets/classes/$index.jpg",
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            title: Text(className),
            children: classHistory.isEmpty
                ? [const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("No scans recorded"),
                  )]
                : classHistory.map((item) {
                    final date = DateTime.parse(item['date_time']);
                    final formatted =
                        DateFormat('MMM dd, yyyy – hh:mm a').format(date);

                    return ListTile(
                      leading: Image.file(File(item['image_path']),
                          width: 50, height: 50, fit: BoxFit.cover),
                      title: Text(item['label']),
                      subtitle: Text(
                          "Accuracy: ${item['confidence'].toStringAsFixed(0)}%\n$formatted"),
                    );
                  }).toList(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    DatabaseHelper.scanNotifier.removeListener(_notifierListener);
    super.dispose();
  }
}

// ===============================
//      STATISTICS PAGE
// ===============================
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Map<String, dynamic>> _history = [];
  List<double> avgAccuracy = [];
  late VoidCallback _notifierListener;

  final List<Color> barColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    loadStats();
    _notifierListener = () {
      loadStats();
    };
    DatabaseHelper.scanNotifier.addListener(_notifierListener);
  }

  Future<void> loadStats() async {
    _history = await DatabaseHelper.instance.getAllScans();

    avgAccuracy = marineClasses.map((className) {
      final classHistory =
          _history.where((item) => item['label'] == className).toList();
      if (classHistory.isEmpty) return 0.0;
      return classHistory
              .map((e) => e['confidence'] as double)
              .reduce((a, b) => a + b) /
          classHistory.length;
    }).toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Statistics")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                "Average Accuracy per Class (Colorful Bar Graph with %)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 350,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    gridData: FlGridData(show: true, drawHorizontalLine: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= marineClasses.length) {
                              return const SizedBox();
                            }
                            return RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                marineClasses[index].split(' ').first,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: avgAccuracy.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            color: barColors[e.key % barColors.length],
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 100,
                              color: Colors.grey.shade200,
                            ),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.black87,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            "${avgAccuracy[groupIndex].toStringAsFixed(1)}%",
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: avgAccuracy.asMap().entries.map((e) {
                  final idx = e.key;
                  final value = e.value;
                  final label = marineClasses[idx];
                  return Chip(
                    backgroundColor: barColors[idx % barColors.length].withOpacity(0.14),
                    label: Text(
                      '$label: ${value.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Color(0xFF004D40)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    DatabaseHelper.scanNotifier.removeListener(_notifierListener);
    super.dispose();
  }
}
