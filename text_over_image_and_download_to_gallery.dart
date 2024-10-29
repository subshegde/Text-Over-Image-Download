import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

  // permission_handler: ^8.1.0+2
  // image_picker: ^1.1.2
  // image_gallery_saver: ^2.0.3
  //  geocoding: ^2.0.0
  // geolocator: ^7.1.0

class ImageWithTextOverlay extends StatefulWidget {
  @override
  _ImageWithTextOverlayState createState() => _ImageWithTextOverlayState();
}

class _ImageWithTextOverlayState extends State<ImageWithTextOverlay> {
  final GlobalKey _globalKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile ;


  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.storage,
    ].request();
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();

  }

  String address = '';
  double latitude = 0.0;
  double longitude = 0.0;
  String date = '';
  String time = '';

Future<void> _pickImageFromCamera() async {
  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  if (image != null) {
    // Get current location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    latitude = position.latitude;
    longitude = position.longitude;

    address = await getAddressFromCoordinates(position);

    safeSetState(() {
      _imageFile = image;

      DateTime now = DateTime.now();
      String timestamp = now.toLocal().toString();
      date = "${now.year}-${now.month}-${now.day}";
      time = "${now.hour}:${now.minute}:${now.second}";

    });
  }
}

  Future<String> getAddressFromCoordinates(_position) async {
    if (_position == null) return '';
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _position!.latitude, _position!.longitude);
      if (placemarks != null && placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        return '${placemark.street}, ${placemark.locality},${placemark.administrativeArea}, ${placemark.country}';
      } else {
        return '';
      }
    } catch (e) {
      print('Error fetching address: $e');
      return '';
    }
  }


  Future<void> _saveLocalImage() async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final result = await ImageGallerySaver.saveImage(
          byteData.buffer.asUint8List(),
          quality: 100,
          name: "image_with_text_overlay",
        );

        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image saved successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save image.")),
          );
        }
      }
    } catch (e) {
      print("Error saving image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving image.")),
      );
    }
  }

  void safeSetState(VoidCallback fn){
    if (!mounted) return;
    setState(fn);
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Camera Image with Text Overlay')),
    body: Center(
      child: _imageFile != null
          ? RepaintBoundary(
              key: _globalKey,
              child: Stack(
                
                children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 10, 
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        'Time: $time\n'
                        'Date: $date\n'
                        'Location: $address\n'
                        'GPS Coordinates: ($latitude, $longitude)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.02,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),

                  Positioned(bottom: 260,left: 187,right: 0,
                    child: Container(
                      child: IconButton(onPressed: (){safeSetState((){_imageFile = null;});}, icon: const Icon(Icons.cancel,color: Colors.white,size: 30,))))
                ],
              ),
            )
          : const Text('No image selected.'),
    ),
    floatingActionButton: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: _pickImageFromCamera,
          child: Icon(Icons.camera),
          tooltip: 'Capture Image from Camera',
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          onPressed: _imageFile != null ? _saveLocalImage : null,
          child: Icon(Icons.download),
          tooltip: 'Download Image with Overlay',
        ),
      ],
    ),
  );
}
}
