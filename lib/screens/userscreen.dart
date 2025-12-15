import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:smartagriapp/state/themeprovier.dart';
import 'package:smartagriapp/screens/login_screen.dart';
import 'package:share_plus/share_plus.dart';

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

class UserScreen extends StatefulWidget {
  final String? selectedLang;
  final Function(String)? onLanguageChanged;

  const UserScreen({super.key, this.selectedLang, this.onLanguageChanged});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late String selectedLang;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int totalReadings = 0;
  int totalDiseaseDetections = 0;
  Map<String, dynamic>? latestSensorReading;
  Map<String, dynamic>? latestDiseaseDetection;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  LatLng? _selectedLocation;
  String _selectedAddress = "Not set";
  TextEditingController _nameController = TextEditingController();
  TextEditingController _farmSizeController = TextEditingController();

  // Separate loading states for each share operation
  bool isSharingSensorData = false;
  bool isSharingDiseaseData = false;
  bool isSharingCompleteReport = false;

  @override
  void initState() {
    super.initState();
    selectedLang = widget.selectedLang ?? "EN";
    _initializeAndFetchData();
  }

  // NEW METHOD: Initialize Firestore structure first, then fetch data
  Future<void> _initializeAndFetchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Step 1: Initialize Firestore structure (ensure collections exist)
      await _initializeFirestoreStructure();

