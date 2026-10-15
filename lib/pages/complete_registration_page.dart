import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard_page.dart';
import '../features/main_shell.dart';
import '../core/utils/role_utils.dart';

class CompleteRegistrationPage extends StatefulWidget {
  const CompleteRegistrationPage({super.key});

  @override
  State<CompleteRegistrationPage> createState() =>
      _CompleteRegistrationPageState();
}

class _CompleteRegistrationPageState
    extends State<CompleteRegistrationPage> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime? _selectedDob;
  String? _selectedGender;

  bool _loading = false;

  static const List<String> _genderOptions = [
    "Male",
    "Female",
    "Other",
  ];

  // ============================================================
  // COLORS
  // ============================================================

  static const navy = Color(0xFF0D1B3E);
  static const yellow = Color(0xFFFFCC00);
  static const grey = Color(0xFFF0F2F8);
  static const greyBorder = Color(0xFFDDE0EE);
  static const red = Color(0xFFEF4444);

  User? get _user => _auth.currentUser;

  // ============================================================
  // INITIALIZE EXISTING USER DATA
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = _user;

    if (user == null) return;

    try {
      final doc = await _firestore
          .collection("users")
          .doc(user.uid)
          .get();

      if (!mounted) return;

      // Use existing Firestore data if the profile already exists.
      if (doc.exists) {
        final data = doc.data();

        if (data != null) {
          final existingName = data["name"];
          final existingGender = data["gender"];
          final existingDob = data["dob"];
          final existingUpi = data["upiId"];


          if (existingName != null &&
              existingName.toString().trim().isNotEmpty) {
            _nameCtrl.text = existingName.toString();
          } else if (user.displayName != null &&
              user.displayName!.trim().isNotEmpty) {
            _nameCtrl.text = user.displayName!;
          }

          if (existingGender != null) {
            final gender = existingGender.toString();

            if (_genderOptions.contains(gender)) {
              _selectedGender = gender;
            }
          }

          if (existingUpi != null &&
              existingUpi.toString().trim().isNotEmpty) {
            _upiCtrl.text = existingUpi.toString();
          }

          if (existingDob is Timestamp) {
            final dob = existingDob.toDate();

            _selectedDob = dob;

            _dobCtrl.text =
            "${dob.day.toString().padLeft(2, '0')}/"
                "${dob.month.toString().padLeft(2, '0')}/"
                "${dob.year}";
          }
        }
      } else {
        // New Google user.
        // Google already provides the name.
        if (user.displayName != null &&
            user.displayName!.trim().isNotEmpty) {
          _nameCtrl.text = user.displayName!;
        }
      }

      setState(() {});
    } catch (e) {
      // If loading existing data fails, the user can still
      // manually enter their information.
      if (!mounted) return;

      if (user.displayName != null &&
          user.displayName!.trim().isNotEmpty &&
          _nameCtrl.text.isEmpty) {
        setState(() {
          _nameCtrl.text = user.displayName!;
        });
      }
    }
  }

  // ============================================================
  // DOB
  // ============================================================

  Future<void> _pickDob() async {
    final now = DateTime.now();

    // User must be at least 18 years old.
    final maxDob = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? maxDob,
      firstDate: DateTime(now.year - 100),
      lastDate: maxDob,
      helpText: "Select your Date of Birth",
      cancelText: "Cancel",
      confirmText: "Select",
    );

    if (picked == null) return;

    setState(() {
      _selectedDob = picked;

      _dobCtrl.text =
      "${picked.day.toString().padLeft(2, '0')}/"
          "${picked.month.toString().padLeft(2, '0')}/"
          "${picked.year}";
    });
  }

  int _age(DateTime dob) {
    final now = DateTime.now();

    int age = now.year - dob.year;

    if (now.month < dob.month ||
        (now.month == dob.month &&
            now.day < dob.day)) {
      age--;
    }

    return age;
  }

  // ============================================================
  // COMPLETE PROFILE
  // ============================================================

  Future<void> _complete() async {
    final user = _user;

    if (user == null) {
      _snack(
        "Session expired. Please login again.",
        error: true,
      );
      return;
    }

    final upiId = _upiCtrl.text.trim();

    if (upiId.isNotEmpty && !upiId.contains('@')) {
      _snack(
        "Enter a valid UPI ID (e.g. name@upi)",
        error: true,
      );
      return;
    }


    final name = _nameCtrl.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (name.length < 3) {
      _snack(
        "Enter your full name",
        error: true,
      );
      return;
    }

    if (_selectedDob == null) {
      _snack(
        "Select your date of birth",
        error: true,
      );
      return;
    }

    if (_age(_selectedDob!) < 18) {
      _snack(
        "You must be at least 18 years old",
        error: true,
      );
      return;
    }

    if (_selectedGender == null) {
      _snack(
        "Please select your gender",
        error: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // --------------------------------------------------------
      // UPDATE FIREBASE AUTH NAME
      // --------------------------------------------------------

      await user.updateDisplayName(name);

      // --------------------------------------------------------
      // DETERMINE AUTH PROVIDER
      // --------------------------------------------------------

      String authProvider = "google";

      if (user.providerData.isNotEmpty) {
        final providerIds = user.providerData
            .map((provider) => provider.providerId)
            .toList();

        if (providerIds.contains("google.com")) {
          authProvider = "google";
        } else if (providerIds.contains("password")) {
          authProvider = "email";
        } else if (providerIds.contains("phone")) {
          authProvider = "phone";
        }
      }

      // --------------------------------------------------------
      // CREATE / UPDATE PROFILE
      // --------------------------------------------------------
      //
      // merge: true is important.
      //
      // If the Google user already has an incomplete profile,
      // we update the missing information without deleting
      // anything else already stored in Firestore.
      // --------------------------------------------------------

      await _firestore
          .collection("users")
          .doc(user.uid)
          .set(
        {
          "name": name,
          "email": user.email ?? "",
          "dob": Timestamp.fromDate(_selectedDob!),
          "gender": _selectedGender,
          "photoUrl": user.photoURL ?? "",
          "upiId": upiId,
          "profileComplete": true,
          "authProvider": authProvider,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _snack("Profile completed successfully!");

      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // ROUTE USER
      // --------------------------------------------------------

      final isAdmin = await RoleUtils.isAdmin(user);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isAdmin
              ? const AdminDashboardPage()
              : const MainShell(),
        ),
      );
    } on FirebaseException catch (e) {
      _snack(
        "${e.plugin}: ${e.code}",
        error: true,
      );
    } catch (e) {
      _snack(
        "Could not complete your profile.",
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _snack(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: error ? red : yellow,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _upiCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: navy,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Complete Your Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // TOP ICON
              // =================================================

              Center(
                child: Container(
                  height: 70,
                  width: 70,
                  decoration: const BoxDecoration(
                    color: yellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: navy,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // HEADER
              // =================================================

              const Center(
                child: Text(
                  "Almost there!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  "Complete your profile to unlock all GharTak features.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =================================================
              // PROGRESS
              // =================================================

              Row(
                children: [
                  _stepCircle(
                    number: "1",
                    active: true,
                  ),

                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.white24,
                    ),
                  ),

                  _stepCircle(
                    number: "2",
                    active: true,
                  ),

                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.white24,
                    ),
                  ),

                  _stepCircle(
                    number: "3",
                    active: false,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Account",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "Ready",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // =================================================
              // GOOGLE ACCOUNT CARD
              // =================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: grey,
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_circle_outlined,
                        color: navy,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Google Account",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.email ?? "No email",
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: navy,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // PERSONAL INFORMATION
              // =================================================

              const Text(
                "Personal Information",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Some information is still required before you can find or post rides.",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // FULL NAME
              // =================================================

              _field(
                controller: _nameCtrl,
                label: "Full Name",
                icon: Icons.person_outline_rounded,
                keyboard: TextInputType.name,
                textCapitalization:
                TextCapitalization.words,
              ),

              // =================================================
              // DOB
              // =================================================

              _field(
                controller: _dobCtrl,
                label: "Date of Birth",
                icon: Icons.calendar_month_outlined,
                readOnly: true,
                onTap: _pickDob,
                suffix: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: navy,
                ),
              ),

              // =================================================
              // GENDER
              // =================================================

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 16,
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  isExpanded: true,

                  decoration: InputDecoration(
                    labelText: "Gender",
                    labelStyle: const TextStyle(
                      color: Colors.black54,
                    ),
                    floatingLabelStyle:
                    const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.wc_outlined,
                      color: navy,
                    ),
                    filled: true,
                    fillColor: grey,
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide:
                      const BorderSide(
                        color: greyBorder,
                      ),
                    ),
                    enabledBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide:
                      const BorderSide(
                        color: greyBorder,
                      ),
                    ),
                    focusedBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide:
                      const BorderSide(
                        color: yellow,
                        width: 2,
                      ),
                    ),
                  ),

                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: navy,
                  ),

                  items: _genderOptions.map(
                        (gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(
                          gender,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 15.5,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ).toList(),

                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),

              // =================================================
// UPI ID
// =================================================

              _field(
                controller: _upiCtrl,
                label: "UPI ID (Optional)",
                icon: Icons.account_balance_wallet_outlined,
                keyboard: TextInputType.emailAddress,
              ),

              const Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  right: 4,
                  bottom: 24,
                ),
                child: Text(
                  "Add your UPI ID so riders can pay you after a ride.",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),

              // =================================================
              // INFO BOX
              // =================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(
                  bottom: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius:
                  BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: yellow,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You must be at least 18 years old to use GharTak.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // COMPLETE BUTTON
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    disabledBackgroundColor:
                    yellow.withOpacity(0.5),
                    foregroundColor: navy,
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: navy,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Text(
                        "Complete Profile",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // =================================================
              // FOOTER
              // =================================================

              const Center(
                child: Text(
                  "Welcome to GharTak 🚗",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM TEXT FIELD
  // ============================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: readOnly,
        onTap: onTap,
        textCapitalization:
        textCapitalization,

        style: const TextStyle(
          color: navy,
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
        ),

        decoration: InputDecoration(
          labelText: label,

          labelStyle: const TextStyle(
            color: Colors.black54,
          ),

          floatingLabelStyle:
          const TextStyle(
            color: navy,
            fontWeight: FontWeight.w600,
          ),

          prefixIcon: Icon(
            icon,
            color: navy,
          ),

          suffixIcon: suffix,

          filled: true,
          fillColor: grey,

          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),

          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: greyBorder,
            ),
          ),

          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: greyBorder,
            ),
          ),

          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: yellow,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STEP CIRCLE
  // ============================================================

  Widget _stepCircle({
    required String number,
    required bool active,
  }) {
    return Container(
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? yellow
            : Colors.white12,
        border: Border.all(
          color: active
              ? yellow
              : Colors.white30,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: active
                ? navy
                : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}