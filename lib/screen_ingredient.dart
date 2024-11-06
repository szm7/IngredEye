import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:IngredEye/database/db.dart';
import 'package:IngredEye/global.dart';

class ScreenIngredients extends StatefulWidget {
  const ScreenIngredients({required this.dishData, super.key});

  final Map<String, dynamic> dishData;

  @override
  State<ScreenIngredients> createState() => _ScreenIngredientsState();
}

class _ScreenIngredientsState extends State<ScreenIngredients> {
  String imageUrl = '';
  Reference get firebaseStorage => FirebaseStorage.instance.ref();

  @override
  void initState() {
    super.initState();
    loadImage(widget.dishData['image']);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    List<String> instructionList = widget.dishData['instruction'].split(';');
    return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all(
                  const Color.fromARGB(255, 221, 102, 100)),
            ),
          ),
          title: const Text("Instructions"),
          actions: [],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.end,
                runAlignment: WrapAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  _buildCard(
                      widget.dishData['name'].toString(),
                      widget.dishData['ingredients'].toString(),
                      "",
                      imageUrl,
                      "assets/icons/${widget.dishData['type'].toString().toLowerCase()}.png",
                      Colors.white,
                      context,
                      size),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: instructionList.map((instruction) {
                      return Container(
                        width: size.width,
                        child: Card(
                          color: Colors.white,
                          child: ListTile(
                            title: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Step ${instructionList.indexOf(instruction) + 1} : ",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Expanded(
                                    child: Text(
                                      instruction,
                                      style: const TextStyle(fontSize: 16),
                                      maxLines: null,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
          ),
        ));
  }

  Future<String> loadImage(String imgName) async {
    try {
      var image = firebaseStorage.child("Dish").child(imgName);
      print(image);
      var url = await image.getDownloadURL();
      print(url);
      setState(() {
        imageUrl = url;
      });
    } catch (e) {
      print('Failed to load image: $e');
    }
    return "";
  }

  Widget _buildCard(String title, String time, String offer, String imagePath,
      String iconPath, Color bgColor, BuildContext context, Size size) {
    return Container(
      width: size.width,
      child: Card(
        color: bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.network(imagePath,
                    fit: BoxFit.fill, height: 250, width: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  const Spacer(),
                  Image.asset(
                    iconPath,
                    fit: BoxFit.fill,
                    height: 15,
                    width: 15,
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(time,
                  style: const TextStyle(color: Colors.black, fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.fireplace_rounded,
                    color: Colors.red,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Text("200"),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.sports_gymnastics,
                      color: Colors.yellow[600],
                    ),
                  ),
                  const Text("200"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(offer, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
