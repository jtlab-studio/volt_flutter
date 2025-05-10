// lib/features/profile/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/profile_providers.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _customEcorController;
  String _biologicalSex = 'other';
  String _distanceUnit = 'km';
  String _paceUnit = 'min/km';
  bool _useCustomEcor = false;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _ageController = TextEditingController();
    _customEcorController = TextEditingController();

    // Load user profile data
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _customEcorController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the provider to load the user profile
      final profile = await ref.read(userProfileProvider.future);

      // Fill in form fields with user data
      _nameController.text = profile.name;
      _weightController.text = profile.weightKg.toString();
      _heightController.text = profile.heightCm.toString();
      _ageController.text = profile.age.toString();

      setState(() {
        _biologicalSex = profile.biologicalSex;
        _distanceUnit = profile.distanceUnit;
        _paceUnit = profile.paceUnit;

        // Set custom ECOR if available
        if (profile.customEcor != null) {
          _useCustomEcor = true;
          _customEcorController.text = profile.customEcor!.toString();
        }
      });
    } catch (e) {
      _showErrorMessage('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Create updated profile from form data
      final updatedProfile = UserProfile(
        name: _nameController.text,
        weightKg: double.parse(_weightController.text),
        heightCm: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        biologicalSex: _biologicalSex,
        distanceUnit: _distanceUnit,
        paceUnit: _paceUnit,
        customEcor: _useCustomEcor && _customEcorController.text.isNotEmpty
            ? double.parse(_customEcorController.text)
            : null,
        lastUpdated: DateTime.now(),
      );

      // Save the profile
      await updatedProfile.save();

      // Refresh the provider
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e) {
      _showErrorMessage('Error saving profile: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: Colors.black,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveUserProfile,
                  tooltip: 'Save Profile',
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileForm(),
    );
  }

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Card
            Card(
              color: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Weight field - IMPORTANT for power calculations
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.fitness_center),
                        helperText: 'Required for power calculations',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your weight';
                        }
                        final weight = double.tryParse(value);
                        if (weight == null || weight <= 0 || weight > 300) {
                          return 'Please enter a valid weight';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Height field
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your height';
                        }
                        final height = int.tryParse(value);
                        if (height == null || height <= 0 || height > 300) {
                          return 'Please enter a valid height';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Age field
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age <= 0 || age > 120) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Biological sex selection
                    const Text(
                      'Biological Sex',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'male',
                          label: Text('Male'),
                          icon: Icon(Icons.male),
                        ),
                        ButtonSegment(
                          value: 'female',
                          label: Text('Female'),
                          icon: Icon(Icons.female),
                        ),
                        ButtonSegment(
                          value: 'other',
                          label: Text('Other'),
                          icon: Icon(Icons.person),
                        ),
                      ],
                      selected: {_biologicalSex},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _biologicalSex = selection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Units & Preferences Card
            Card(
              color: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Units & Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Distance unit selection
                    const Text(
                      'Distance Unit',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'km',
                          label: Text('Kilometers'),
                        ),
                        ButtonSegment(
                          value: 'mi',
                          label: Text('Miles'),
                        ),
                      ],
                      selected: {_distanceUnit},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _distanceUnit = selection.first;
                          // Update pace unit to match distance unit
                          _paceUnit =
                              _distanceUnit == 'km' ? 'min/km' : 'min/mi';
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Pace unit selection
                    const Text(
                      'Pace Unit',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'min/km',
                          label: Text('min/km'),
                        ),
                        ButtonSegment(
                          value: 'min/mi',
                          label: Text('min/mi'),
                        ),
                      ],
                      selected: {_paceUnit},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _paceUnit = selection.first;
                          // Update distance unit to match pace unit
                          _distanceUnit = _paceUnit == 'min/km' ? 'km' : 'mi';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Advanced Settings Card
            Card(
              color: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advanced Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Custom ECOR toggle
                    SwitchListTile(
                      title: const Text('Custom Energy Cost of Running (ECOR)'),
                      subtitle: const Text(
                        'Override the default energy calculation coefficient',
                      ),
                      value: _useCustomEcor,
                      onChanged: (bool value) {
                        setState(() {
                          _useCustomEcor = value;
                        });
                      },
                    ),

                    // Custom ECOR value
                    if (_useCustomEcor)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextFormField(
                          controller: _customEcorController,
                          decoration: const InputDecoration(
                            labelText: 'ECOR Value (J/kg/m)',
                            helperText: 'Typical range: 0.90 - 1.10',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,4}')),
                          ],
                          validator: (value) {
                            if (_useCustomEcor) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an ECOR value';
                              }
                              final ecor = double.tryParse(value);
                              if (ecor == null || ecor <= 0 || ecor > 2.0) {
                                return 'Please enter a valid ECOR value';
                              }
                            }
                            return null;
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    const Text(
                      'What is ECOR?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Energy Cost of Running (ECOR) is the energy required to '
                      'move 1 kg of body mass over 1 meter of distance. This '
                      'value varies slightly between runners based on running '
                      'economy. Only modify if you have accurate test data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveUserProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SAVE PROFILE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
