import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:IngredEye/global.dart';
import 'package:IngredEye/screen_ingredient.dart';

class ScreenDetected extends StatefulWidget {
  final List<String> ingredientszz;

  const ScreenDetected({super.key, required this.ingredientszz});

  @override
  State<ScreenDetected> createState() => _ScreenDetectedState();
}

class _ScreenDetectedState extends State<ScreenDetected> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late Interpreter _interpreter;
  List<int> _prediction = [];
  List<double> encodedList = [];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      print('Loading TensorFlow Lite model...');
      _interpreter = await Interpreter.fromAsset('assets/k.tflite');
      print('TensorFlow Lite model loaded successfully.');
      var inputShape = _interpreter.getInputTensor(0).shape;
      var outputShape = _interpreter.getOutputTensor(0).shape;
      print('Input shape: ${inputShape.toString()}');
      print('Output shape: ${outputShape.toString()}');


      List<String> allIngredients = [
        'onion',
        'garlic',
        'tomato',
        'chicken',
        'rice',
        'potato',
        'beef',
        'pasta',
        'fish',
        'lettuce',
        'mushroom',
        'lentils',
        'flour',
        'cheese',
        'shrimp',
        'beans',
        'egg',
        'bread',
        'honey',
        'carrot',
        'ginger',
        'cabbage'
      ];

      encodedList = encodeIngredients(allIngredients, widget.ingredientszz);

      print(encodedList);
      predictDish(encodedList);
    } catch (e) {
      print('Failed to load TensorFlow Lite model: $e');
      // Handle error, e.g., show a message to the user
    }
  }

  List<double> encodeIngredients(
      List<String> allIngredients, List<String> inputIngredients) {
    print(inputIngredients);
    return allIngredients
        .map((ingredient) => inputIngredients.contains(ingredient) ? 1.0 : 0.0)
        .toList();
  }

  Future predictDish(List<double> ingredients) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded yet. Call _loadModel() first.');
    }

    try {
      var input = [ingredients];
      var output = List.filled(43, 0.0).reshape([1, 43]);

      _interpreter.run(input, output);

      List<double> outputBuffer = output[0];
      print("outputBuffer: $outputBuffer");
      print("outputBuffer Length: ${outputBuffer.length}");

      List<int> indices = findTopNIndices4(outputBuffer, 2);
      print("indices $indices");

      setState(() {
        _prediction = indices;
      });
      print("predictions $_prediction");
    } catch (e) {
      print('Error during prediction: $e');
      throw Exception('Prediction failed.');
    }
  }

  List<int> findTopNIndices4(List<double> values, int n) {
    List<double> truncatedValues =
        values.map((value) => (value * 10000).round() / 10000).toList();
    print(truncatedValues);

    List<int> indices =
        List<int>.generate(truncatedValues.length, (index) => index + 1);
    print("indices: $indices");
  
    indices.sort(
        (a, b) => truncatedValues[b - 1].compareTo(truncatedValues[a - 1]));
    print("Sorted indices: $indices");

    return indices.take(n).toList();
  }

  List<int> findTopNIndices3(List<double> values, int n) {
    // Truncate values to 4 decimal places
    List<double> truncatedValues =
        values.map((value) => (value * 10000).round() / 10000).toList();
    print(truncatedValues);

    // Create a list of indices
    List<int> indices =
        List<int>.generate(truncatedValues.length, (index) => index);
    print("indices: $indices");
    print("indices Length ${indices.length}");

    // Sort indices based on the truncated values in descending order
    indices.sort((a, b) => truncatedValues[b].compareTo(truncatedValues[a]));
    print("Sorted indices: $indices");
    print("indices Length ${indices.length}");

    // Get the top n indices
    return indices.take(n).toList();
  }

  List<int> getTopNIndices1(List<double> list, int n) {
    List<MapEntry<int, double>> indexedList = list.asMap().entries.toList();

    indexedList.sort((a, b) => b.value.compareTo(a.value));

    return indexedList.sublist(0, n).map((e) => e.key).toList();
  }

  List<int> getTopNIndices2(var values, int n) {
    // Create a list of index-value pairs
    List<MapEntry<int, double>> indexedValues = values.asMap().entries.toList();
    print("indexedValues : $indexedValues");

    // Sort the list based on the values in descending order
    indexedValues.sort((a, b) => b.value.compareTo(a.value));
    print("indexedValues : $indexedValues");

    // Take the top 'n' indices
    return indexedValues.take(n).map((entry) => entry.key).toList();
  }

  List<int> getTopNIndices(List<double> values, int n) {
    List<int> indices = List<int>.generate(values.length, (i) => i);
    indices.sort((a, b) => values[b].compareTo(values[a]));
    return indices.sublist(0, n);
  }

  List<int> findHighestIndices(List<double> values, int topN) {
    List<MapEntry<int, double>> indexedValues = values.asMap().entries.toList();
    indexedValues.sort((a, b) => b.value.compareTo(a.value));
    List<int> topIndices =
        indexedValues.take(topN).map((entry) => entry.key).toList();
    return topIndices;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all(
                const Color.fromARGB(255, 221, 102, 100)),
          ),
        ),
        title: const Text("Recommended Dishes"),
        actions: [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder(
          stream: firestore.collection('Dish').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              var appointments = snapshot.data!.docs;
              var filteredAppointments = appointments.where((doc) {
                var indexString = doc.data()['index'];
                var index = int.tryParse(indexString);
                print("Document Index: $index");
                return index != null && _prediction.contains(index);
              }).toList();
              print(_prediction);
              print("filteredAppointments");
              print(filteredAppointments);
              return ListView.builder(
                  itemCount: filteredAppointments.length,
                  itemBuilder: (context, index) {
                    var data = filteredAppointments[index].data();
                    print("data");
                    print(data);
                    return ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name']),
                                Text(
                                  data['ingredients'],
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                slideTransition(ScreenIngredients(
                                  dishData: data,
                                )));
                          },
                          child: Text("Prepare")),
                    );

                  });
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildCard(String title, String time, String offer, Color bgColor,
      BuildContext context, var data) {
    return Container(
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              slideTransition(ScreenIngredients(
                dishData: data,
              )));
        },
        child: Card(
          color: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(time, style: const TextStyle(color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(offer, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
