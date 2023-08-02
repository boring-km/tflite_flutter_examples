import 'dart:ffi';

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tflite_flutter_examples/drawing_painter.dart';
import 'dart:ui' as ui;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _globalKey = GlobalKey();
  List<Offset?> _points = [];

  final outputs = [Float64List(10)];

  String resultValue = '';

  void _onPanUpdate(DragUpdateDetails details) {
    RenderBox? renderBox =
        _globalKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    Offset localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _points = List.from(_points)..add(localPosition);
    });
  }

  void _extractImage() async {
    final boundary =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    ui.Image image = await boundary.toImage();

    final shape = interpreter.getInputTensor(0).shape;
    final width = shape[1];
    final height = shape[2];

    // image encode
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final imageBytes = pngBytes?.buffer.asUint8List();
    if (imageBytes == null) return;
    // resize image by width and height
    final resizedImage = await resizeImage(imageBytes, width, height);
    if (resizedImage == null) return;


    classify(resizedImage);
  }
  Future<ByteBuffer?> resizeImage(Uint8List imageData, int width, int height) async {
    ui.Image image = await decodeImageFromList(imageData);
    ui.Image resizedImage = (await (await ui.instantiateImageCodec(
      Uint8List.fromList(imageData),
      targetWidth: width,
      targetHeight: height,
    )).getNextFrame()).image;
    final resizedByteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    return resizedByteData?.buffer;
  }

  void classify(ByteBuffer pngBytes) {
    interpreter.runInference(pngBytes.asUint8List());
    final output = interpreter.getOutputTensors();
    final result = outputs[0];
    final maxValue = result.reduce((curr, next) => curr > next ? curr : next);
    setState(() {
      resultValue = '$maxValue';
    });
  }

  late tfl.Interpreter interpreter;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      interpreter = await tfl.Interpreter.fromAsset('assets/mnist.tflite');
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _globalKey,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: (_) => _points.add(null),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  child: CustomPaint(
                    painter: MyCustomPainter()..points = _points,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(resultValue),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _extractImage,
              child: const Text('Extract Image'),
            ),
          ],
        ),
      ),
    );
  }
}
