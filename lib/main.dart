import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'chat_input.dart';
import 'chat_list.dart';
import 'chat_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';




void main() async {
  // Asegurar que los widgets estén inicializados antes de usar Firebase
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar Firebase con la configuración por defecto para la plataforma actual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Ejecutar la aplicación principal
  runApp(const MyApp());
}

// Definición de la clase principal MyApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Proveedor de modelo de chat
        ChangeNotifierProvider(create: (_) => ChatModel()),
      ],
      child: MaterialApp(
        title: 'My App',
        // Configuración del tema principal de la app
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        // Pantalla inicial de la aplicación
        home: const RegisterScreen(),
        // Definición de las rutas de navegación
        routes: {
          '/register': (context) => const RegisterScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => MyHomePage(),
          '/nuestrasMezclas': (context) => const NuestrasMezclasPage(),
          '/nuestraIA': (context) => const IAPage(),
          '/hacerUnaCachimba': (context) => const CachimbaTutorialesPage(),
          '/userProfile': (context) => const UserProfile(),
        },
      ),
    );
  }
}

// Definición de la pantalla de registro
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para los campos del formulario
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Variables para almacenar errores específicos
  String birthdateError = '';
  String emailError = '';
  String phoneError = '';

  // Función para registrar al usuario
  Future<void> registerUser() async {
    // Reiniciar errores
    setState(() {
      birthdateError = '';
      emailError = '';
      phoneError = '';
    });

    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Obtener valores de los campos
    final String username = usernameController.text;
    final String password = passwordController.text;
    final String birthdate = birthdateController.text;
    final String phone = phoneController.text;
    final String email = emailController.text;

    // Validar y convertir la fecha de nacimiento
    DateTime? birthdateDate;
    try {
      birthdateDate = DateFormat("yyyy-MM-dd").parseStrict(birthdate);
    } catch (e) {
      setState(() {
        birthdateError = 'Formato de fecha inválido';
      });
      return;
    }

    // Comprobar que la fecha de nacimiento sea mayor de 18 años
    final DateTime currentDate = DateTime.now();
    final int age = currentDate.year - birthdateDate.year;
    if (age < 18 || (age == 18 && currentDate.isBefore(DateTime(currentDate.year, birthdateDate.month, birthdateDate.day)))) {
      setState(() {
        birthdateError = 'Debes tener al menos 18 años';
      });
      return;
    }

    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Verificar si el correo electrónico ya está en uso
      final QuerySnapshot emailSnapshot = await firestore.collection('users').where('email', isEqualTo: email).get();
      if (emailSnapshot.docs.isNotEmpty) {
        setState(() {
          emailError = 'El email ya está en uso';
        });
        return;
      }

      // Verificar si el teléfono ya está en uso
      final QuerySnapshot phoneSnapshot = await firestore.collection('users').where('phone', isEqualTo: phone).get();
      if (phoneSnapshot.docs.isNotEmpty) {
        setState(() {
          phoneError = 'El teléfono ya está en uso';
        });
        return;
      }

      // Crear usuario en Firebase Auth
      final UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Guardar usuario en Firestore
      await firestore.collection('users').doc(userId).set({
        'username': username,
        'birthdate': DateFormat("yyyy-MM-dd").format(birthdateDate),
        'phone': phone,
        'email': email,
        'role': 'basic', // Rol inicial del usuario
      });

      SchedulerBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          setState(() {
            emailError = 'El email ya está en uso';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Función para seleccionar la fecha de nacimiento
  Future<void> selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red, // Color de la barra superior
              onPrimary: Colors.white, // Color del texto en la barra superior
              onSurface: Colors.red, // Color del texto en el calendario
            ),
            dialogBackgroundColor: Colors.white, // Color de fondo del calendario
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      birthdateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/background1.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'REGISTRARSE',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField('Nombre de Usuario', usernameController, validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre de usuario es obligatorio';
                        }
                        return null;
                      }),
                      const SizedBox(height: 10),
                      _buildTextField('Contraseña', passwordController, obscureText: true, validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La contraseña es obligatoria';
                        } else if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      }),
                      const SizedBox(height: 10),
                      _buildTextField('Repetir Contraseña', confirmPasswordController, obscureText: true, validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Repetir la contraseña es obligatorio';
                        } else if (value != passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      }),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          selectDate(context);
                        },
                        child: AbsorbPointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField('Fecha de Nacimiento (yyyy-MM-dd)', birthdateController, validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La fecha de nacimiento es obligatoria';
                                }
                                return null;
                              }),
                              if (birthdateError.isNotEmpty)
                                Text(
                                  birthdateError,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField('Teléfono', phoneController, keyboardType: TextInputType.phone, validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El teléfono es obligatorio';
                            } else if (value.length != 9) {
                              return 'El teléfono debe tener 9 dígitos';
                            }
                            return null;
                          }),
                          if (phoneError.isNotEmpty)
                            Text(
                              phoneError,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField('Email', emailController, keyboardType: TextInputType.emailAddress, validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El email es obligatorio';
                            } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Formato de email inválido';
                            }
                            return null;
                          }),
                          if (emailError.isNotEmpty)
                            Text(
                              emailError,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent, // Color del botón
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('REGÍSTRATE'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Text(
                          '¿Ya tienes una cuenta? Inicia sesión',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir campos de texto reutilizables
  Widget _buildTextField(String hintText, TextEditingController controller, {bool obscureText = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }
}

// Definición de la pantalla de inicio de sesión
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // Función para iniciar sesión
    void loginUser() async {
      final String email = emailController.text;
      final String password = passwordController.text;

      final FirebaseAuth auth = FirebaseAuth.instance;

      try {
        // Iniciar sesión en Firebase Auth
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        });
      }
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/background1.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'INICIO SESIÓN',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField('Email', emailController),
                    const SizedBox(height: 10),
                    _buildTextField('Contraseña', passwordController, obscureText: true),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('ACCEDER'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        '¿No tienes una cuenta? Regístrate',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir campos de texto reutilizables
  Widget _buildTextField(String hintText, TextEditingController controller, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }
}

// Definición de la página principal de la aplicación
class MyHomePage extends StatelessWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  MyHomePage({super.key});

  // Función para abrir una URL en el navegador
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Función para obtener datos del usuario actual
  Future<Map<String, String>> _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return {
        'username': userData['username'],
        'email': userData['email'],
      };
    }
    return {
      'username': 'Nombre de usuario',
      'email': 'Correo electrónico',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return DefaultTabController(
            length: 8,
            child: buildLargeScreen(context),
          );
        } else {
          return DefaultTabController(
            length: 8,
            child: buildSmallScreen(context),
          );
        }
      },
    );
  }

  // Construcción de la interfaz para pantallas pequeñas
  Scaffold buildSmallScreen(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Image.asset('images/logo_app.png', height: 70),
        backgroundColor: const Color(0xFF2E0502),
      ),
      drawer: buildDrawer(context),
      body: const TabBarView(
        children: [
          HomePageContent(),
          IAPage(),
          NuestrasMezclasPage(),
          SaboresPage(),
          CachimbaTutorialesPage(),
          CazoletaElegirPage(),
          NoticiasPage(),
          PagosPlanesPage(),
        ],
      ),
    );
  }

  // Construcción de la interfaz para pantallas grandes
  Scaffold buildLargeScreen(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Image.asset('images/logo_insta.png', height: 40),
                      onPressed: () {
                        _launchURL('https://www.instagram.com');
                      },
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Image.asset('images/logo_twitter.png', height: 40),
                      onPressed: () {
                        _launchURL('https://www.twitter.com');
                      },
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Image.asset('images/logo_tiktok.png', height: 40),
                      onPressed: () {
                        _launchURL('https://www.tiktok.com');
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: Image.asset('images/logo_usuario.gif'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/userProfile');
                  },
                ),
              ],
            ),
            const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'INICIO'),
                  Tab(text: 'IA'),
                  Tab(text: 'NUESTRAS MEZCLAS'),
                  Tab(text: 'SABORES'),
                  Tab(text: 'LA CACHIMBA Y TUTORIALES'),
                  Tab(text: 'QUE CAZOLETA ELEGIR'),
                  Tab(text: 'NOTICIAS'),
                  Tab(text: 'PAGOS Y PLANES'),
                ],
                indicatorColor: Colors.blue,
                labelColor: Color(0xFFABE7E6),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E0502),
        toolbarHeight: 120,
      ),
      body: const TabBarView(
        children: [
          HomePageContent(),
          IAPage(),
          NuestrasMezclasPage(),
          SaboresPage(),
          CachimbaTutorialesPage(),
          CazoletaElegirPage(),
          NoticiasPage(),
          PagosPlanesPage(),
        ],
      ),
    );
  }

  // Construcción del menú lateral
  Drawer buildDrawer(BuildContext context) {
    return Drawer(
      child: FutureBuilder<Map<String, String>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error cargando datos del usuario'));
          }

          var userData = snapshot.data ?? {'username': 'Nombre de usuario', 'email': 'Correo electrónico'};
          return Container(
            color: const Color(0xFF5C0A04),
            child: ListView(
              children: <Widget>[
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF800000),
                  ),
                  accountName: Text(userData['username'] ?? 'Nombre de usuario', style: const TextStyle(color: Color(0xFFABE7E6))),
                  accountEmail: Text(userData['email'] ?? 'Correo electrónico', style: const TextStyle(color: Color(0xFFABE7E6))),
                  currentAccountPicture: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserProfile()),
                      );
                    },
                    child: const CircleAvatar(
                      backgroundImage: AssetImage('images/logo_usuario.gif'),
                    ),
                  ),
                  otherAccountsPictures: <Widget>[
                    GestureDetector(
                      onTap: () {
                        _launchURL('https://www.instagram.com');
                      },
                      child: Image.asset('images/logo_insta.png', height: 40),
                    ),
                    GestureDetector(
                      onTap: () {
                        _launchURL('https://www.twitter.com');
                      },
                      child: Image.asset('images/logo_twitter.png', height: 40),
                    ),
                    GestureDetector(
                      onTap: () {
                        _launchURL('https://www.tiktok.com');
                      },
                      child: Image.asset('images/logo_tiktok.png', height: 40),
                    ),
                  ],
                ),
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white),
                  title: const Text('INICIO', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePageContent()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline, color: Colors.white),
                  title: const Text('IA', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const IAPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_drink, color: Colors.white),
                  title: const Text('NUESTRAS MEZCLAS', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NuestrasMezclasPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_cafe, color: Colors.white),
                  title: const Text('SABORES', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SaboresPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_library, color: Colors.white),
                  title: const Text('LA CACHIMBA Y TUTORIALES', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CachimbaTutorialesPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer, color: Colors.white),
                  title: const Text('QUE CAZOLETA ELEGIR', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CazoletaElegirPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.new_releases, color: Colors.white),
                  title: const Text('NOTICIAS', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NoticiasPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.white),
                  title: const Text('PAGOS Y PLANES', style: TextStyle(color: Color(0xFFABE7E6))),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PagosPlanesPage()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Clase principal para el contenido de la página de inicio
