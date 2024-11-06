import 'dart:io';
import 'dart:math';
import 'dart:io' as io;
import 'package:animated_icon/animate_icon.dart';
import 'package:animated_icon/animate_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:image_picker/image_picker.dart';
import 'package:IngredEye/global.dart';
import 'package:IngredEye/screen_detected.dart';
import 'package:IngredEye/screen_ingredient.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:ultralytics_yolo/predict/detect/object_detector.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Reference get firebaseStorage => FirebaseStorage.instance.ref();

  late List<Map<String, dynamic>> yoloResults;
  List imageUrls = [];

  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  late ObjectDetector objectDetector;
  bool isModelLoaded = false;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    loadImages();
    _initializeObjectDetector();
    _initSpeech();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() async {
    _searchController.dispose();
    super.dispose();
  }

  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  /// Initialize the speech recognition
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Start listening for voice input
  void _startListening() async {
    print("_startListening");
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Stop listening
  void _stopListening() async {
    print("_stopListening");
    await _speechToText.stop();
    setState(() {});
  }

  /// Handle the speech recognition result
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      print("_lastWords");
      print(_lastWords);
      _searchController.text = _lastWords;
    });
  }

  Future<void> _pickImage(ImageSource source, BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);

        // Clear previous results when picking a new image
      });
      await _detectObjects(_imageFile!.path, context);
    }
  }

  Future<void> loadImages() async {
    QuerySnapshot snapshot = await firestore.collection('Dish').get();
    List<Future<String>> futures = [];

    for (var doc in snapshot.docs) {
      String imgName = doc['image'].toString();
      futures.add(loadImage(imgName));
    }
    print("FUTURES : $futures");
    List<String> urls = await Future.wait(futures);
    print("URLS : $urls");
    setState(() {
      imageUrls = urls;
    });
    print("IMAGE URLS : $imageUrls");
  }

  Future<String> loadImage(String imgName) async {
    try {
      var imageRef = firebaseStorage.child("Dish").child(imgName);
      var url = await imageRef.getDownloadURL();
      return url;
    } catch (e) {
      print('Failed to load image: $e');
      return ''; // Handle error as needed
    }
  }

  @override
  Widget build(BuildContext context1) {
    final Size size = MediaQuery.of(context1).size;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search a dish...',
            prefixIcon: Icon(
              Icons.search,
              color: Color.fromARGB(255, 221, 102, 100),
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: _speechToText.isListening
                ? const Icon(
                    Icons.mic,
                    color: const Color.fromARGB(255, 221, 102, 100),
                  )
                : const Icon(
                    Icons.mic_off,
                    color: Color.fromARGB(255, 141, 134, 134),
                  ),
            onPressed: () async {
              if (!_speechToText.isListening) {
                _startListening();
              } else {
                _stopListening();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                          ),
                          children: [
                            const TextSpan(
                                text: 'Capture Image or Upload from Gallery ',
                                style: TextStyle(color: Colors.black)),
                            WidgetSpan(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Image.asset(
                                  'assets/sparkling.png', // Replace with the path to your logo
                                  height: 20, // Adjust the size as needed
                                  alignment: Alignment.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 3,
                      ),
                    )

              
                    ,
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        _pickImage(ImageSource.camera, context1);
                      },
                      icon: const Icon(Icons.camera_alt_sharp),
                      color: const Color.fromARGB(255, 221, 102, 100),
                    ),
                    IconButton(
                      onPressed: () {
                        _pickImage(ImageSource.gallery, context1);
                      },
                      icon: const Icon(Icons.photo),
                      color: const Color.fromARGB(255, 221, 102, 100),
                    ),
                    IconButton(
                      onPressed: () {
                        List<String> empty = [" "];

                        showIngredientsDialog(context1, empty, "true");
                      },
                      icon: const Icon(Icons.edit),
                      color: const Color.fromARGB(255, 221, 102, 100),
                    ),
                  ],
                ),
              ),
              const Divider(),
              StreamBuilder(
                stream:
                    FirebaseFirestore.instance.collection('Dish').snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                
                  if (snapshot.hasData) {
                    var appointments = snapshot.data!.docs;
                    var filteredAppointments = appointments.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;

                      // Convert searchQuery to lowercase for case-insensitive search
                      var lowerCaseQuery = searchQuery.toLowerCase();

                      // Check if searchQuery is present in any relevant fields
                      var dishName = data['name'].toString().toLowerCase();
                      var ingredients =
                          data['ingredients'].toString().toLowerCase();
                      var dishType = data['type'].toString().toLowerCase();
                      var dishIndex = data['index'].toString().toLowerCase();

                      return dishName.contains(lowerCaseQuery) ||
                          ingredients.contains(lowerCaseQuery) ||
                          dishType.contains(lowerCaseQuery) ||
                          dishIndex.contains(lowerCaseQuery);
                    }).toList();

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3 / 4, // Number of items per row
                      ),
                      itemCount: filteredAppointments.length,
                      itemBuilder: (context, index) {
                        var data = filteredAppointments[index].data()
                            as Map<String, dynamic>;
                        print(data);

                        return Padding(
                          padding: const EdgeInsets.only(left: 8, right: 8),
                          child: _buildCard(
                            data['name'].toString(),
                            data['ingredients'].toString(),
                            imageUrls[index],
                            "assets/icons/${data['type'].toString().toLowerCase()}.png",
                            Colors.white,
                            context,
                            size,
                            data,
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),

          
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeObjectDetector() async {
    objectDetector = await _initObjectDetectorWithLocalModel();
    await objectDetector.loadModel();
    setState(() {
      isModelLoaded = true;
      print(isModelLoaded);
    });
  }

  Future<ObjectDetector> _initObjectDetectorWithLocalModel() async {
    final modelPath = await _copy('assets/final.tflite');
    final metadataPath = await _copy('assets/metadatafinal.yaml');
    final model = LocalYoloModel(
      id: '',
      task: TaskName.detect,
      format: Format.tflite,
      modelPath: modelPath,
      metadataPath: metadataPath,
    );

    return ObjectDetector(model: model);
  }

  Future<String> _copy(String assetPath) async {
    final path =
        '${(await getApplicationSupportDirectory()).path}/${basename(assetPath)}';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<void> _detectObjects(String imagePath, BuildContext context) async {
    if (isModelLoaded) {
      // Await the detection result
      objectDetector.setConfidenceThreshold(0.1);
      objectDetector.setIouThreshold(0.5);
      objectDetector.setNumItemsThreshold(20);
      var results = await objectDetector.detect(imagePath: imagePath);
      List<String> labels = [];

      for (var result in results!) {
        if (!labels.contains(result!.label)) {
          labels.add(result.label);
          print("${result.label} ${result.confidence}");
        }
      }
      showIngredientsDialog(context, labels, "");
    }
  }



  Widget _buildCard(
      String title,
      String time,
      String imagePath,
      String iconPath,
      Color bgColor,
      BuildContext context,
      Size size,
      var data) {
    return Container(
      height: size.height * 0.6,
      child: InkWell(
        onTap: () {
          Navigator.push(
              context, slideTransition(ScreenIngredients(dishData: data)));
        },
        child: Card(
          color: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      10.0), // Adjust the radius as needed
                  child: Image.network(
                    imagePath,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      // You can customize the loading indicator here
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // You can customize the error widget here
                      return const Center(child: Text('Image load failed'));
                    }, // Adjust this as needed
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: null,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    const Spacer(),
                    Image.asset(
                      iconPath,
                      fit: BoxFit.fill,
                      height: 10,
                      width: 10,
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(time, style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showIngredientsDialog(
      BuildContext context, List<String> ingredients, String value) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        print("ingredient: $ingredients");
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingredients Detected'),
          
            ],
          ),
          content: IngredientsDialogContent(
            value: value,
            ingredients: ingredients,
            onConfirm: (List<String> updatedIngredients) {
    
              print(updatedIngredients);
              Navigator.push(
                  context,
                  slideTransition(
                      ScreenDetected(ingredientszz: updatedIngredients)));
            },
          ),
          actions: <Widget>[],
        );
      },
    );
  }
}

class IngredientsDialogContent extends StatefulWidget {
  final List<String> ingredients;
  final Function(List<String>) onConfirm;
  String value;

  IngredientsDialogContent(
      {required this.ingredients,
      required this.onConfirm,
      required this.value});

  @override
  _IngredientsDialogContentState createState() =>
      _IngredientsDialogContentState();
}

class _IngredientsDialogContentState extends State<IngredientsDialogContent> {
  List<TextEditingController> _controllers = [];

  bool isEdit = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      if (widget.value == "true") {
        isEdit = true;
      } else {
        isEdit = false;
      }
    });
    widget.ingredients.forEach((ingredient) {
      _controllers.add(TextEditingController(text: ingredient));
    });
  }

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  List<String> _getIngredients() {
    return _controllers.map((controller) => controller.text).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: !isEdit
          ? Column(
              children: [
                ..._controllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(entry.value.text),
                      ],
                    ),
                  );
                }).toList(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEdit = !isEdit;
                        });
                      },
                      child: const Text('Edit'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          List<String> ingredients = _getIngredients();
                          print("onConfirm:$ingredients");
                          widget.onConfirm(ingredients);
                        },
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ..._controllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              border: const UnderlineInputBorder(),
                              labelText: 'Ingredient ${index + 1}',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _removeIngredient(index);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16.0),
                IconButton(
                    onPressed: _addIngredient, icon: const Icon(Icons.add)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        List<String> ingredients = _getIngredients();
                        widget.onConfirm(ingredients);
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
