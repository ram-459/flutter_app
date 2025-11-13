// screens/pharmacy/add_ad_page.dart
import 'dart:io';
import 'package:abc_app/models/ad_model.dart';
import 'package:abc_app/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddAdPage extends StatefulWidget {
  const AddAdPage({super.key});

  @override
  State<AddAdPage> createState() => _AddAdPageState();
}

class _AddAdPageState extends State<AddAdPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _offerCodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  File? _imageFile;
  DateTime? _startDate;
  DateTime? _endDate;
  String _adType = 'banner';
  bool _isActive = true;
  bool _isLoading = false;
  String? _pharmacyName;

  final List<String> _adTypes = ['banner', 'offer', 'poster'];

  @override
  void initState() {
    super.initState();
    _getPharmacyInfo();
  }

  Future<void> _getPharmacyInfo() async {
    try {
      final userStream = _firestoreService.getCurrentUserStream();

      // Use take(1) to get the first value and automatically close the subscription
      await userStream.take(1).listen((user) {
        if (mounted) {
          setState(() {
            // Fix: Use null-aware operators
            _pharmacyName = (user.pharmacyName?.isNotEmpty ?? false)
                ? user.pharmacyName
                : (user.name?.isNotEmpty ?? false)
                ? user.name
                : 'Our Pharmacy';
          });
        }
      }).asFuture();

    } catch (e) {
      // Use debugPrint instead of print for production
      debugPrint('Error in _getPharmacyInfo: $e');
      if (mounted) {
        setState(() {
          _pharmacyName = 'Our Pharmacy';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickStartDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        _startDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  Future<void> _pickEndDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate?.add(const Duration(days: 30)) ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
        _endDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  Future<void> _saveAd() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates.')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload image using FirestoreService
      String imageUrl = await _firestoreService.uploadAdImage(_imageFile!);

      // Get current user ID with null check
      final String? userId = _firestoreService.currentUserId;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Create ad model
      AdModel newAd = AdModel(
        id: '', // Will be set by Firestore
        imageUrl: imageUrl,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        pharmacyId: userId,
        pharmacyName: _pharmacyName ?? 'Our Pharmacy',
        startDate: _startDate!,
        endDate: _endDate!,
        isActive: _isActive,
        type: _adType,
        offerCode: _adType == 'offer' ? _offerCodeController.text.trim() : null,
        discountPercentage: _adType == 'offer'
            ? double.tryParse(_discountController.text)
            : null,
        createdAt: DateTime.now(),
      );

      // Save ad using FirestoreService
      await _firestoreService.addAd(newAd);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad/Offer posted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving ad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post ad: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _offerCodeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Ad/Offer'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 24),
              _buildAdTypeDropdown(),
              const SizedBox(height: 16),
              _buildTextFormField(_titleController, 'Title'),
              _buildTextFormField(_descController, 'Description', maxLines: 3),
              _buildDateField(
                _startDateController,
                'Start Date',
                _pickStartDate,
              ),
              _buildDateField(
                _endDateController,
                'End Date',
                _pickEndDate,
              ),
              if (_adType == 'offer') ...[
                _buildTextFormField(_offerCodeController, 'Offer Code'),
                _buildTextFormField(
                  _discountController,
                  'Discount Percentage (%)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_adType == 'offer' && (value == null || value.isEmpty)) {
                      return 'Please enter discount percentage';
                    }
                    if (value != null && value.isNotEmpty) {
                      final discount = double.tryParse(value);
                      if (discount == null || discount <= 0 || discount > 100) {
                        return 'Please enter a valid discount (1-100)';
                      }
                    }
                    return null;
                  },
                ),
              ],
              _buildSwitchRow(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _adType,
      decoration: InputDecoration(
        labelText: 'Ad Type',
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: _adTypes.map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type[0].toUpperCase() + type.substring(1)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _adType = newValue!;
        });
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ad Image *',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _imageFile != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate,
                    size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('Tap to upload image',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
      TextEditingController controller,
      String label,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextFormField(
      TextEditingController controller,
      String label, {
        TextInputType? keyboardType,
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSwitchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Active', style: TextStyle(fontSize: 16)),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeColor: Colors.blue[800],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isLoading ? null : _saveAd,
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          'Post Ad/Offer',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}