class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        // Título centrado en la barra de la aplicación
        title: const Center(
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Text(
              'CACHIMBA APP',
              style: TextStyle(
                fontFamily: 'PoetsenOne',
                color: Color(0xFFABE7E6),
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenHeight,
          ),
          child: Container(
            width: screenWidth,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/fondo_inicio.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      // Botón para "Nuestras Mezclas"
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/nuestrasMezclas');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Image.asset('images/nuestra_ia.png', width: screenWidth / 4),
                              Text(
                                'Nuestras\nMezclas',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFABE7E6),
                                  fontSize: screenWidth / 35,
                                  fontFamily: 'PoetsenOne',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Botón para "Nuestra IA"
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/nuestraIA');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Image.asset('images/nuestra_ia.png', width: screenWidth / 4),
                              Text(
                                'Nuestra\nIA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFABE7E6),
                                  fontSize: screenWidth / 35,
                                  fontFamily: 'PoetsenOne',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Botón para "Hacer Una Cachimba"
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/hacerUnaCachimba');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Image.asset('images/nuestra_ia.png', width: screenWidth / 4),
                              Text(
                                'Hacer Una\nCachimba',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFABE7E6),
                                  fontSize: screenWidth / 35,
                                  fontFamily: 'PoetsenOne',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Texto central destacado
                Container(
                  color: const Color(0xFF5C0A04),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ESTA ES LA MEJOR APLICACIÓN QUE ENCONTRARAS PARA PREPARAR Y APRENDER A HACER CACHIMBAS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFABE7E6),
                          fontSize: screenWidth < 640 ? 24 : 30,
                        ),
                      ),
                    ),
                  ),
                ),
                // Carrusel de patrocinadores
                Container(
                  height: screenWidth < 640 ? screenWidth * 0.5 : screenWidth * 0.3,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/fondo_sponsors2.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: screenWidth < 640 ? screenWidth * 0.5 : screenWidth * 0.3,
                      viewportFraction: 0.3,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 2),
                    ),
                    items: [1, 2, 3, 4, 5].map((i) {
                      return Builder(
                        builder: (BuildContext context) {
                          return Opacity(
                            opacity: 0.9,
                            child: Container(
                              width: screenWidth * 0.3,
                              height: screenWidth * 0.3,
                              margin: const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 85, 85, 85),
                                image: DecorationImage(
                                  image: AssetImage('images/logo_patro$i.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Footer
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/fondo_footer.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        if (constraints.maxWidth > 640) {
                          // Diseño para pantallas grandes (tabletas, computadoras)
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Logo
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset('images/logo_app.png', width: 150, height: 150),
                                  ],
                                ),
                              ),
                              // Información
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'INFORMACIÓN',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/politicaDePrivacidad');
                                      },
                                      child: const Text(
                                        'POLÍTICA DE PRIVACIDAD',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/terminosYCondiciones');
                                      },
                                      child: const Text(
                                        'TÉRMINOS Y CONDICIONES',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/acercaDe');
                                      },
                                      child: const Text(
                                        'ACERCA DE',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Atención al cliente
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'ATENCIÓN AL CLIENTE',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/formularioContacto');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Empresas
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'EMPRESAS',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/contactoEmpresas');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Redes sociales
                              Flexible(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Image.asset('images/logo_tiktok.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.tiktok.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset('images/logo_insta.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.instagram.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset('images/logo_twitter.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.twitter.com/');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Diseño para pantallas pequeñas (teléfonos)
                          return Column(
                            children: [
                              // Logo
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset('images/logo_app.png', width: 100, height: 100),
                              ),
                              // Información
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'INFORMACIÓN',
                                      style: TextStyle(color: Colors.black, fontSize: 20),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/politicaDePrivacidad');
                                      },
                                      child: const Text(
                                        'POLÍTICA DE PRIVACIDAD',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/terminosYCondiciones');
                                      },
                                      child: const Text(
                                        'TÉRMINOS Y CONDICIONES',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/acercaDe');
                                      },
                                      child: const Text(
                                        'ACERCA DE',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Atención al cliente
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'ATENCIÓN AL CLIENTE',
                                      style: TextStyle(color: Colors.black, fontSize: 20),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/formularioContacto');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Empresas
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'EMPRESAS',
                                      style: TextStyle(color: Colors.black, fontSize: 20),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/contactoEmpresas');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Redes sociales
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Image.asset('images/logo_tiktok.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.tiktok.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset('images/logo_insta.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.instagram.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset('images/logo_twitter.png', width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.twitter.com/');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para construir tarjetas de categoría reutilizables
  Widget _buildCategoryCard(BuildContext context, String imagePath,
      String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 150, // Aumenta el tamaño de las imágenes
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15), // Borde redondeado
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5), // Capa semitransparente
                borderRadius: BorderRadius.circular(15), // Borde redondeado
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFABE7E6),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Clase para la página "Nuestras Mezclas"
class NuestrasMezclasPage extends StatelessWidget {
  const NuestrasMezclasPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        // Título centrado en la barra de la aplicación
        title: const Center(
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
              color: Color(0xFFABE7E6),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección 1: Robot con fondo
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/fondo_mezcla.webp'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset('images/bot_sabor.png',
                      height: screenWidth < 640 ? 100 : 200),
                ),
              ),
            ),
            // Sección 2: Categorías con fondo de ladrillos
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/fondo_ladrillos.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20.0,
                  runSpacing: 20.0,
                  children: [
                    // Tarjeta de categoría "AFRUTADA"
                    _buildCategoryCard(
                      context,
                      'images/afrutada.webp',
                      'AFRUTADA',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MixCategoryPage(category: 'AFRUTADA'),
                          ),
                        );
                      },
                    ),
                    // Tarjeta de categoría "CÍTRICA"
                    _buildCategoryCard(
                      context,
                      'images/citrica.webp',
                      'CÍTRICA',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MixCategoryPage(category: 'CÍTRICA'),
                          ),
                        );
                      },
                    ),
                    // Tarjeta de categoría "DULCE"
                    _buildCategoryCard(
                      context,
                      'images/dulce.webp',
                      'DULCE',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MixCategoryPage(category: 'DULCE'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Sección 3: Carrusel con su propio fondo
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/fondo_sponsors2.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: screenWidth < 640
                        ? screenWidth * 0.5
                        : screenWidth * 0.3,
                    viewportFraction: 0.3,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 2),
                  ),
                  items: [1, 2, 3, 4, 5].map((i) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Opacity(
                          opacity: 0.9,
                          child: Container(
                            width: screenWidth * 0.3,
                            height: screenWidth * 0.3,
                            margin: const EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: const Color.fromARGB(255, 85, 85, 85),
                              image: DecorationImage(
                                image: AssetImage('images/logo_patro$i.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            // Footer
            Container(
              width: double.infinity,
              height: screenHeight * 0.2,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/fondo_footer.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth > 640) {
                    // Diseño para pantallas grandes (tabletas, computadoras)
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Flexible(
                          child: Center(
                            child: Image.asset('images/logo_app.png',
                                width: 150, height: 150),
                          ),
                        ),
                        // Información
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'INFORMACIÓN',
                                style: TextStyle(
                                  color: Colors.black, // Cambiado a color negro
                                  fontSize: 20,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/politicaDePrivacidad');
                                },
                                child: const Text(
                                  'POLÍTICA DE PRIVACIDAD',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/terminosYCondiciones');
                                },
                                child: const Text(
                                  'TÉRMINOS Y CONDICIONES',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/acercaDe');
                                },
                                child: const Text(
                                  'ACERCA DE',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Atención al cliente
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'ATENCIÓN AL CLIENTE',
                                style: TextStyle(
                                  color: Colors.black, // Cambiado a color negro
                                  fontSize: 20,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/formularioContacto');
                                },
                                child: const Text(
                                  'CONTACTO',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Empresas
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'EMPRESAS',
                                style: TextStyle(
                                  color: Colors.black, // Cambiado a color negro
                                  fontSize: 20,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/contactoEmpresas');
                                },
                                child: const Text(
                                  'CONTACTO',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Redes sociales
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Image.asset('images/logo_tiktok.png',
                                    width: 30, height: 30),
                                onPressed: () {
                                  launch('https://www.tiktok.com/');
                                },
                              ),
                              IconButton(
                                icon: Image.asset('images/logo_insta.png',
                                    width: 30, height: 30),
                                onPressed: () {
                                  launch('https://www.instagram.com/');
                                },
                              ),
                              IconButton(
                                icon: Image.asset('images/logo_twitter.png',
                                    width: 30, height: 30),
                                onPressed: () {
                                  launch('https://www.twitter.com/');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Diseño para pantallas pequeñas (teléfonos)
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Logo
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Image.asset('images/logo_app.png',
                                  width: 100, height: 100),
                            ),
                          ),
                          // Información
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'INFORMACIÓN',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20), // Cambiado a color negro
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/politicaDePrivacidad');
                                  },
                                  child: const Text(
                                    'POLÍTICA DE PRIVACIDAD',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/terminosYCondiciones');
                                  },
                                  child: const Text(
                                    'TÉRMINOS Y CONDICIONES',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/acercaDe');
                                  },
                                  child: const Text(
                                    'ACERCA DE',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Atención al cliente
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'ATENCIÓN AL CLIENTE',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20), // Cambiado a color negro
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/formularioContacto');
                                  },
                                  child: const Text(
                                    'CONTACTO',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Empresas
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'EMPRESAS',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20), // Cambiado a color negro
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/contactoEmpresas');
                                  },
                                  child: const Text(
                                    'CONTACTO',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Redes sociales
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Image.asset('images/logo_tiktok.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.tiktok.com/');
                                  },
                                ),
                                IconButton(
                                  icon: Image.asset('images/logo_insta.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.instagram.com/');
                                  },
                                ),
                                IconButton(
                                  icon: Image.asset('images/logo_twitter.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.twitter.com/');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para construir tarjetas de categoría reutilizables
  Widget _buildCategoryCard(BuildContext context, String imagePath,
      String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 150, // Aumenta el tamaño de las imágenes
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15), // Borde redondeado
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5), // Capa semitransparente
                borderRadius: BorderRadius.circular(15), // Borde redondeado
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFABE7E6),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


// Clase que define la página de categorías de mezclas.
class MixCategoryPage extends StatelessWidget {
  final String category; // Variable que almacena la categoría seleccionada.

  const MixCategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    // Variables que almacenarán la ruta de la colección y la imagen basada en la categoría.
    String collectionPath;
    String imagePath;

    // Asigna la ruta de la colección y la imagen según la categoría seleccionada.
    if (category == 'AFRUTADA') {
      collectionPath = 'mezclas/afrutadas/mezclasafrutadas';
      imagePath = 'images/afrutada.webp';
    } else if (category == 'CÍTRICA') {
      collectionPath = 'mezclas/citrica/mezclascitricas';
      imagePath = 'images/citrica.webp'; // Nombre del archivo actualizado
    } else {
      collectionPath = 'mezclas/dulce/mezclasdulces';
      imagePath = 'images/dulce.webp';
    }

    // Estructura de la interfaz de la página.
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF5C0A04), // Mismo color de fondo que "VERSION DE PRUEBA/PREMIUM"
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: const TextStyle(
                color: Color(0xFFABE7E6),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home'); // Navega a la página de inicio.
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade900,
              Colors.black,
            ],
          ),
        ),
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection(collectionPath).get(), // Obtiene datos de Firestore.
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator()); // Muestra un indicador de carga mientras espera los datos.
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}')); // Muestra un mensaje de error si ocurre algún problema.
            }
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay datos disponibles')); // Muestra un mensaje si no hay datos disponibles.
            }

            final documents = snapshot.data!.docs;

            // Construye una cuadrícula con los datos obtenidos.
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final document = documents[index];

                // Verifica si el documento tiene el campo "Nombre" y si es una lista.
                if (document.data() == null || !(document.data() as Map).containsKey('Nombre') || (document['Nombre'] is! List)) {
                  return const Text('Documento sin campo "Nombre" o formato incorrecto'); // Muestra un mensaje si hay un problema con el documento.
                }

                List<String> nombres = List<String>.from(document['Nombre']);

                return _buildMixCard(nombres, imagePath); // Construye una tarjeta con los nombres y la imagen.
              },
            );
          },
        ),
      ),
    );
  }

  // Método que construye una tarjeta de mezcla.
  Widget _buildMixCard(List<String> nombres, String imagePath) {
    return Card(
      margin: const EdgeInsets.all(10),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath), // Imagen de la categoría
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), // Fondo semitransparente para el texto
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: nombres.map((nombre) => Text(
                  nombre,
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Clase que define la página de inteligencia artificial (IA).
class IAPage extends StatelessWidget {
  const IAPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
              color: Color(0xFFABE7E6), // Cambia el color del texto
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home'); // Navega a la página de inicio.
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade900,
              Colors.black,
            ],
          ),
        ),
        child: const Column(
          children: <Widget>[
            Expanded(child: ChatList()), // Muestra la lista de chat.
            ChatInput(), // Muestra el campo de entrada del chat.
          ],
        ),
      ),
    );
  }
}


