import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(GharTakApp());
}

class GharTakApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GharTak Login',
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _login() async {
    try {
      UserCredential user = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user.user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Login Failed"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _forgotPassword() {
    if (_emailController.text.isNotEmpty) {
      _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter your email first")),
      );
    }
  }

  void _createAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(height: 80),
              Icon(Icons.directions_car, size: 80, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text("Welcome to GharTak",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value!);
                    },
                  ),
                  Text("Remember Me"),
                  Spacer(),
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text("Forgot Password?"),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: Text("Login", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: _createAccount,
                child: Text("Create Account", style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _enrollmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _register() async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_contactController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid 10-digit contact number")),
      );
      return;
    }
    try {
      UserCredential user = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user.user != null) {

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.user!.uid)
            .set({
          "name": _nameController.text.trim(),
          "enrollment": _enrollmentController.text.trim(),
          "email": _emailController.text.trim(),
          "contact": _contactController.text.trim(),
          "createdAt": Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account Created Successfully")),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Name"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _enrollmentController,
                decoration: InputDecoration(labelText: "Enrollment"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _contactController,
                decoration: InputDecoration(labelText: "Contact Number"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                child: Text("Register", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool showGetRide = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userName = "User";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          userName = doc["name"];
        });
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dashboard")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.blue),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Welcome, $userName",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    "MENU!!!",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.directions_car),
              title: Text("Get Ride"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  showGetRide = true;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text("Find Ride"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  showGetRide = false;
                });
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showGetRide = true;
                  });
                },
                child: Text("Get Ride"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 40),
                  backgroundColor: showGetRide ? Colors.blue : Colors.grey,
                ),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showGetRide = false;
                  });
                },
                child: Text("Find Ride"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 40),
                  backgroundColor: !showGetRide ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          Expanded(
            child: Center(
              child: showGetRide
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car,
                      size: 80, color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    "Get Ride Page Content",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search,
                      size: 80, color: Colors.orange),
                  SizedBox(height: 20),
                  Text(
                    "Find Ride Page Content",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
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

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String name = "";
  String enrollment = "";
  String email = "";
  String contact = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          name = doc["name"];
          enrollment = doc["enrollment"];
          email = doc["email"];
          contact = doc["contact"];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Profile")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 60),
              ),
            ),
            SizedBox(height: 30),
            Text("Name: $name",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text("Enrollment: $enrollment",
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text("Email: $email", style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text("Contact: $contact", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}