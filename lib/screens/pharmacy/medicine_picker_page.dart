import 'package:abc_app/models/medicine_template_model.dart';
import 'package:abc_app/services/medicine_data_service.dart';
import 'package:flutter/material.dart';

class MedicinePickerPage extends StatefulWidget {
  const MedicinePickerPage({super.key});

  @override
  State<MedicinePickerPage> createState() => _MedicinePickerPageState();
}

class _MedicinePickerPageState extends State<MedicinePickerPage> {
  final MedicineDataService _service = MedicineDataService();
  List<MedicineTemplateModel> _allMedicines = [];
  List<MedicineTemplateModel> _filteredMedicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _allMedicines = await _service.loadMedicineDatabase();
      setState(() {
        _filteredMedicines = _allMedicines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error - you might want to show a snackbar
      print('Error loading medicine database: $e');
    }
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      _filteredMedicines = _allMedicines;
    } else {
      _filteredMedicines = _allMedicines
          .where((med) => med.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Medicine'),
        backgroundColor: Colors.white,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: 'Search medicine name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMedicines.isEmpty
          ? const Center(
        child: Text(
          'No medicines found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: _filteredMedicines.length,
        itemBuilder: (context, index) {
          final medicine = _filteredMedicines[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.medical_services,
                  color: Colors.green),
              title: Text(
                medicine.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category: ${medicine.category}'),
                  if (medicine.description.isNotEmpty)
                    Text(
                      medicine.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              onTap: () {
                Navigator.pop(context, medicine);
              },
            ),
          );
        },
      ),
    );
  }
}