// Página principal para mostrar las opciones de sabores
class SaboresPage extends StatelessWidget {
  const SaboresPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
              color: Color(0xFFABE7E6),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/fondo_inicio.png'), // Imagen de fondo
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Image.asset('images/bot_sabor.png', height: 150), // Imagen de cabecera
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SectionTitle(
                title: 'TABACO RUBIO',
                backgroundColor: Color(0xFF5C0A04),
                textColor: Color(0xFFABE7E6),
              ),
              // Slider para tabaco rubio
              const TobaccoSlider(
                tobaccoType: 'rubio',
                images: [
                  'images/zomo.png',
                  'images/vintage.png',
                  'images/trifecta.png',
                  // ...
                ],
                marcaIds: [
                  'ZOMO',
                  'VINTAGE',
                  'TRIFECTA',
                  // ...
                ],
              ),
              const SectionTitle(
                title: 'TABACO NEGRO',
                backgroundColor: Color(0xFF5C0A04),
                textColor: Color(0xFFABE7E6),
              ),
              // Slider para tabaco negro
              const TobaccoSlider(
                tobaccoType: 'negro',
                images: [
                  'images/musthave.png',
                  'images/dozaj_black.png',
                  'images/darkside.png',
                  'images/adalya_black.png',
                ],
                marcaIds: [
                  'musthuve',
                  'dozajblack',
                  'darkside',
                  'adalya_black',
                ],
              ),
              // Carrusel de patrocinadores
              Container(
                height: screenWidth < 640 ? screenWidth * 0.5 : screenWidth * 0.3,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('images/fondo_sponsors2.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: screenWidth < 640 ? screenWidth * 0.5 : screenWidth * 0.3,
                    viewportFraction: 0.3,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 2),
                  ),
                  items: [1, 2, 3, 4, 5].map((i) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Opacity(
                          opacity: 0.9,
                          child: Container(
                            width: screenWidth * 0.3,
                            height: screenWidth * 0.3,
                            margin: const EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 85, 85, 85),
                              image: DecorationImage(
                                image: AssetImage('images/logo_patro$i.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Pie de página
              Container(
                width: double.infinity,
                height: screenHeight * 0.2,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('images/fondo_footer.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    if (constraints.maxWidth > 640) {
                      // Diseño para pantallas grandes (tabletas, computadoras)
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Flexible(
                            child: Center(
                              child: Image.asset('images/logo_app.png',
                                  width: 150, height: 150),
                            ),
                          ),
                          // Información
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'INFORMACIÓN',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/politicaDePrivacidad');
                                  },
                                  child: const Text(
                                    'POLÍTICA DE PRIVACIDAD',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/terminosYCondiciones');
                                  },
                                  child: const Text(
                                    'TÉRMINOS Y CONDICIONES',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/acercaDe');
                                  },
                                  child: const Text(
                                    'ACERCA DE',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Atención al cliente
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'ATENCIÓN AL CLIENTE',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/formularioContacto');
                                  },
                                  child: const Text(
                                    'CONTACTO',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Empresas
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'EMPRESAS',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/contactoEmpresas');
                                  },
                                  child: const Text(
                                    'CONTACTO',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Redes sociales
                          Flexible(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Image.asset('images/logo_tiktok.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.tiktok.com/');
                                  },
                                ),
                                IconButton(
                                  icon: Image.asset('images/logo_insta.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.instagram.com/');
                                  },
                                ),
                                IconButton(
                                  icon: Image.asset('images/logo_twitter.png',
                                      width: 30, height: 30),
                                  onPressed: () {
                                    launch('https://www.twitter.com/');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Diseño para pantallas pequeñas (teléfonos)
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            // Logo
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Image.asset('images/logo_app.png',
                                    width: 100, height: 100),
                              ),
                            ),
                            // Información
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'INFORMACIÓN',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/politicaDePrivacidad');
                                    },
                                    child: const Text(
                                      'POLÍTICA DE PRIVACIDAD',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/terminosYCondiciones');
                                    },
                                    child: const Text(
                                      'TÉRMINOS Y CONDICIONES',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/acercaDe');
                                    },
                                    child: const Text(
                                      'ACERCA DE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Atención al cliente
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ATENCIÓN AL CLIENTE',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/formularioContacto');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Empresas
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'EMPRESAS',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/contactoEmpresas');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Redes sociales
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Image.asset('images/logo_tiktok.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.tiktok.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_insta.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.instagram.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_twitter.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.twitter.com/');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para mostrar el título de cada sección
class SectionTitle extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final Color textColor;

  const SectionTitle({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      width: double.infinity,
      color: backgroundColor,
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// Slider para mostrar imágenes de tabaco
class TobaccoSlider extends StatefulWidget {
  final String tobaccoType; // 'rubio' o 'negro'
  final List<String> images;
  final List<String> marcaIds; // Lista de identificadores de marcas

  const TobaccoSlider({
    super.key,
    required this.tobaccoType,
    required this.images,
    required this.marcaIds,
  });

  @override
  _TobaccoSliderState createState() => _TobaccoSliderState();
}

class _TobaccoSliderState extends State<TobaccoSlider> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150, // Ajusta la altura del slider
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SaborDetailPage(
                        marcaId: widget.marcaIds[index],
                        tipoTabaco: widget.tobaccoType == 'rubio' ? 'marcas' : 'negro',
                      ),
                    ),
                  );
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          // Botón para retroceder en el slider
          Positioned(
            left: 10,
            top: 60,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                _controller.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
            ),
          ),
          // Botón para avanzar en el slider
          Positioned(
            right: 10,
            top: 60,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 30),
              onPressed: () {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Página de detalles del sabor
class SaborDetailPage extends StatelessWidget {
  final String marcaId; // Identificador de la marca
  final String tipoTabaco; // Tipo de tabaco (rubio o negro)

  const SaborDetailPage({super.key, required this.marcaId, required this.tipoTabaco});

  @override
  Widget build(BuildContext context) {
    print("Fetching data for marcaId: $marcaId, tipoTabaco: $tipoTabaco"); // Línea de depuración

    // Ajustamos la ruta de la colección para manejar la excepción de 7DAYS
    String collectionPath = (tipoTabaco == 'marcas' && marcaId == '7DAYS') ? 'Listado' : 'listado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Sabor'),
        backgroundColor: const Color(0xFF5C0A04),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5C0A04), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection(tipoTabaco)
              .doc(marcaId)
              .collection(collectionPath)
              .get()
              .then((value) {
                print("Data fetched for $marcaId: ${value.docs.length} documents");
                return value;
              }),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}')); // Mostrar error
            }
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
              print("No data available for marcaId: $marcaId"); // Línea de depuración
              return const Center(child: Text('No hay datos disponibles'));
            }
            final sabores = snapshot.data!.docs.map((doc) {
              print("Document data: ${doc.data()}"); // Línea de depuración
              return Sabor.fromMap(doc.data() as Map<String, dynamic>);
            }).toList();

            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: sabores.length,
              itemBuilder: (context, index) {
                final sabor = sabores[index];
                double fontSizeTitle = MediaQuery.of(context).size.width * 0.045; // Tamaño de la fuente para el título
                double fontSizeSubtitle = MediaQuery.of(context).size.width * 0.035; // Tamaño de la fuente para el subtítulo

                // Ajustar los nombres de archivo según las convenciones de nombres en pubspec.yaml
                String imagePath;
                switch (marcaId.toLowerCase()) {
                  case 'musthuve':
                    imagePath = 'images/musthave.png';
                    break;
                  case 'dozajblack':
                    imagePath = 'images/dozaj_black.png';
                    break;
                  case 'darkside':
                    imagePath = 'images/darkside.png';
                    break;
                  case 'adalya_black':
                    imagePath = 'images/adalya_black.png';
                    break;
                  default:
                    imagePath = 'images/${marcaId.toLowerCase()}.png';
                    break;
                }

                return Card(
                  margin: const EdgeInsets.all(10),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(imagePath), // Imagen de la marca
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5), // Fondo semitransparente para el texto
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sabor.nombre,
                                style: TextStyle(
                                  fontSize: fontSizeTitle,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                sabor.ingredientes,
                                style: TextStyle(fontSize: fontSizeSubtitle, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Clase para representar los sabores
class Sabor {
  final String nombre;
  final String ingredientes;

  Sabor({required this.nombre, required this.ingredientes});

  factory Sabor.fromMap(Map<String, dynamic> data) {
    return Sabor(
      nombre: data['Nombre'] ?? '',
      ingredientes: data['Ingredientes'] ?? '',
    );
  }
}
// Página de tutoriales de cachimbas
class CachimbaTutorialesPage extends StatelessWidget {
  const CachimbaTutorialesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
                color: Color(0xFFABE7E6)), // Cambia el color del texto
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home'); // Esto te llevará al home
          },
        ),
      ),
      body: Stack(
        children: [
          // Imagen de fondo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/backgroundN.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Contenido principal
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(
                  'images/historia.jpg',
                  fit: BoxFit.cover,
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '¿QUÉ ES UNA CACHIMBA?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'La cachimba, también conocida como shisha o hookah, es un dispositivo utilizado para fumar tabaco, generalmente de sabores. El tabaco se calienta mediante carbón y el humo se filtra a través del agua antes de ser inhalado.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
                Image.asset('images/partes_cachimba.jpg'),
                const Divider(color: Colors.white),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'COMPONENTES DE UNA CACHIMBA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '1. Base de agua: Lugar donde el agua se utiliza para enfriar y filtrar el humo.\n'
                    '2. Cuerpo (tallo): El tubo principal que conecta la base con la cabeza.\n'
                    '3. Plato: Se coloca debajo de la cabeza para recoger cenizas y exceso de tabaco.\n'
                    '4. Manguera: A través de la cual se inhala el humo.\n'
                    '5. Boquilla: Parte de la manguera por donde se inhala el humo.\n'
                    '6. Cabeza (cazoleta): Donde se coloca el tabaco y el carbón.\n'
                    '7. Válvula de purga: Permite la salida del humo viejo de la base.\n',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
                const Divider(color: Colors.white),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '¿CÓMO MONTAR UNA CACHIMBA?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: () => _launchURL('https://www.youtube.com/watch?v=nuYwU061cCI'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Image.network(
                      'https://img.youtube.com/vi/nuYwU061cCI/0.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32), // Más espacio entre el video y la siguiente sección
                const Divider(color: Colors.white),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '¿CÓMO PREPARAR UNA CACHIMBA?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: () => _launchURL('https://www.youtube.com/watch?v=ZqyUJVyi1TI'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Image.network(
                      'https://img.youtube.com/vi/ZqyUJVyi1TI/0.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32), // Más espacio entre el video y la imagen de fondo
                SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    'images/background_fuego.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Función para abrir una URL en el navegador
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}

// Página de elección de cazoleta
class CazoletaElegirPage extends StatelessWidget {
  const CazoletaElegirPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          // Alinea el texto al centro
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
                color: Color(0xFFABE7E6)), // Cambia el color del texto
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home'); // Esto te llevará a la página de inicio
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade900,
              Colors.black,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Sección sobre qué es una cazoleta
              const Section(
                title: '¿Qué es una cazoleta y para qué sirve?',
                content: 'La cazoleta es un componente fundamental de la cachimba (shisha o hookah). Es el recipiente donde se coloca el tabaco y que se calienta mediante carbones para generar el humo que posteriormente se inhala a través de la cachimba. La cazoleta puede estar fabricada de diversos materiales como arcilla, cerámica, silicona o vidrio, y viene en distintos diseños, cada uno con características específicas que afectan la experiencia de fumado.',
              ),
              // Sección sobre tipos de cazoletas con imagen
              Section(
                title: 'Tipos de Cazoletas',
                contentWidget: Column(
                  children: [
                    Center(
                      child: Image.asset(
                        'images/Tipos_de_Cazoletas.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Lógica para navegar a una nueva página con más detalles
                      },
                      child: const Text('Más detalles', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              // Sección sobre cazoletas tradicionales vs phunnel
              Section(
                title: 'Cazoletas tradicionales vs cazoletas phunnel, ¿Cuál es la diferencia?',
                contentWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cazoletas Tradicionales (Tradi)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las cazoletas tradicionales, también conocidas como cazoletas "tradi" o tradicionales, se caracterizan por su diseño clásico y simple. Suelen estar hechas de materiales como arcilla o cerámica y presentan uno o varios agujeros en el fondo. Este diseño permite que el aire pase a través del tabaco hacia la base de la cachimba.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ventajas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(context, 'Precio Asequible: Generalmente, las cazoletas tradicionales son más económicas en comparación con otros tipos, lo que las hace accesibles para la mayoría de los usuarios.'),
                    _buildBulletPoint(context, 'Flujo de Aire Directo: El diseño permite un flujo de aire más directo, lo que puede resultar en una mayor producción de humo.'),
                    _buildBulletPoint(context, 'Disponibilidad: Son fáciles de encontrar en la mayoría de las tiendas de cachimbas y vienen en una variedad de tamaños y estilos.'),
                    _buildBulletPoint(context, 'Facilidad de Uso: Son simples de usar y no requieren técnicas especiales para la carga del tabaco.'),
                    const SizedBox(height: 16),
                    Text(
                      'Desventajas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(context, 'Pérdida de Jugo: El jugo del tabaco puede filtrarse a través de los agujeros, lo que puede ensuciar la base de la cachimba y requerir más limpieza.'),
                    _buildBulletPoint(context, 'Quemado Desigual: El tabaco puede quemarse de manera desigual debido a la exposición directa al carbón, lo que puede afectar el sabor.'),
                    _buildBulletPoint(context, 'Duración de la Sesión: Las sesiones pueden ser más cortas en comparación con otros tipos de cazoletas que retienen mejor el jugo del tabaco.'),
                    const SizedBox(height: 16),
                    Text(
                      'Cazoletas Tradicionales Más Vendidas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildCazoletaInfo(
                      context,
                      'El Nefes Sultan',
                      'Esta cazoleta de origen turco es conocida por su excelente calidad y diseño auténtico. Está hecha a mano y ofrece una experiencia de fumado tradicional.',
                      'Buena retención de calor, flujo de aire óptimo, y durabilidad.',
                      'Muy valorada por los usuarios de cachimbas tradicionales.',
                      'images/Cazoleta_El_Nefes_Tradi.jpg', // Ruta de la imagen
                    ),
                    _buildCazoletaInfo(
                      context,
                      'KS Appo',
                      'Fabricada en Alemania, esta cazoleta combina diseño tradicional con innovación. Está hecha de cerámica de alta calidad y es conocida por su resistencia.',
                      'Distribución uniforme del calor, fácil de limpiar, y resistente a altas temperaturas.',
                      'Es una de las más vendidas en Europa por su rendimiento y diseño atractivo.',
                      'images/Cazoleta_KS_Appo.jpg', // Ruta de la imagen
                    ),
                    _buildCazoletaInfo(
                      context,
                      'Harmony Bowls Tradi',
                      'De origen estadounidense, estas cazoletas están hechas a mano y son conocidas por su capacidad de retención de calor y larga duración de las sesiones.',
                      'Gran capacidad de carga, excelente retención de calor, y un diseño clásico que apela a los fumadores tradicionales.',
                      'Muy popular entre los entusiastas de la cachimba por su rendimiento constante y fiable.',
                      'images/Cazoleta_Harmony_Bowls.jpg', // Ruta de la imagen
                    ),
                  ],
                ),
              ),
              // Sección sobre cazoletas tipo phunnel
              Section(
                title: 'Cazoletas tipo phunnel: Ventajas, desventajas y ejemplos',
                contentWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cazoletas Phunnel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las cazoletas tipo phunnel son un diseño más moderno y avanzado en comparación con las cazoletas tradicionales. Tienen un agujero grande en el centro que se eleva por encima del fondo de la cazoleta, lo que evita que el jugo del tabaco se derrame y se filtre hacia la base de la cachimba. Este diseño permite una experiencia de fumado más limpia y prolongada.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ventajas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(context, 'Retención de Líquidos: El diseño evita que el jugo del tabaco se derrame, lo que mantiene el tabaco húmedo por más tiempo y mejora la duración de la sesión.'),
                    _buildBulletPoint(context, 'Distribución Uniforme del Calor: Ayuda a distribuir el calor de manera más uniforme, lo que previene puntos calientes y quemaduras desiguales del tabaco.'),
                    _buildBulletPoint(context, 'Fácil de Limpiar: Al no tener múltiples agujeros en el fondo, el jugo del tabaco no se filtra a la base, lo que facilita la limpieza.'),
                    _buildBulletPoint(context, 'Mantenimiento del Sabor: Retiene mejor el sabor del tabaco durante la sesión, proporcionando una experiencia de fumado más agradable.'),
                    const SizedBox(height: 16),
                    Text(
                      'Desventajas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(context, 'Precio: Suelen ser más costosas que las cazoletas tradicionales debido a su diseño y los materiales utilizados.'),
                    _buildBulletPoint(context, 'Manejo del Calor: Requieren una técnica adecuada para manejar el calor de los carbones y evitar que el tabaco se queme demasiado rápido.'),
                    _buildBulletPoint(context, 'Peso y Tamaño: Algunas cazoletas phunnel pueden ser más pesadas y voluminosas, lo que puede hacerlas menos manejables.'),
                    const SizedBox(height: 16),
                    Text(
                      'Cazoletas Phunnel Más Vendidas:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildCazoletaInfo(
                      context,
                      'Oblako Phunnel',
                      'De origen ruso, las cazoletas Oblako son muy populares por su diseño innovador y atractivo. Están hechas de materiales de alta calidad y son conocidas por su excelente rendimiento.',
                      'Gran retención de calor, diseño estético, y alta durabilidad.',
                      'Son muy apreciadas en la comunidad de cachimbas por su eficiencia y el sabor puro que proporcionan.',
                      'images/Cazoleta_Oblako_Phunnel.jpg', // Ruta de la imagen
                    ),
                    _buildCazoletaInfo(
                      context,
                      'Alpaca Bowl Company Rook',
                      'Fabricada en Estados Unidos, la cazoleta Rook de Alpaca Bowl Company combina un diseño atractivo con una funcionalidad superior. Está hecha de una mezcla especial de arcilla que mejora la retención de calor.',
                      'Retención de calor excepcional, sesiones prolongadas, y facilidad de limpieza.',
                      'Es muy popular entre los aficionados a las cachimbas que buscan una cazoleta de alta gama.',
                      'images/Cazoleta_Alpaca_Rook.jpg', // Ruta de la imagen
                    ),
                    _buildCazoletaInfo(
                      context,
                      'HookahJohn Ferris Bowl',
                      'Esta cazoleta de HookahJohn es conocida por su diseño práctico y eficiente. Está hecha a mano y diseñada para proporcionar una experiencia de fumado óptima.',
                      'Excelente distribución del calor, fácil de usar, y proporciona una sesión de fumado suave y prolongada.',
                      'Muy valorada por los usuarios por su rendimiento constante y la calidad del material.',
                      'images/Cazoleta_HookahJohn_Ferris.jpg', // Ruta de la imagen
                    ),
                  ],
                ),
              ),
              // Sección sobre gestores de calor
              const Section(
                title: 'Gestor de Rejilla',
                content: 'El gestor de rejilla es una opción sencilla y económica para gestionar el calor en la cachimba. Consiste en una rejilla metálica que se coloca sobre la cazoleta, permitiendo que el aire circule y el carbón se mantenga encendido. Es ideal para sesiones cortas y tiene una durabilidad limitada.',
                imagePath: 'images/GC_Rejilla.jpg',
              ),
              const Section(
                title: 'Gestor de Provost',
                content: 'El Provost es un tipo de gestor de calor que se utiliza en combinación con papel de aluminio. Con una tapa ajustable, permite controlar la cantidad de aire que entra y sale, manteniendo una temperatura constante en la cazoleta. Es muy popular entre los fumadores que buscan prolongar la vida del carbón.',
                imagePath: 'images/GC_Provost.jpg',
              ),
              const Section(
                title: 'Gestor de Kaloud',
                content: 'El Kaloud es probablemente el gestor de calor más conocido y utilizado. Este dispositivo de aluminio se coloca directamente sobre la cazoleta, permitiendo una distribución uniforme del calor. Es fácil de usar y proporciona una sesión de fumado larga y consistente. Es compatible con la mayoría de las cazoletas y viene con una tapa ajustable.',
                imagePath: 'images/GC_Kaloud.jpg',
              ),
              // Imagen de fondo en la parte inferior
              SizedBox(
                width: double.infinity,
                child: AspectRatio(
                  aspectRatio: 16 / 9, // Ajusta la relación de aspecto según sea necesario
                  child: Image.asset(
                    'images/background_fuego.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      
    );
  }

  // Widget para crear puntos de viñeta en las listas
  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar información detallada de cada cazoleta
  Widget _buildCazoletaInfo(BuildContext context, String title, String description, String advantages, String popularity, String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Ventajas: $advantages',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Popularidad: $popularity',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Image.asset(imagePath, height: 140, fit: BoxFit.cover), // Aumenta ligeramente el tamaño de la imagen
        ],
      ),
    );
  }
}

// Widget para secciones reutilizables
class Section extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final String? imagePath;

  const Section({super.key, required this.title, this.content, this.contentWidget, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          content != null
              ? Text(
                  content!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                )
              : contentWidget!,
          const SizedBox(height: 16),
          imagePath != null
              ? Center(
                  child: Image.asset(imagePath!, height: 120, fit: BoxFit.cover),
                )
              : Container(),
          const SizedBox(height: 16),
          const Divider(color: Colors.white),
        ],
      ),
    );
  }
}