      // Step 2: Fetch all data
      await Future.wait([
        _fetchUserData(),
        _fetchStatistics(),
        _fetchLatestSensorReading(),
        _fetchLatestDiseaseDetection(),
      ]);
    } catch (e) {
      debugPrint('Error initializing and fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // NEW METHOD: Initialize Firestore structure
  Future<void> _initializeFirestoreStructure() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('Initializing Firestore structure for user: ${user.uid}');

      // Check if main user document exists
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // If main document doesn't exist, create it
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Created main user document');
      }

      // Check if user_profile subcollection exists
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_profile')
          .doc('profile')
          .get();

      // If profile doesn't exist, create it with default values
      if (!profileDoc.exists) {
        await _createDefaultProfile(user.uid);
        debugPrint('Created user_profile subcollection');
      }

      // Note: sensor_readings and disease_history collections will be created
      // automatically when the first document is added, so we don't need to create them here

      debugPrint('Firestore structure initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firestore structure: $e');
      rethrow;
    }
  }

  void _updateLanguage(String newLang) {
    setState(() {
      selectedLang = newLang;
    });

    if (widget.onLanguageChanged != null) {
      widget.onLanguageChanged!(newLang);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch from user_profile subcollection
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('user_profile')
            .doc('profile')
            .get();

        if (snapshot.exists) {
          setState(() {
            userData = snapshot.data();
            _nameController.text = userData?['name'] ?? '';
            _farmSizeController.text = userData?['farmSize'] ?? '';

            if (userData?['location'] != null) {
              final loc = userData!['location'];
              if (loc['latitude'] != null && loc['longitude'] != null) {
                _selectedLocation = LatLng(loc['latitude'], loc['longitude']);
                _selectedAddress = loc['address'] ?? 'Selected Location';
              }
            }
          });
        } else {
          // This shouldn't happen if initialization worked, but just in case
          debugPrint('Profile not found after initialization');
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDefaultProfile(String userId) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      // Create default profile in user_profile subcollection
      final defaultProfile = {
        'uid': userId,
        'email': userEmail,
        'name': 'Guest User',
        'farmSize': 'Not set',
        'profileImageUrl': '',
        'location': {'latitude': 0.0, 'longitude': 0.0, 'address': 'Not set'},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_profile')
          .doc('profile')
          .set(defaultProfile);

      debugPrint('Created default profile for user: $userId');
    } catch (e) {
      debugPrint('Error creating default profile: $e');
      rethrow;
    }
  }

  // Fetch statistics from user's subcollections
  Future<void> _fetchStatistics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get sensor readings from user's subcollection
        final readingsQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sensor_readings')
            .get();

        // Get disease history from user's subcollection
        final diseaseQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('disease_history')
            .get();

        setState(() {
          totalReadings = readingsQuery.docs.length;
          totalDiseaseDetections = diseaseQuery.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
    }
  }

  // Fetch latest sensor reading from user's subcollection
  Future<void> _fetchLatestSensorReading() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sensor_readings')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          setState(() {
            latestSensorReading = {
              'crop': data['crop'] ?? data['crop_name'] ?? 'Unknown',
              'confidence': data['confidence']?.toString() ?? 'N/A',
              'timestamp': data['timestamp'],
              'moisture': data['moisture']?.toString() ?? 'N/A',
              'temperature': data['temperature']?.toString() ?? 'N/A',
              'ph': data['ph']?.toString() ?? 'N/A',
              'nitrogen': data['nitrogen']?.toString() ?? 'N/A',
              'phosphorus': data['phosphorus']?.toString() ?? 'N/A',
              'potassium': data['potassium']?.toString() ?? 'N/A',
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching latest sensor reading: $e');
    }
  }

  // Fetch latest disease detection from user's subcollection
  Future<void> _fetchLatestDiseaseDetection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('disease_history')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          setState(() {
            latestDiseaseDetection = {
              'disease': data['disease'] ?? data['diseaseName'] ?? 'Unknown',
              'confidence': data['confidence']?.toString() ?? 'N/A',
              'timestamp': data['timestamp'],
              'crop': data['crop'] ?? 'Not specified',
              'severity': data['severity']?.toString() ?? 'Unknown',
              'treatment':
                  data['treatment'] ??
                  data['recommendedTreatment'] ??
                  'Not specified',
              'notes': data['notes'] ?? '',
              'imageUrl': data['imageUrl'] ?? '',
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching latest disease detection: $e');
    }
  }

  // NEW HELPER METHOD: Ensure profile exists
  Future<void> _ensureProfileExists(String userId) async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_profile')
          .doc('profile')
          .get();

      if (!profileDoc.exists) {
        await _createDefaultProfile(userId);
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
      rethrow;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _uploadImage() async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _imageFile == null) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

      // Ensure Firestore structure exists before uploading
      await _ensureProfileExists(user.uid);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_imageFile!);
      await uploadTask.whenComplete(() {});

      final imageUrl = await storageRef.getDownloadURL();

      // Update profile with image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_profile')
          .doc('profile')
          .update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        userData?['profileImageUrl'] = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  Future<void> _selectLocation() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildLocationDialog(isDarkMode),
    );

    if (result != null) {
      await _saveLocation(
        result['location'] as LatLng,
        result['address'] as String,
      );
    }
  }

  Widget _buildLocationDialog(bool isDarkMode) {
    String address = _selectedAddress;
    double lat = _selectedLocation?.latitude ?? 0.0;
    double lng = _selectedLocation?.longitude ?? 0.0;

    return AlertDialog(
      title: Text(
        'Set Location',
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Address',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[400]! : Colors.grey[700]!,
                ),
                hintText: 'Enter your location address',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[500]! : Colors.grey[500]!,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color(0xFF21C357),
                    width: 2,
                  ),
                ),
                filled: isDarkMode,
                fillColor: isDarkMode ? Colors.grey[700]! : null,
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              onChanged: (value) => address = value,
              controller: TextEditingController(text: address),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      labelStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[400]!
                            : Colors.grey[700]!,
                      ),
                      hintText: 'e.g., 31.5204',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[500]!
                            : Colors.grey[500]!,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: const Color(0xFF21C357),
                          width: 2,
                        ),
                      ),
                      filled: isDarkMode,
                      fillColor: isDarkMode ? Colors.grey[700]! : null,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => lat = double.tryParse(value) ?? lat,
                    controller: TextEditingController(
                      text: lat.toStringAsFixed(6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      labelStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[400]!
                            : Colors.grey[700]!,
                      ),
                      hintText: 'e.g., 74.3587',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[500]!
                            : Colors.grey[500]!,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: const Color(0xFF21C357),
                          width: 2,
                        ),
                      ),
                      filled: isDarkMode,
                      fillColor: isDarkMode ? Colors.grey[700]! : null,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => lng = double.tryParse(value) ?? lng,
                    controller: TextEditingController(
                      text: lng.toStringAsFixed(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'location': LatLng(lat, lng),
              'address': address,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF21C357),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveLocation(LatLng location, String address) async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Ensure profile exists first
      await _ensureProfileExists(user.uid);

      final locationData = {
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': address,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update profile with location
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_profile')
          .doc('profile')
          .update(locationData);

      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
        userData?['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': address,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location saved successfully!'),
          backgroundColor: const Color(0xFF21C357),
        ),
      );
    } catch (e) {
      debugPrint('Error saving location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLocationPreview(bool isDarkMode) {
    if (_selectedLocation == null) {
      return GestureDetector(
        onTap: _selectLocation,
        child: Text(
          'Tap to set location',
          style: TextStyle(
            color: isDarkMode ? Colors.blue[300]! : Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _selectLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.blue[300]! : Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
            'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Profile',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[700]!,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: const Color(0xFF21C357),
                      width: 2,
                    ),
                  ),
                  filled: isDarkMode,
                  fillColor: isDarkMode ? Colors.grey[700]! : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _farmSizeController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Farm Size',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[700]!,
                  ),
                  hintText: 'e.g., 5 acres, 10 hectares',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[500]! : Colors.grey[500]!,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: const Color(0xFF21C357),
                      width: 2,
                    ),
                  ),
                  filled: isDarkMode,
                  fillColor: isDarkMode ? Colors.grey[700]! : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateProfile();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21C357),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Ensure profile exists
      await _ensureProfileExists(user.uid);

      final profileData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'name': _nameController.text.trim(),
        'farmSize': _farmSizeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update existing profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_profile')
          .doc('profile')
          .update(profileData);

      setState(() {
        userData?['name'] = _nameController.text.trim();
        userData?['farmSize'] = _farmSizeController.text.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: const Color(0xFF21C357),
        ),
      );
    } catch (e) {
      debugPrint('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // OPTION 1: Share Sensor Readings Only
  Future<void> _shareSensorReadings() async {
    if (isSharingSensorData) return;

    setState(() {
      isSharingSensorData = true;
    });

    final isUrdu = selectedLang == "UR";

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUrdu
              ? "سینسر ڈیٹا اکٹھا ہو رہا ہے..."
              : "Collecting sensor data...",
        ),
        backgroundColor: Color(0xFF21C357),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch ALL sensor readings from user's subcollection
      final readingsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sensor_readings')
          .orderBy('timestamp', descending: true)
          .get();

      if (readingsQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUrdu
                  ? "کوئی سینسر ریڈنگ دستیاب نہیں ہے"
                  : "No sensor readings available",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Calculate sensor-specific statistics
      double totalMoisture = 0;
      double totalTemperature = 0;
      double totalPh = 0;
      double totalNitrogen = 0;
      double totalPhosphorus = 0;
      double totalPotassium = 0;
      int validMoistureReadings = 0;
      int validTemperatureReadings = 0;
      int validPhReadings = 0;
      Map<String, int> cropCount = {};
      String mostCommonCrop = '';

      // Build SENSOR-SPECIFIC message
      String message =
          '''
SENSOR READINGS REPORT

Farmer: ${userData?['name'] ?? 'Not set'}
Farm Location: $_selectedAddress
Farm Size: ${userData?['farmSize'] ?? 'Not set'}
Total Readings: ${readingsQuery.docs.length}

DETAILED SENSOR READINGS:
═══════════════════════════════════════
''';

      // Add each sensor reading to the message
      for (int i = 0; i < readingsQuery.docs.length; i++) {
        final reading = readingsQuery.docs[i].data();

        // Extract sensor-specific fields
        final cropName =
            reading['crop'] ?? reading['crop_name'] ?? 'Not specified';
        final moisture = reading['moisture']?.toString() ?? 'N/A';
        final temperature = reading['temperature']?.toString() ?? 'N/A';
        final ph = reading['ph']?.toString() ?? 'N/A';
        final nitrogen = reading['nitrogen']?.toString() ?? 'N/A';
        final phosphorus = reading['phosphorus']?.toString() ?? 'N/A';
        final potassium = reading['potassium']?.toString() ?? 'N/A';
        final confidence = reading['confidence']?.toString() ?? 'N/A';

        // Format timestamp
        final timestamp = reading['timestamp'] != null
            ? _formatTimestamp(reading['timestamp'])
            : 'Unknown time';

        message +=
            '''
READING #${i + 1} - $timestamp
Crop: $cropName
${confidence != 'N/A' ? 'Confidence: ${confidence}%\n' : ''}${moisture != 'N/A' ? 'Moisture: ${moisture}%\n' : ''}${temperature != 'N/A' ? 'Temperature: ${temperature}°C\n' : ''}${ph != 'N/A' ? 'pH Level: $ph\n' : ''}${nitrogen != 'N/A' ? 'Nitrogen: ${nitrogen} mg/kg\n' : ''}${phosphorus != 'N/A' ? 'Phosphorus: ${phosphorus} mg/kg\n' : ''}${potassium != 'N/A' ? 'Potassium: ${potassium} mg/kg' : 'Location: $_selectedAddress'}
─────────────────────────────────
''';

        // Calculate sensor statistics
        if (moisture != 'N/A') {
          totalMoisture += double.parse(moisture);
          validMoistureReadings++;
        }

        if (temperature != 'N/A') {
          totalTemperature += double.parse(temperature);
          validTemperatureReadings++;
        }

        if (ph != 'N/A') {
          totalPh += double.parse(ph);
          validPhReadings++;
        }

        if (nitrogen != 'N/A') totalNitrogen += double.parse(nitrogen);
        if (phosphorus != 'N/A') totalPhosphorus += double.parse(phosphorus);
        if (potassium != 'N/A') totalPotassium += double.parse(potassium);

        // Count crops
        cropCount[cropName] = (cropCount[cropName] ?? 0) + 1;
      }

      // Find most common crop
      if (cropCount.isNotEmpty) {
        mostCommonCrop = cropCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      // Calculate sensor averages
      final avgMoisture = validMoistureReadings > 0
          ? (totalMoisture / validMoistureReadings).toStringAsFixed(1)
          : 'N/A';

      final avgTemperature = validTemperatureReadings > 0
          ? (totalTemperature / validTemperatureReadings).toStringAsFixed(1)
          : 'N/A';

      final avgPh = validPhReadings > 0
          ? (totalPh / validPhReadings).toStringAsFixed(1)
          : 'N/A';

      // Add sensor-specific summary
      message +=
          '''
SENSOR STATISTICS:
${mostCommonCrop.isNotEmpty ? 'Most Common Crop: $mostCommonCrop\n' : ''}${avgMoisture != 'N/A' ? 'Average Moisture: ${avgMoisture}%\n' : ''}${avgTemperature != 'N/A' ? 'Average Temperature: ${avgTemperature}°C\n' : ''}${avgPh != 'N/A' ? 'Average pH Level: $avgPh' : 'Farm Location: $_selectedAddress'}

SOIL & ENVIRONMENT RECOMMENDATIONS:
''';

      // Add sensor-specific recommendations
      if (avgMoisture != 'N/A') {
        double moistureValue = double.parse(avgMoisture);
        if (moistureValue < 30) {
          message += '• Soil moisture is LOW - Schedule irrigation\n';
        } else if (moistureValue > 70) {
          message += '• Soil moisture is HIGH - Reduce watering frequency\n';
        } else {
          message += '• Soil moisture is OPTIMAL for most crops\n';
        }
      }

      if (avgPh != 'N/A') {
        double phValue = double.parse(avgPh);
        if (phValue < 5.5) {
          message += '• Soil is ACIDIC - Consider adding agricultural lime\n';
        } else if (phValue > 7.5) {
          message += '• Soil is ALKALINE - Add sulfur or organic matter\n';
        } else {
          message += '• Soil pH is in OPTIMAL range (5.5-7.5)\n';
        }
      }

      if (avgTemperature != 'N/A') {
        double tempValue = double.parse(avgTemperature);
        if (tempValue < 15) {
          message += '• Temperature is LOW - Consider using row covers\n';
        } else if (tempValue > 35) {
          message += '• Temperature is HIGH - Provide shade/irrigation\n';
        } else {
          message += '• Temperature is IDEAL for plant growth\n';
        }
      }

      message +=
          '''
─────────────────────────────────
Shared via Smart Agri App
Report Generated: ${_formatDateTime(DateTime.now())}

#SensorData #SoilHealth #FarmMonitoring #AgricultureTech
''';

      final subject =
          'Farm Sensor Readings Report - ${userData?['name'] ?? 'Farmer'}';

      // Dismiss loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show native share sheet
      await _showShareSheet(message, subject);
    } catch (e) {
      debugPrint('Error sharing sensor data: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrdu
                ? "سینسر ڈیٹا شیئر کرنے میں خرابی: $e"
                : "Error sharing sensor data: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSharingSensorData = false;
        });
      }
    }
  }

  // OPTION 2: Share Disease History Only
  Future<void> _shareDiseaseHistory() async {
    if (isSharingDiseaseData) return;

    setState(() {
      isSharingDiseaseData = true;
    });

    final isUrdu = selectedLang == "UR";

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUrdu
              ? "بیماری کی تاریخ اکٹھا ہو رہی ہے..."
              : "Collecting disease history...",
        ),
        backgroundColor: Color(0xFF21C357),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch ALL disease detections from user's subcollection
      final diseaseQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('disease_history')
          .orderBy('timestamp', descending: true)
          .get();

      if (diseaseQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUrdu
                  ? "کوئی بیماری کی تشخیص دستیاب نہیں ہے"
                  : "No disease detections available",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Calculate disease-specific statistics
      int totalDetections = diseaseQuery.docs.length;
      Map<String, int> diseaseCount = {};
      Map<String, int> cropCount = {};
      double totalConfidence = 0;
      int validDetections = 0;
      String mostCommonDisease = '';
      String mostAffectedCrop = '';
      int healthyCount = 0;
      int infectedCount = 0;

      // Build DISEASE-SPECIFIC message
      String message =
          '''
DISEASE DETECTION HISTORY

Farmer: ${userData?['name'] ?? 'Not set'}
Farm Location: $_selectedAddress
Farm Size: ${userData?['farmSize'] ?? 'Not set'}
Total Detections: $totalDetections

DISEASE DETECTION HISTORY:
═══════════════════════════════════════
''';

      // Add each disease detection to the message
      for (int i = 0; i < diseaseQuery.docs.length; i++) {
        final detection = diseaseQuery.docs[i].data();

        // Extract disease-specific fields
        final diseaseName =
            detection['disease'] ?? detection['diseaseName'] ?? 'Unknown';
        final crop = detection['crop']?.toString() ?? 'Not specified';
        final confidence = detection['confidence']?.toString() ?? 'N/A';
        final severity = detection['severity']?.toString() ?? 'Not specified';
        final treatment =
            detection['treatment'] ??
            detection['recommendedTreatment'] ??
            'Consult expert';
        final notes = detection['notes']?.toString() ?? '';

        // Format timestamp
        final timestamp = detection['timestamp'] != null
            ? _formatTimestamp(detection['timestamp'])
            : 'Unknown time';

        // Check if healthy
        final isHealthy =
            diseaseName.toLowerCase().contains('healthy') ||
            diseaseName.toLowerCase().contains('normal');

        if (isHealthy) healthyCount++;
        if (!isHealthy) infectedCount++;

        message +=
            '''
DETECTION #${i + 1} - $timestamp
Status: ${isHealthy ? 'HEALTHY' : 'DISEASE: ' + diseaseName.toUpperCase()}
Crop: $crop
${!isHealthy ? 'Confidence: ${confidence}%\n' : ''}${!isHealthy ? 'Severity: $severity\n' : ''}${!isHealthy ? 'Treatment: $treatment\n' : ''}${notes.isNotEmpty ? 'Notes: $notes\n' : ''}Detected: $timestamp
─────────────────────────────────
''';

        // Calculate disease statistics
        if (confidence != 'N/A' && !isHealthy) {
          totalConfidence += double.parse(confidence);
          validDetections++;
        }

        // Count diseases and crops (only for actual diseases)
        if (!isHealthy) {
          diseaseCount[diseaseName] = (diseaseCount[diseaseName] ?? 0) + 1;
        }
        cropCount[crop] = (cropCount[crop] ?? 0) + 1;
      }

      // Find most common disease and crop
      if (diseaseCount.isNotEmpty) {
        mostCommonDisease = diseaseCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      if (cropCount.isNotEmpty) {
        mostAffectedCrop = cropCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      // Calculate average confidence
      final avgConfidence = validDetections > 0
          ? (totalConfidence / validDetections).toStringAsFixed(1)
          : 'N/A';

      // Add disease-specific summary
      message +=
          '''
DISEASE STATISTICS:
Healthy Detections: $healthyCount
Disease Detections: $infectedCount
${mostCommonDisease.isNotEmpty ? 'Most Common Disease: $mostCommonDisease\n' : ''}${mostAffectedCrop.isNotEmpty ? 'Most Affected Crop: $mostAffectedCrop\n' : ''}${avgConfidence != 'N/A' ? 'Average Confidence: ${avgConfidence}%' : 'Location: $_selectedAddress'}

DISEASE MANAGEMENT RECOMMENDATIONS:
''';

      // Add disease-specific recommendations
      if (infectedCount > 0) {
        message +=
            '• $infectedCount disease detection${infectedCount > 1 ? 's' : ''} found\n';

        if (mostCommonDisease.isNotEmpty) {
          message += '• Focus on managing: $mostCommonDisease\n';

          // Disease-specific tips
          if (mostCommonDisease.toLowerCase().contains('blight')) {
            message += '• Remove and destroy infected plant material\n';
            message += '• Improve air circulation around plants\n';
            message += '• Avoid overhead watering\n';
          } else if (mostCommonDisease.toLowerCase().contains('rust')) {
            message += '• Remove infected leaves immediately\n';
            message += '• Apply copper-based fungicide\n';
            message += '• Water at soil level only\n';
          } else if (mostCommonDisease.toLowerCase().contains('mildew')) {
            message += '• Increase sunlight exposure\n';
            message += '• Improve ventilation\n';
            message += '• Space plants properly\n';
          } else if (mostCommonDisease.toLowerCase().contains('rot')) {
            message += '• Improve soil drainage\n';
            message += '• Avoid overwatering\n';
            message += '• Use well-draining soil\n';
          }
        }
      } else {
        message += '• No disease detections - Excellent farm health!\n';
        message += '• Continue with preventive measures\n';
        message += '• Maintain regular monitoring schedule\n';
      }

      // General disease prevention tips
      message +=
          '''
GENERAL PREVENTION TIPS:
• Practice crop rotation
• Use disease-resistant varieties
• Maintain field hygiene
• Monitor plants regularly
• Apply treatments timely

ACTION REQUIRED:
${infectedCount > 0 ? '• Immediate attention needed for infected crops\n' : '• No urgent actions required\n'}• Schedule regular health checks

─────────────────────────────────
Shared via Smart Agri App
Report Generated: ${_formatDateTime(DateTime.now())}

#PlantHealth #DiseaseManagement #CropProtection #FarmHealth
''';

      final subject =
          'Disease Detection History - ${userData?['name'] ?? 'Farmer'}';

      // Dismiss loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show native share sheet
      await _showShareSheet(message, subject);
    } catch (e) {
      debugPrint('Error sharing disease data: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrdu
                ? "بیماری کی تاریخ شیئر کرنے میں خرابی: $e"
                : "Error sharing disease history: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSharingDiseaseData = false;
        });
      }
    }
  }

  // OPTION 3: Share Complete Farm Report (Both sensor and disease data)
  Future<void> _shareCompleteReport() async {
    if (isSharingCompleteReport) return;

    setState(() {
      isSharingCompleteReport = true;
    });

    final isUrdu = selectedLang == "UR";

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUrdu
              ? "مکمل رپورٹ تیار ہو رہی ہے..."
              : "Preparing complete report...",
        ),
        backgroundColor: Color(0xFF21C357),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch BOTH sensor readings AND disease history from user's subcollections
      final sensorFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sensor_readings')
          .orderBy('timestamp', descending: true)
          .get();

      final diseaseFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('disease_history')
          .orderBy('timestamp', descending: true)
          .get();

      // Wait for both queries
      final results = await Future.wait([sensorFuture, diseaseFuture]);
      final readingsQuery = results[0];
      final diseaseQuery = results[1];

      // Check if we have any data at all
      if (readingsQuery.docs.isEmpty && diseaseQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUrdu ? "کوئی ڈیٹا دستیاب نہیں ہے" : "No data available",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Build COMPLETE REPORT message
      String message =
          '''
COMPLETE FARM MANAGEMENT REPORT

Farmer: ${userData?['name'] ?? 'Not set'}
Farm Location: $_selectedAddress
Farm Size: ${userData?['farmSize'] ?? 'Not set'}
Report Date: ${_formatDateTime(DateTime.now())}

═══════════════════════════════════════
REPORT SUMMARY
═══════════════════════════════════════
• Sensor Readings: ${readingsQuery.docs.length}
• Disease Detections: ${diseaseQuery.docs.length}
• Farm Status: ${_getFarmStatus(readingsQuery.docs.length, diseaseQuery.docs.length)}
• Overall Health: ${_calculateOverallHealth(readingsQuery, diseaseQuery)}

''';

      // SECTION 1: Sensor Data Summary
      if (readingsQuery.docs.isNotEmpty) {
        message += '''
═══════════════════════════════════════
SENSOR DATA SUMMARY
═══════════════════════════════════════
''';

        // Calculate sensor averages
        double totalMoisture = 0;
        double totalTemperature = 0;
        double totalPh = 0;
        int moistureReadings = 0;
        int tempReadings = 0;
        int phReadings = 0;
        Map<String, int> cropCount = {};

        for (final doc in readingsQuery.docs) {
          final reading = doc.data();
          final moisture = reading['moisture']?.toString();
          final temperature = reading['temperature']?.toString();
          final ph = reading['ph']?.toString();
          final crop = reading['crop'] ?? reading['crop_name'] ?? 'Unknown';

          if (moisture != null && moisture != 'N/A') {
            totalMoisture += double.parse(moisture);
            moistureReadings++;
          }

          if (temperature != null && temperature != 'N/A') {
            totalTemperature += double.parse(temperature);
            tempReadings++;
          }

          if (ph != null && ph != 'N/A') {
            totalPh += double.parse(ph);
            phReadings++;
          }

          cropCount[crop] = (cropCount[crop] ?? 0) + 1;
        }

        final avgMoisture = moistureReadings > 0
            ? (totalMoisture / moistureReadings).toStringAsFixed(1)
            : 'N/A';
        final avgTemperature = tempReadings > 0
            ? (totalTemperature / tempReadings).toStringAsFixed(1)
            : 'N/A';
        final avgPh = phReadings > 0
            ? (totalPh / phReadings).toStringAsFixed(1)
            : 'N/A';

        // Find most common crop
        String mostCommonCrop = '';
        if (cropCount.isNotEmpty) {
          mostCommonCrop = cropCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }

        message +=
            '''
Primary Crop: $mostCommonCrop
Avg Moisture: ${avgMoisture}%
Avg Temperature: ${avgTemperature}°C
Avg pH Level: $avgPh
Total Readings: ${readingsQuery.docs.length}

''';
      } else {
        message += '''
SENSOR DATA: No sensor readings available
''';
      }

      // SECTION 2: Disease Data Summary
      if (diseaseQuery.docs.isNotEmpty) {
        message += '''
═══════════════════════════════════════
DISEASE MANAGEMENT SUMMARY
═══════════════════════════════════════
''';

        Map<String, int> diseaseCount = {};
        int healthyCount = 0;
        int infectedCount = 0;
        double totalConfidence = 0;
        int confidenceReadings = 0;

        for (final doc in diseaseQuery.docs) {
          final detection = doc.data();
          final diseaseName =
              detection['disease'] ?? detection['diseaseName'] ?? 'Unknown';
          final confidence = detection['confidence']?.toString();
          final isHealthy = diseaseName.toLowerCase().contains('healthy');

          if (isHealthy) {
            healthyCount++;
          } else {
            infectedCount++;
            diseaseCount[diseaseName] = (diseaseCount[diseaseName] ?? 0) + 1;

            if (confidence != null && confidence != 'N/A') {
              totalConfidence += double.parse(confidence);
              confidenceReadings++;
            }
          }
        }

        final avgConfidence = confidenceReadings > 0
            ? (totalConfidence / confidenceReadings).toStringAsFixed(1)
            : 'N/A';

        // Find most common disease
        String mostCommonDisease = '';
        if (diseaseCount.isNotEmpty) {
          mostCommonDisease = diseaseCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }

        message +=
            '''
Healthy Detections: $healthyCount
Disease Detections: $infectedCount
Most Common: ${mostCommonDisease.isNotEmpty ? mostCommonDisease : 'None'}
Avg Confidence: ${avgConfidence}%
Total Checks: ${diseaseQuery.docs.length}

''';
      } else {
        message += '''
DISEASE DATA: No disease detections available
''';
      }

      // SECTION 3: Recommendations
      message += '''
═══════════════════════════════════════
ACTIONABLE RECOMMENDATIONS
═══════════════════════════════════════
''';

      // Sensor-based recommendations
      if (readingsQuery.docs.isNotEmpty) {
        message += '''
For Soil & Environment:
• Regular sensor monitoring recommended
• Maintain optimal moisture levels (30-70%)
• Keep pH between 5.5-7.5
• Monitor temperature extremes

''';
      }

      // Disease-based recommendations
      if (diseaseQuery.docs.isNotEmpty) {
        message += '''
For Plant Health:
• Continue regular health checks
• Implement preventive measures
• Isolate infected plants
• Follow treatment schedules

''';
      }

      // General farm management
      message +=
          '''
General Farm Management:
• Document all readings and detections
• Schedule regular maintenance
• Keep farm records updated
• Consult experts when needed

═══════════════════════════════════════
Report Generated by Smart Agri App
Farm Location: $_selectedAddress
Generated: ${_formatDateTime(DateTime.now())}

#FarmReport #Agriculture #SmartFarming #CompleteAnalysis
''';

      final subject =
          'Complete Farm Management Report - ${userData?['name'] ?? 'Farmer'} - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

      // Dismiss loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show native share sheet
      await _showShareSheet(message, subject);
    } catch (e) {
      debugPrint('Error sharing complete report: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrdu
                ? "مکمل رپورٹ شیئر کرنے میں خرابی: $e"
                : "Error sharing complete report: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSharingCompleteReport = false;
        });
      }
    }
  }

  // Helper method to determine farm status
  String _getFarmStatus(int sensorReadings, int diseaseDetections) {
    if (sensorReadings == 0 && diseaseDetections == 0) {
      return 'No Data Available';
    } else if (sensorReadings > 10 && diseaseDetections == 0) {
      return 'Excellent';
    } else if (sensorReadings > 5 && diseaseDetections < 3) {
      return 'Good';
    } else if (sensorReadings > 0 && diseaseDetections < 5) {
      return 'Fair';
    } else {
      return 'Needs Attention';
    }
  }

  // Helper method to calculate overall health score
  String _calculateOverallHealth(
    QuerySnapshot sensorData,
    QuerySnapshot diseaseData,
  ) {
    int score = 100;

    // Deduct points based on sensor readings
    if (sensorData.docs.isEmpty) {
      score -= 30;
    } else if (sensorData.docs.length < 5) {
      score -= 10;
    }

    // Deduct points based on disease detections
    int diseaseCount = 0;
    for (final doc in diseaseData.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final diseaseName = data['disease'] ?? data['diseaseName'] ?? '';
      if (!diseaseName.toString().toLowerCase().contains('healthy')) {
        diseaseCount++;
      }
    }

    if (diseaseCount > 5) {
      score -= 40;
    } else if (diseaseCount > 2) {
      score -= 20;
    } else if (diseaseCount > 0) {
      score -= 10;
    }

    // Clamp score between 0-100
    score = score.clamp(0, 100);

    if (score >= 80) return 'Excellent ($score%)';
    if (score >= 60) return 'Good ($score%)';
    if (score >= 40) return 'Fair ($score%)';
    return 'Needs Improvement ($score%)';
  }

  // Show native share sheet
  Future<void> _showShareSheet(String message, String subject) async {
    await Share.share(
      message,
      subject: subject,
      sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
    );
  }

  // Format numeric timestamps
  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return _formatDateTime(date);
      } else if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return _formatDateTime(date);
      } else if (timestamp is DateTime) {
        return _formatDateTime(timestamp);
      } else if (timestamp is String) {
        // Handle custom timestamp format like "S58:57"
        return _parseCustomTimestamp(timestamp);
      } else {
        return 'Unknown time';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _parseCustomTimestamp(String timestamp) {
    try {
      // Handle "S58:57" format - likely "5:58:57"
      if (timestamp.contains('S58:')) {
        return timestamp.replaceAll('S58:', '5:');
      }
      return timestamp;
    } catch (e) {
      return timestamp;
    }
  }

  Future<void> _refreshData() async {
    await _initializeAndFetchData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedLang == "UR" ? "ڈیٹا تازہ شدہ" : "Data refreshed",
        ),
        backgroundColor: Color(0xFF21C357),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;
    final isUrdu = selectedLang == "UR";

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900]! : Colors.white,
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF21C357)))
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: Color(0xFF21C357),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: isUrdu
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Theme Toggle and Language
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Language Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[800]!
                                  : Colors.grey[100]!,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _updateLanguage("EN");
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedLang == "EN"
                                          ? Color(0xFF21C357)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      "EN",
                                      style: TextStyle(
                                        color: selectedLang == "EN"
                                            ? Colors.white
                                            : (isDarkMode
                                                  ? Colors.grey[400]!
                                                  : Colors.grey[600]!),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _updateLanguage("UR");
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedLang == "UR"
                                          ? Color(0xFF21C357)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      "UR",
                                      style: TextStyle(
                                        color: selectedLang == "UR"
                                            ? Colors.white
                                            : (isDarkMode
                                                  ? Colors.grey[400]!
                                                  : Colors.grey[600]!),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Dark Mode Toggle
                          GestureDetector(
                            onTap: () {
                              themeProvider.toggleTheme();
                            },
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[100]!,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isDarkMode ? 'Light' : 'Dark',
                                style: TextStyle(
                                  color: Color(0xFF21C357),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      Text(
                        isUrdu ? "صارف کا پروفائل" : "User Profile",
                        textDirection: isUrdu
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.grey[800]!,
                        ),
                      ),

                      SizedBox(height: 20),

                      // PROFILE CARD
                      _buildProfileCard(isUrdu, isDarkMode),
                      SizedBox(height: 20),

                      // FARM DETAILS CARD
                      _buildFarmDetailsCard(isUrdu, isDarkMode),
                      SizedBox(height: 20),

                      // STATISTICS CARD
                      _buildStatisticsCard(isUrdu, isDarkMode),
                      SizedBox(height: 20),

                      // ACTIONS CARD
                      _buildActionsCard(isUrdu, isDarkMode),
                      SizedBox(height: 20),

                      // SIGN OUT BUTTON
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(vertical: 10),
                        child: ElevatedButton(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF21C357),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            isUrdu ? "لاگ آوٹ کریں" : "Sign Out",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // PROFILE CARD
  Widget _buildProfileCard(bool isUrdu, bool isDarkMode) {
    final userName = userData?['name'] ?? 'Guest User';
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'No email';
    final joinDate =
        userData?['createdAt']?.toDate()?.year ?? DateTime.now().year;
    final profileImageUrl = userData?['profileImageUrl'];

    // Helper function to check if we have a valid image URL
    bool hasValidImageUrl() {
      return profileImageUrl != null &&
          profileImageUrl.isNotEmpty &&
          profileImageUrl != "null" &&
          profileImageUrl.startsWith('http');
    }

    return Container(
      decoration: _cardDecoration(isDarkMode),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  // CircleAvatar with safe image loading
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(
                      0xFF21C357,
                    ).withOpacity(isDarkMode ? 0.2 : 0.1),
                    // Only use NetworkImage if we have a valid URL
                    backgroundImage: hasValidImageUrl()
                        ? NetworkImage(profileImageUrl!) as ImageProvider
                        : null,
                    // Show text if we DON'T have a valid image
                    child: !hasValidImageUrl()
                        ? Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey[400]!
                                  : Color(0xFF21C357),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(0xFF21C357),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '📷',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            Text(
              userName,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.grey[800]!,
              ),
            ),

            SizedBox(height: 8),

            Text(
              userEmail,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),

            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  isUrdu ? "رکنیت از $joinDate" : "Member since $joinDate",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[700]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // FARM DETAILS CARD
  Widget _buildFarmDetailsCard(bool isUrdu, bool isDarkMode) {
    final farmSize = userData?['farmSize'] ?? 'Not set';

    return Container(
      decoration: _cardDecoration(isDarkMode),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: isUrdu
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            _cardTitle(
              isUrdu ? "زرعی تفصیلات" : "Farm Details",
              '🌾',
              isUrdu,
              isDarkMode,
            ),

            SizedBox(height: 16),

            _buildDetailRow(
              label: isUrdu ? "زرعی رقبہ" : "Farm Size",
              value: farmSize,
              isUrdu: isUrdu,
              isDarkMode: isDarkMode,
              onTap: () {
                if (farmSize == 'Not set') {
                  _editProfile();
                }
              },
            ),

            _buildDetailRow(
              label: isUrdu ? "مقام" : "Location",
              value: '',
              isUrdu: isUrdu,
              isDarkMode: isDarkMode,
              customWidget: _buildLocationPreview(isDarkMode),
            ),

            SizedBox(height: 16),

            ElevatedButton(
              onPressed: _selectLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF21C357),
                foregroundColor: Colors.white,
              ),
              child: Text(isUrdu ? "مقام منتخب کریں" : "Set Location"),
            ),
          ],
        ),
      ),
    );
  }

  // STATISTICS CARD
  Widget _buildStatisticsCard(bool isUrdu, bool isDarkMode) {
    final hasData = totalReadings > 0 || totalDiseaseDetections > 0;

    if (!hasData) {
      return Container(
        decoration: _cardDecoration(isDarkMode),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _cardTitle(
                isUrdu ? "شماریات" : "Statistics",
                '📊',
                isUrdu,
                isDarkMode,
              ),
              SizedBox(height: 20),
              Text('📈', style: TextStyle(fontSize: 60)),
              SizedBox(height: 16),
              Text(
                isUrdu ? "ابھی تک کوئی ڈیٹا نہیں" : "No data yet",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
              SizedBox(height: 8),
              Text(
                isUrdu
                    ? "سینسر استعمال کرنے کے بعد ڈیٹا دکھائی دے گا"
                    : "Data will appear after using sensors",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500]! : Colors.grey[500]!,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(isDarkMode),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: isUrdu
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            _cardTitle(
              isUrdu ? "شماریات" : "Statistics",
              '📊',
              isUrdu,
              isDarkMode,
            ),

            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  value: totalReadings.toString(),
                  label: isUrdu ? "ریڈنگز" : "Readings",
                  subtitle: isUrdu ? "سینسر ریڈنگز" : "Sensor Readings",
                  isDarkMode: isDarkMode,
                ),
                _buildStatItem(
                  value: totalDiseaseDetections.toString(),
                  label: isUrdu ? "تشخیص" : "Detections",
                  subtitle: isUrdu ? "بیماری کی تشخیص" : "Disease Detections",
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            SizedBox(height: 10),

            // Latest sensor reading info
            if (latestSensorReading != null &&
                latestSensorReading!['crop'] != null)
              Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700]! : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('🌱', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUrdu
                                ? "آخری فصل: ${latestSensorReading!['crop']}"
                                : "Latest Crop: ${latestSensorReading!['crop']}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (latestSensorReading!['moisture'] != 'N/A')
                            Text(
                              isUrdu
                                  ? "نمی: ${latestSensorReading!['moisture']}%"
                                  : "Moisture: ${latestSensorReading!['moisture']}%",
                              style: TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Latest disease detection info
            if (latestDiseaseDetection != null &&
                latestDiseaseDetection!['disease'] != null)
              Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700]! : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('🏥', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUrdu
                                ? "بیماری: ${latestDiseaseDetection!['disease']}"
                                : "Disease: ${latestDiseaseDetection!['disease']}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (latestDiseaseDetection!['confidence'] != 'N/A')
                            Text(
                              isUrdu
                                  ? "اعتماد: ${latestDiseaseDetection!['confidence']}%"
                                  : "Confidence: ${latestDiseaseDetection!['confidence']}%",
                              style: TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ACTIONS CARD
  Widget _buildActionsCard(bool isUrdu, bool isDarkMode) {
    return Container(
      decoration: _cardDecoration(isDarkMode),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: isUrdu
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            _cardTitle(isUrdu ? "عملیات" : "Actions", '⚙️', isUrdu, isDarkMode),

            SizedBox(height: 16),

            _buildActionButton(
              label: isUrdu ? "پروفائل میں ترمیم کریں" : "Edit Profile",
              onPressed: _editProfile,
              isDarkMode: isDarkMode,
            ),

            // OPTION 1: Share Sensor Data Only
            _buildActionButton(
              label: isSharingSensorData
                  ? (isUrdu
                        ? "سینسر ڈیٹا شیئر ہو رہا ہے..."
                        : "Sharing Sensor Data...")
                  : (isUrdu ? "سینسر ڈیٹا شیئر کریں" : "Share Sensor Data"),
              onPressed: isSharingSensorData ? null : _shareSensorReadings,
              isDarkMode: isDarkMode,
            ),

            // OPTION 2: Share Disease History Only
            _buildActionButton(
              label: isSharingDiseaseData
                  ? (isUrdu
                        ? "بیماری کی تاریخ شیئر ہو رہی ہے..."
                        : "Sharing Disease History...")
                  : (isUrdu
                        ? "بیماری تاریخ شیئر کریں"
                        : "Share Disease History"),
              onPressed: isSharingDiseaseData ? null : _shareDiseaseHistory,
              isDarkMode: isDarkMode,
            ),

            // OPTION 3: Share Complete Report
            _buildActionButton(
              label: isSharingCompleteReport
                  ? (isUrdu
                        ? "مکمل رپورٹ شیئر ہو رہی ہے..."
                        : "Sharing Complete Report...")
                  : (isUrdu ? "مکمل رپورٹ شیئر کریں" : "Share Complete Report"),
              onPressed: isSharingCompleteReport ? null : _shareCompleteReport,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDarkMode) {
    return BoxDecoration(
      color: isDarkMode ? Colors.grey[800]! : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDarkMode ? Colors.grey[700]! : Color(0xFFE0E0E0),
      ),
      boxShadow: isDarkMode
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
    );
  }

  Widget _cardTitle(String title, String emoji, bool isUrdu, bool isDarkMode) {
    return Row(
      mainAxisAlignment: isUrdu
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 24)),
        SizedBox(width: 8),
        Text(
          title,
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.grey[800]!,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool isUrdu,
    required bool isDarkMode,
    Widget? customWidget,
    VoidCallback? onTap,
  }) {
    final content = GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isUrdu) ...[
              Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                    ),
                  ),
                ],
              ),
              if (customWidget != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: customWidget,
                  ),
                )
              else
                Text(
                  value == 'Not set' ? 'Tap to set' : value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value == 'Not set'
                        ? (isDarkMode ? Colors.blue[300]! : Colors.blue)
                        : (isDarkMode ? Colors.white : Colors.grey[800]!),
                  ),
                ),
            ],

            if (isUrdu) ...[
              if (customWidget != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: customWidget,
                  ),
                )
              else
                Text(
                  value == 'Not set' ? 'سیٹ کرنے کے لیے ٹیپ کریں' : value,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value == 'Not set'
                        ? (isDarkMode ? Colors.blue[300]! : Colors.blue)
                        : (isDarkMode ? Colors.white : Colors.grey[800]!),
                  ),
                ),
              Row(
                children: [
                  Text(
                    label,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return onTap != null ? content : Container(child: content);
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Color(0xFF21C357).withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFF21C357).withOpacity(isDarkMode ? 0.4 : 0.3),
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF21C357),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.grey[800]!,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
          foregroundColor: isDarkMode ? Colors.white : Colors.grey[800]!,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDarkMode ? Colors.grey[700]! : Color(0xFFE0E0E0),
            ),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.grey[800]!,
                  ),
                ),
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                fontSize: 20,
                color: isDarkMode ? Colors.grey[400]! : Colors.grey[500]!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
