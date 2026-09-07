import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StudentSearchResult {
  final String userId;
  final String firstname;
  final String lastname;
  final String email;
  final int? programId;
  final String? programCode;
  final int? yearLevel;
  final int? studentStatus;
  final int role;
  final String roleName;

  StudentSearchResult({
    required this.userId,
    required this.firstname,
    required this.lastname,
    required this.email,
    this.programId,
    this.programCode,
    this.yearLevel,
    this.studentStatus,
    required this.role,
    required this.roleName,
  });

  String get fullName => '$firstname $lastname'.trim();

  factory StudentSearchResult.fromJson(Map<String, dynamic> json) {
    return StudentSearchResult(
      userId: json['userID'] ?? json['userId'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      email: json['email'] ?? '',
      programId: json['programID'] ?? json['programId'],
      programCode: json['programCode'],
      yearLevel: json['yearLevel'],
      studentStatus: json['studentStatus'],
      role: json['role'] ?? 5,
      roleName: json['roleName'] ?? 'Student',
    );
  }
}

class GradeClearanceItem {
  final String clearanceId;
  final String userId;
  final String termId;
  final String? termLabel;
  bool isCleared;
  final String? clearedByUserId;
  final String? clearedByUserName;
  final String? clearedAt;

  GradeClearanceItem({
    required this.clearanceId,
    required this.userId,
    required this.termId,
    this.termLabel,
    required this.isCleared,
    this.clearedByUserId,
    this.clearedByUserName,
    this.clearedAt,
  });

  factory GradeClearanceItem.fromJson(Map<String, dynamic> json) {
    return GradeClearanceItem(
      clearanceId: json['clearanceID'] ?? json['clearanceId'] ?? '',
      userId: json['userID'] ?? json['userId'] ?? '',
      termId: json['termID'] ?? json['termId'] ?? '',
      termLabel: json['termLabel'],
      isCleared: json['isCleared'] ?? false,
      clearedByUserId: json['clearedByUserID'] ?? json['clearedByUserId'],
      clearedByUserName: json['clearedByUserName'],
      clearedAt: json['clearedAt'],
    );
  }
}

class ClearanceManagementScreen extends StatefulWidget {
  final String idToken;
  final String apiBaseUrl;

  const ClearanceManagementScreen({
    super.key,
    required this.idToken,
    this.apiBaseUrl = 'http://localhost:5054',
  });

  @override
  State<ClearanceManagementScreen> createState() =>
      _ClearanceManagementScreenState();
}

class _ClearanceManagementScreenState extends State<ClearanceManagementScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  String? _searchError;
  List<StudentSearchResult> _students = [];
  StudentSearchResult? _selectedStudent;

  bool _isLoadingClearances = false;
  String? _clearanceError;
  List<GradeClearanceItem> _clearances = [];
  final Set<String> _togglingTermIds = {};

  @override
  void initState() {
    super.initState();
    // Initial fetch of up to 50 students
    _fetchStudents('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchStudents(query);
    });
  }

  Future<void> _fetchStudents(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/UserDetails?search=${Uri.encodeComponent(query.trim())}&role=5',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.idToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _students = data.map((e) => StudentSearchResult.fromJson(e)).toList();
        });
      } else {
        setState(() {
          _searchError =
              'Error ${response.statusCode}: ${response.body.isNotEmpty ? response.body : response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _selectStudent(StudentSearchResult student) async {
    setState(() {
      _selectedStudent = student;
      _isLoadingClearances = true;
      _clearanceError = null;
      _clearances = [];
    });

    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/gradeclearances/${student.userId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.idToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _clearances = data.map((e) => GradeClearanceItem.fromJson(e)).toList();
        });
      } else {
        setState(() {
          _clearanceError =
              'Error ${response.statusCode}: ${response.body.isNotEmpty ? response.body : response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _clearanceError = 'Failed to load clearance records: $e';
      });
    } finally {
      setState(() {
        _isLoadingClearances = false;
      });
    }
  }

  Future<void> _toggleClearance(GradeClearanceItem item, bool newValue) async {
    if (_selectedStudent == null) return;

    final termId = item.termId;
    setState(() {
      _togglingTermIds.add(termId);
    });

    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/gradeclearances/${_selectedStudent!.userId}/$termId',
      );

      final response = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.idToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isCleared': newValue}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> updated = jsonDecode(response.body);
        setState(() {
          item.isCleared = updated['isCleared'] ?? newValue;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: newValue ? Colors.green.shade700 : Colors.orange.shade800,
              content: Text(
                '${item.termLabel ?? "Term"}: status updated to ${newValue ? "Cleared" : "Uncleared"}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Failed to update clearance: ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Network error: $e'),
          ),
        );
      }
    } finally {
      setState(() {
        _togglingTermIds.remove(termId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Clearance Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left Pane: Search & Student Directory
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  // Debounced Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by student name or email (300ms debounce)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchStudents('');
                                    },
                                  )
                                : null),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                        ),
                      ),
                    ),
                  ),

                  if (_searchError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        _searchError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),

                  // Results header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'STUDENTS (${_students.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Selectable Student List
                  Expanded(
                    child: _students.isEmpty && !_isSearching
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No students found.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _students.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final isSelected =
                                  _selectedStudent?.userId == student.userId;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xFFEFF6FF),
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.shade300,
                                  foregroundColor:
                                      isSelected ? Colors.white : Colors.black87,
                                  child: Text(
                                    student.firstname.isNotEmpty
                                        ? student.firstname[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  student.fullName.isNotEmpty ? student.fullName : '(Unnamed Student)',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.email,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            student.programCode ?? 'No Program',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          student.yearLevel != null ? 'Year ${student.yearLevel}' : 'Year N/A',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right, size: 20),
                                onTap: () => _selectStudent(student),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Right Pane: Clearance History and Toggle
          Expanded(
            flex: 6,
            child: _selectedStudent == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Select a student on the left\nto view and manage term clearances.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected Student Header Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF1E3A8A),
                                child: Text(
                                  _selectedStudent!.firstname.isNotEmpty
                                      ? _selectedStudent!.firstname[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedStudent!.fullName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _selectedStudent!.email,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Program: ${_selectedStudent!.programCode ?? "None"}  •  Year Level: ${_selectedStudent!.yearLevel ?? "N/A"}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'TERM CLEARANCE STATUS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Clearance List
                        Expanded(
                          child: _isLoadingClearances
                              ? const Center(child: CircularProgressIndicator())
                              : _clearanceError != null
                                  ? Center(
                                      child: Text(
                                        _clearanceError!,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : _clearances.isEmpty
                                      ? Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.info_outline, size: 36, color: Colors.grey.shade400),
                                                const SizedBox(height: 10),
                                                const Text(
                                                  'No clearance records exist for this student yet.',
                                                  style: TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Default status is uncleared until a clearance record is created.',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _clearances.length,
                                          itemBuilder: (context, index) {
                                            final item = _clearances[index];
                                            final isToggling = _togglingTermIds.contains(item.termId);

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              elevation: 1,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                side: BorderSide(
                                                  color: item.isCleared
                                                      ? Colors.green.shade200
                                                      : Colors.orange.shade200,
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      item.isCleared ? Icons.check_circle : Icons.warning_rounded,
                                                      color: item.isCleared ? Colors.green.shade600 : Colors.orange.shade700,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item.termLabel ?? 'Academic Term',
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            item.isCleared
                                                                ? 'Cleared${item.clearedByUserName != null ? ' by ${item.clearedByUserName}' : ''}'
                                                                : 'Hold (Uncleared)',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w500,
                                                              color: item.isCleared
                                                                  ? Colors.green.shade800
                                                                  : Colors.orange.shade900,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Toggle Switch
                                                    isToggling
                                                        ? const SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          )
                                                        : Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                item.isCleared ? 'Cleared' : 'Uncleared',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: item.isCleared ? Colors.green : Colors.grey,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Switch(
                                                                value: item.isCleared,
                                                                activeThumbColor: Colors.green.shade600,
                                                                onChanged: (val) => _toggleClearance(item, val),
                                                              ),
                                                            ],
                                                          ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