// Página de Noticias y Foro
class NoticiasPage extends StatefulWidget {
  const NoticiasPage({super.key});

  @override
  _NoticiasPageState createState() => _NoticiasPageState();
}

class _NoticiasPageState extends State<NoticiasPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Autenticación de Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore de Firebase
  final FirebaseStorage _storage = FirebaseStorage.instance; // Almacenamiento de Firebase
  final TextEditingController _tituloController = TextEditingController(); // Controlador de texto para el título
  final TextEditingController _descripcionController = TextEditingController(); // Controlador de texto para la descripción
  final TextEditingController _temaController = TextEditingController(); // Controlador de texto para el tema del foro
  final TextEditingController _comentarioController = TextEditingController(); // Controlador de texto para los comentarios del foro
  final ImagePicker _picker = ImagePicker(); // Selector de imágenes
  File? _imageFile; // Archivo de imagen seleccionado

  User? get currentUser => _auth.currentUser; // Obtener el usuario actual
  bool isAdmin = false; // Verificar si el usuario es administrador
  bool _loading = true; // Estado de carga
  late TabController _tabController; // Controlador de la pestaña

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Inicializar el controlador de pestañas
    _checkAdminRole(); // Verificar el rol de administrador
  }

  // Verificar si el usuario es administrador
  Future<void> _checkAdminRole() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
        if (userDoc.exists) {
          setState(() {
            isAdmin = userDoc['rol2'] == 'Admin';
          });
        }
      } catch (e) {
        print('Error checking admin role: $e');
      } finally {
        setState(() {
          _loading = false;
        });
      }
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  // Seleccionar imagen de la galería
  Future<void> _pickImage() async {
    final pickedFile = await _picker.getImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      }
    });
  }

  // Subir imagen al almacenamiento de Firebase
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storageRef = _storage.ref().child('noticias/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Crear una nueva noticia
  void _crearNoticia() async {
    if (_tituloController.text.isNotEmpty && _descripcionController.text.isNotEmpty && isAdmin) {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }
      try {
        await _firestore.collection('noticias').add({
          'titulo': _tituloController.text,
          'descripcion': _descripcionController.text,
          'fecha': Timestamp.now(),
          'autor': currentUser!.email,
          'imagen': imageUrl,
        });
        _tituloController.clear();
        _descripcionController.clear();
        setState(() {
          _imageFile = null;
        });
      } catch (e) {
        print('Error creating news: $e');
      }
    }
  }

  // Eliminar una noticia existente
  void _eliminarNoticia(String noticiaId) async {
    try {
      await _firestore.collection('noticias').doc(noticiaId).delete();
    } catch (e) {
      print('Error deleting news: $e');
    }
  }

  // Crear un nuevo tema en el foro
  void _crearTema() async {
    if (_temaController.text.isNotEmpty) {
      try {
        await _firestore.collection('foro').doc('temas').collection('temas').add({
          'titulo': _temaController.text,
          'fecha': Timestamp.now(),
          'autor': currentUser!.email,
          'comentarios': [],
        });
        _temaController.clear();
      } catch (e) {
        print('Error creating topic: $e');
      }
    }
  }

  // Agregar un comentario a un tema del foro
  void _agregarComentario(String temaId) async {
    if (_comentarioController.text.isNotEmpty) {
      try {
        await _firestore.collection('foro').doc('temas').collection('temas').doc(temaId).update({
          'comentarios': FieldValue.arrayUnion([{
            'comentario': _comentarioController.text,
            'fecha': Timestamp.now(),
            'autor': currentUser!.email,
          }])
        });
        _comentarioController.clear();
      } catch (e) {
        print('Error adding comment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'VERSIÓN DE PRUEBA/PREMIUM',
            style: TextStyle(
              color: Color(0xFFABE7E6),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNoticiasTab(),
                      _buildForoTab(),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFF5C0A04),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Noticias'),
                      Tab(text: 'Foro'),
                    ],
                    indicatorColor: const Color(0xFFABE7E6),
                    labelColor: const Color(0xFFABE7E6),
                    unselectedLabelColor: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  // Construir la pestaña de noticias
  Widget _buildNoticiasTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('noticias').orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No hay noticias disponibles'));
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              if (currentUser != null && isAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Crear Nueva Noticia',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tituloController,
                        decoration: InputDecoration(
                          labelText: 'Título de la noticia',
                          labelStyle: const TextStyle(color: Colors.black),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descripcionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción de la noticia',
                          labelStyle: const TextStyle(color: Colors.black),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_imageFile != null)
                        Image.file(_imageFile!),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo),
                        label: const Text('Subir Imagen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C0A04),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _crearNoticia,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C0A04),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Publicar Noticia'),
                      ),
                    ],
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot document = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document['titulo'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5C0A04),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            document['descripcion'],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          if (document['imagen'] != null)
                            Image.network(document['imagen']),
                          const SizedBox(height: 10),
                          Text('Por ${document['autor']} el ${document['fecha'].toDate()}'),
                        ],
                      ),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarNoticia(document.id),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Construir la pestaña del foro
  Widget _buildForoTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('foro').doc('temas').collection('temas').orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No hay temas disponibles'));
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear Nuevo Tema',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _temaController,
                      decoration: InputDecoration(
                        labelText: 'Título del tema',
                        labelStyle: const TextStyle(color: Colors.black),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _crearTema,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C0A04),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Crear Tema'),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot document = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ExpansionTile(
                      title: Text(document['titulo']),
                      subtitle: Text('Por ${document['autor']} el ${document['fecha'].toDate()}'),
                      children: [
                        for (var comentario in document['comentarios'])
                          ListTile(
                            title: Text(comentario['comentario']),
                            subtitle: Text('Por ${comentario['autor']} el ${comentario['fecha'].toDate()}'),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _comentarioController,
                                decoration: InputDecoration(
                                  labelText: 'Nuevo Comentario',
                                  labelStyle: const TextStyle(color: Colors.black),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _agregarComentario(document.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C0A04),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('Comentar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Página de planes de pago
class PagosPlanesPage extends StatelessWidget {
  const PagosPlanesPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        appBar: AppBar(
          title: const Center(
            child: Text(
              'VERSIÓN DE PRUEBA/PREMIUM',
              style: TextStyle(
                color: Color(0xFFABE7E6), // Cambia el color del texto
              ),
            ),
          ),
          backgroundColor: const Color(0xFF5C0A04),
          automaticallyImplyLeading: false, // Para evitar el botón de retroceso
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
        ),
        body: SingleChildScrollView(
            child: Container(
                width: MediaQuery.of(context).size.width, // Ajuste del ancho
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('images/billetes_pago.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(children: <Widget>[
                  const SizedBox(height: 20),
                  Image.asset(
                    'images/bot_plan.png',
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.height * 0.3,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: <Widget>[
                        buildPlanColumn(
                          context,
                          'BÁSICO',
                          'Nuestro plan básico es para ayudar a todos los que empiezan de nuevo. Este plan contiene:\n\n- 2 mezclas aseguradas cada tipo de mezcla que elijas en el caso de querer más (Plan Premium)\n\n- 3 interacciones (en el caso de que lo quieran contratar plan premium) con nuestra propia IA que realiza esta función de cachimbas',
                        ),
                        const SizedBox(height: 20),
                        buildPlanColumn(
                          context,
                          'PREMIUM',
                          'Nuestro plan premium te ahorrará mucho tiempo de pensar en qué tabacos mezclar, etc. ¿Qué contiene nuestro plan premium?\n\n- Todas nuestras mezclas disponibles\n\n- Todas las interacciones con la IA que quieras. La IA trabajará para ti como si tuvieras un cachimbero siempre disponible para ti, algo que nunca es posible y está a tu alcance.',
                          showButton: true,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
// Footer
                  Container(
                    width: double.infinity,
                    height: screenHeight * 0.2,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/fondo_footer.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        if (constraints.maxWidth > 640) {
                          // Diseño para pantallas grandes (tabletas, computadoras)
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Flexible(
                                child: Center(
                                  child: Image.asset('images/logo_app.png',
                                      width: 150, height: 150),
                                ),
                              ),
                              // Información
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'INFORMACIÓN',
                                      style: TextStyle(
                                        color: Colors
                                            .black, // Cambiado a color negro
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/politicaDePrivacidad');
                                      },
                                      child: const Text(
                                        'POLÍTICA DE PRIVACIDAD',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/terminosYCondiciones');
                                      },
                                      child: const Text(
                                        'TÉRMINOS Y CONDICIONES',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/acercaDe');
                                      },
                                      child: const Text(
                                        'ACERCA DE',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Atención al cliente
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'ATENCIÓN AL CLIENTE',
                                      style: TextStyle(
                                        color: Colors
                                            .black, // Cambiado a color negro
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/formularioContacto');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Empresas
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'EMPRESAS',
                                      style: TextStyle(
                                        color: Colors
                                            .black, // Cambiado a color negro
                                        fontSize: 20,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/contactoEmpresas');
                                      },
                                      child: const Text(
                                        'CONTACTO',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Redes sociales
                              Flexible(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Image.asset(
                                          'images/logo_tiktok.png',
                                          width: 30,
                                          height: 30),
                                      onPressed: () {
                                        launch('https://www.tiktok.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset('images/logo_insta.png',
                                          width: 30, height: 30),
                                      onPressed: () {
                                        launch('https://www.instagram.com/');
                                      },
                                    ),
                                    IconButton(
                                      icon: Image.asset(
                                          'images/logo_twitter.png',
                                          width: 30,
                                          height: 30),
                                      onPressed: () {
                                        launch('https://www.twitter.com/');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Diseño para pantallas pequeñas (teléfonos)
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // Logo
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Image.asset('images/logo_app.png',
                                        width: 100, height: 100),
                                  ),
                                ),
                                // Información
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'INFORMACIÓN',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize:
                                                20), // Cambiado a color negro
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/politicaDePrivacidad');
                                        },
                                        child: const Text(
                                          'POLÍTICA DE PRIVACIDAD',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/terminosYCondiciones');
                                        },
                                        child: const Text(
                                          'TÉRMINOS Y CONDICIONES',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/acercaDe');
                                        },
                                        child: const Text(
                                          'ACERCA DE',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Atención al cliente
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'ATENCIÓN AL CLIENTE',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize:
                                                20), // Cambiado a color negro
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/formularioContacto');
                                        },
                                        child: const Text(
                                          'CONTACTO',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Empresas
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'EMPRESAS',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize:
                                                20), // Cambiado a color negro
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/contactoEmpresas');
                                        },
                                        child: const Text(
                                          'CONTACTO',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Redes sociales
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Image.asset(
                                            'images/logo_tiktok.png',
                                            width: 30,
                                            height: 30),
                                        onPressed: () {
                                          launch('https://www.tiktok.com/');
                                        },
                                      ),
                                      IconButton(
                                        icon: Image.asset(
                                            'images/logo_insta.png',
                                            width: 30,
                                            height: 30),
                                        onPressed: () {
                                          launch('https://www.instagram.com/');
                                        },
                                      ),
                                      IconButton(
                                        icon: Image.asset(
                                            'images/logo_twitter.png',
                                            width: 30,
                                            height: 30),
                                        onPressed: () {
                                          launch('https://www.twitter.com/');
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  )
                ]))));
  }

  // Crear columna de plan de pago
  Widget buildPlanColumn(BuildContext context, String title, String content, {bool showButton = false}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFABE7E6),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.justify,
          ),
          if (showButton)
            const SizedBox(height: 10),
          if (showButton)
            ElevatedButton(
              onPressed: () {
                // Lógica del botón para actualizar a premium
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('ACTUALIZAR A PREMIUM'),
            ),
        ],
      ),
    );
  }
}




class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  String username = '';
  String email = '';
  String password = '';

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    if (user != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      setState(() {
        username = userData['username'];
        email = userData['email'];
        password = userData['password'];
      });
    } catch (e) {
      // Handle error
      print("Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'VERSION DE PRUEBA/PREMIUM',
            style: TextStyle(
              color: Color(0xFFABE7E6), // Cambia el color del texto
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5C0A04),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('images/fondo_perfil.webp'), // Ruta de la imagen de fondo
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4), BlendMode.darken),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'MI CUENTA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFABE7E6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MIS DATOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFABE7E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTextField(context, username, 'Mi Usuario:', false, 0.25),
                              Column(
                                children: [
                                  _buildTextField(context, (password), '*******', true, 0.25),
                                  const Text(
                                    'RESTABLECER\nCONTRASEÑA',
                                    style: TextStyle(
                                      color: Color(0xFFABE7E6),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              _buildTextField(context, email, 'MI EMAIL:', false, 0.25),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildTextField(context, username, 'Mi Usuario:', false, 0.8),
                              Column(
                                children: [
                                  _buildTextField(context,(password), '*******', true, 0.8),
                                  const Text(
                                    'RESTABLECER\nCONTRASEÑA',
                                    style: TextStyle(
                                      color: Color(0xFFABE7E6),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              _buildTextField(context, email, 'MI EMAIL:', false, 0.8),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MI PLAN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFABE7E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFABE7E6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Acción para comprar premium
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Color de fondo del botón
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'COMPRAR PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('images/fondo_footer.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      if (constraints.maxWidth > 640) {
                        // Diseño para pantallas grandes (tabletas, computadoras)
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Logo
                            Flexible(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('images/logo_app.png',
                                      width: 150, height: 150),
                                ],
                              ),
                            ),
                            // Información
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'INFORMACIÓN',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/politicaDePrivacidad');
                                    },
                                    child: const Text(
                                      'POLÍTICA DE PRIVACIDAD',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/terminosYCondiciones');
                                    },
                                    child: const Text(
                                      'TÉRMINOS Y CONDICIONES',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/acercaDe');
                                    },
                                    child: const Text(
                                      'ACERCA DE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Atención al cliente
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ATENCIÓN AL CLIENTE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/formularioContacto');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Empresas
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'EMPRESAS',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/contactoEmpresas');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Redes sociales
                            Flexible(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Image.asset('images/logo_tiktok.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.tiktok.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_insta.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.instagram.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_twitter.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.twitter.com/');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Diseño para pantallas pequeñas (teléfonos)
                        return Column(
                          children: [
                            // Logo
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Image.asset('images/logo_app.png',
                                    width: 100, height: 100),
                              ),
                            ),
                            // Información
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'INFORMACIÓN',
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/politicaDePrivacidad');
                                    },
                                    child: const Text(
                                      'POLÍTICA DE PRIVACIDAD',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/terminosYCondiciones');
                                    },
                                    child: const Text(
                                      'TÉRMINOS Y CONDICIONES',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/acercaDe');
                                    },
                                    child: const Text(
                                      'ACERCA DE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Atención al cliente
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ATENCIÓN AL CLIENTE',
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/formularioContacto');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Empresas
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'EMPRESAS',
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 20),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/contactoEmpresas');
                                    },
                                    child: const Text(
                                      'CONTACTO',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Redes sociales
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Image.asset('images/logo_tiktok.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.tiktok.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_insta.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.instagram.com/');
                                    },
                                  ),
                                  IconButton(
                                    icon: Image.asset('images/logo_twitter.png',
                                        width: 30, height: 30),
                                    onPressed: () {
                                      launch('https://www.twitter.com/');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para construir los campos de texto
  Widget _buildTextField(BuildContext context, String value, String label, bool obscureText, double widthFactor) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * widthFactor,
      child: TextFormField(
        initialValue: value,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFABE7E6)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFABE7E6)),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFABE7E6)),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// Widget para el pie de página
class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      height: screenHeight * 0.2,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/fondo_footer.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth <= 1300) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('images/logo_app.png',
                        width: 100, height: 100),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INFORMACIÓN',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, '/politicaDePrivacidad');
                          },
                          child: const Text(
                            'POLÍTICA DE PRIVACIDAD',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, '/terminosYCondiciones');
                          },
                          child: const Text(
                            'TÉRMINOS Y CONDICIONES',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/acercaDe');
                          },
                          child: const Text(
                            'ACERCA DE',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ATENCIÓN AL CLIENTE',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/formularioContacto');
                          },
                          child: const Text(
                            'CONTACTO',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMPRESAS',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/contactoEmpresas');
                          },
                          child: const Text(
                            'CONTACTO',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Image.asset('images/logo_tiktok.png',
                              width: 30, height: 30),
                          onPressed: () {
                            launch('https://www.tiktok.com/');
                          },
                        ),
                        IconButton(
                          icon: Image.asset('images/logo_insta.png',
                              width: 30, height: 30),
                          onPressed: () {
                            launch('https://www.instagram.com/');
                          },
                        ),
                        IconButton(
                          icon: Image.asset('images/logo_twitter.png',
                              width: 30, height: 30),
                          onPressed: () {
                            launch('https://www.twitter.com/');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: Image.asset('images/logo_app.png',
                      width: 150, height: 150),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INFORMACIÓN',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/politicaDePrivacidad');
                        },
                        child: const Text(
                          'POLÍTICA DE PRIVACIDAD',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/terminosYCondiciones');
                        },
                        child: const Text(
                          'TÉRMINOS Y CONDICIONES',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/acercaDe');
                        },
                        child: const Text(
                          'ACERCA DE',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ATENCIÓN AL CLIENTE',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/formularioContacto');
                        },
                        child: const Text(
                          'CONTACTO',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMPRESAS',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/contactoEmpresas');
                        },
                        child: const Text(
                          'CONTACTO',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Image.asset('images/logo_tiktok.png',
                            width: 30, height: 30),
                        onPressed: () {
                          launch('https://www.tiktok.com/');
                        },
                      ),
                      IconButton(
                        icon: Image.asset('images/logo_insta.png',
                            width: 30, height: 30),
                        onPressed: () {
                          launch('https://www.instagram.com/');
                        },
                      ),
                      IconButton(
                        icon: Image.asset('images/logo_twitter.png',
                            width: 30, height: 30),
                        onPressed: () {
                          launch('https://www.twitter.com/');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
