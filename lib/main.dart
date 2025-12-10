import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart'; // Required for Zipping
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p; // Required for filename handling
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Required for Exporting
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const TalkBuilderApp());
}

class TalkBuilderApp extends StatelessWidget {
  const TalkBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF80CBC4)),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
      ),
      home: const BuilderScreen(),
    );
  }
}

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> customCards = [];
  List<Map<String, dynamic>> sentenceStrip = [];

  bool isAdminMode = false;

  final List<Map<String, dynamic>> coreWords = [
    {"id": "c_i", "label": "I", "color": 0xFFFFF59D, "icon": "🙂"},
    {"id": "c_want", "label": "Want", "color": 0xFFA5D6A7, "icon": "🤲"},
    {"id": "c_see", "label": "See", "color": 0xFFA5D6A7, "icon": "👀"},
    {"id": "c_go", "label": "Go", "color": 0xFFA5D6A7, "icon": "🏃"},
    {"id": "c_like", "label": "Like", "color": 0xFFA5D6A7, "icon": "❤️"},
    {"id": "c_more", "label": "More", "color": 0xFFFFF59D, "icon": "➕"},
    {"id": "c_no", "label": "No", "color": 0xFFEF9A9A, "icon": "👎"},
    {"id": "c_yes", "label": "Yes", "color": 0xFFC5E1A5, "icon": "👍"},
  ];

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadCustomCards();
  }

  void _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
  }

  // --- DATA MANAGEMENT ---

  Future<void> _loadCustomCards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('toddler_cards');
    if (storedData != null) {
      setState(() {
        customCards = List<Map<String, dynamic>>.from(json.decode(storedData));
      });
    }
  }

  Future<void> _saveCustomCards() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('toddler_cards', json.encode(customCards));
  }

  // --- BACKUP LOGIC (Restored) ---

  Future<void> _backupData() async {
    if (customCards.isEmpty) {
      _speak("Nothing to backup");
      return;
    }

    try {
      final archive = Archive();
      final appDir = await getApplicationDocumentsDirectory();
      List<Map<String, dynamic>> portableList = [];

      for (var card in customCards) {
        final File imageFile = File(card['imagePath']);
        final String filename = p.basename(card['imagePath']);

        if (await imageFile.exists()) {
          final List<int> bytes = await imageFile.readAsBytes();
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));

          Map<String, dynamic> portableCard = Map.from(card);
          portableCard['imagePath'] = filename;
          portableList.add(portableCard);
        }
      }

      final String jsonStr = jsonEncode(portableList);
      archive.addFile(
        ArchiveFile('data.json', jsonStr.length, utf8.encode(jsonStr)),
      );

      final ZipEncoder encoder = ZipEncoder();
      final File zipFile = File('${appDir.path}/talk_builder_backup.zip');

      await zipFile.writeAsBytes(encoder.encode(archive));

      // Share using SharePlus
      await SharePlus.instance.share(
        ShareParams(text: 'Talk Builder Backup', files: [XFile(zipFile.path)]),
      );
    } catch (e) {
      _speak("Backup failed");
      debugPrint("Backup Error: $e");
    }
  }

  Future<void> _restoreData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return;

      final File zipFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<Map<String, dynamic>> importedCards = [];

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          if (file.name == 'data.json') {
            String jsonStr = utf8.decode(data);
            List<dynamic> jsonList = jsonDecode(jsonStr);
            importedCards = List<Map<String, dynamic>>.from(jsonList);
          } else {
            File outFile = File('${appDir.path}/${file.name}');
            if (!await outFile.exists()) {
              await outFile.create(recursive: true);
              await outFile.writeAsBytes(data);
            }
          }
        }
      }

      for (var card in importedCards) {
        card['imagePath'] = '${appDir.path}/${card['imagePath']}';
      }

      int addedCount = 0;
      setState(() {
        for (var newCard in importedCards) {
          final bool exists = customCards.any((c) => c['id'] == newCard['id']);
          if (!exists) {
            customCards.add(newCard);
            addedCount++;
          }
        }
      });

      _saveCustomCards();
      _speak("Merged $addedCount items");
    } catch (e) {
      _speak("Restore failed");
      debugPrint("Error: $e");
    }
  }

  // --- SENTENCE STRIP LOGIC ---

  void _addToSentence(Map<String, dynamic> card) {
    _speak(card['label']);
    setState(() {
      sentenceStrip.add(card);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _playSentence() {
    if (sentenceStrip.isEmpty) return;
    String sentence = sentenceStrip.map((e) => e['label']).join(" ");
    _speak(sentence);
  }

  void _backspace() {
    if (sentenceStrip.isNotEmpty) {
      setState(() {
        sentenceStrip.removeLast();
      });
    }
  }

  void _clearSentence() {
    setState(() {
      sentenceStrip.clear();
    });
  }

  // --- ADMIN & ACTIONS ---

  Future<void> _addNewCard() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (photo == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/${const Uuid().v4()}.jpg';
    await photo.saveTo(path);

    if (!mounted) return;
    String? label = await _showLabelDialog();
    if (label == null || label.isEmpty) return;

    setState(() {
      customCards.add({
        "id": const Uuid().v4(),
        "label": label,
        "imagePath": path,
        "isCustom": true,
        "isVisible": true,
      });
    });
    _saveCustomCards();
  }

  Future<void> _deleteCard(int index) async {
    setState(() => customCards.removeAt(index));
    _saveCustomCards();
  }

  void _toggleVisibility(int index) {
    setState(() {
      bool current = customCards[index]['isVisible'] ?? true;
      customCards[index]['isVisible'] = !current;
    });
    _saveCustomCards();
  }

  Future<String?> _showLabelDialog() {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Card Label"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _speak(String text) {
    flutterTts.speak(text);
  }

  // --- UI CONSTRUCTION ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth > 600;
        final int gridColumns = isTablet ? 4 : 3;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: isAdminMode
                ? const Text("Admin Mode", style: TextStyle(color: Colors.red))
                : const Text("Talk Builder"),
            actions: [
              if (isAdminMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') _restoreData();
                    if (value == 'backup') _backupData(); // UNCOMMENTED
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                        value: 'backup',
                        child: Text('Backup Data'), // UNCOMMENTED
                      ),
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore/Import Data'),
                      ),
                    ];
                  },
                  icon: const Icon(Icons.settings, color: Colors.black),
                ),
              GestureDetector(
                onLongPress: () {
                  setState(() => isAdminMode = !isAdminMode);
                  _speak(isAdminMode ? "Editing On" : "Locked");
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(
                    isAdminMode ? Icons.lock_open : Icons.lock,
                    color: isAdminMode ? Colors.red : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. SENTENCE STRIP AREA
              Container(
                height: 140,
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: sentenceStrip.isEmpty
                            ? const Center(
                                child: Text(
                                  "Tap words to build a sentence",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                itemCount: sentenceStrip.length,
                                itemBuilder: (context, index) {
                                  final card = sentenceStrip[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _buildMiniCard(card),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _clearSentence,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            "Clear",
                            style: TextStyle(color: Colors.red),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _playSentence,
                          icon: const Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "SPEAK",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _backspace,
                          icon: const Icon(Icons.backspace, color: Colors.grey),
                          iconSize: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 2. VOCABULARY GRID
              Expanded(
                child: GridView(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  children: [
                    ...coreWords.map((word) => _buildGridCard(word)),
                    ...customCards
                        .asMap()
                        .entries
                        .where(
                          (e) => isAdminMode || (e.value['isVisible'] ?? true),
                        )
                        .map((e) => _buildCustomGridCard(e.value, e.key)),
                    if (isAdminMode) _buildAddButton(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildMiniCard(Map<String, dynamic> data) {
    // Small version of card for the sentence strip
    final bool isCustom =
        data.containsKey('isCustom') && data['isCustom'] == true;
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: isCustom ? Colors.white : Color(data['color']),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCustom)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Image.file(
                  File(data['imagePath']),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            )
          else
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(data['icon'], style: const TextStyle(fontSize: 30)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              data['label'],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => _addToSentence(data),
      child: Container(
        decoration: BoxDecoration(
          color: Color(data['color']),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(data['icon'], style: const TextStyle(fontSize: 40)),
            Text(
              data['label'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomGridCard(Map<String, dynamic> data, int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _addToSentence(data),
          child: Container(
            foregroundDecoration: (isAdminMode && !(data['isVisible'] ?? true))
                ? BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade100, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(data['imagePath']), fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white.withAlpha(200),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        data['label'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isAdminMode) ...[
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _deleteCard(index),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _toggleVisibility(index),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: (data['isVisible'] ?? true)
                    ? Colors.blue
                    : Colors.grey,
                child: Icon(
                  (data['isVisible'] ?? true)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addNewCard,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400, width: 2),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
        ),
      ),
    );
  }
}
