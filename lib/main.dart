import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de Clientes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;
    return isLoggedIn || currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<bool>(
          future: _isSessionActive(),
          builder: (context, sessionSnap) {
            if (sessionSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && (sessionSnap.data == true)) {
              return const HomePage();
            }

            return const LoginPage();
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// PÁGINA DE LOGIN
// -----------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Guardar sesión persistente en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_email', userCredential.user?.email ?? '');
        await prefs.setString('user_uid', userCredential.user?.uid ?? '');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesión iniciada con éxito')),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Ocurrió un error al iniciar sesión';
        if (e.code == 'user-not-found') {
          message = 'No existe ningún usuario registrado con este correo.';
        } else if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-email') {
          message = 'El formato del correo es inválido.';
        } else if (e.code == 'user-disabled') {
          message = 'Este usuario ha sido deshabilitado.';
        } else if (e.code == 'invalid-credential') {
          message = 'Credenciales inválidas. Verifique su correo y contraseña.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_person,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Bienvenido',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su correo';
                    }
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Ingrese un formato de correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterPage()),
                          );
                        },
                  child: const Text('¿No tienes cuenta? Regístrate aquí'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PÁGINA DE REGISTRO
// -----------------------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_nameController.text.trim());

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'uid': user.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Guardar sesión en SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_email', user.email ?? '');
          await prefs.setString('user_uid', user.uid);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario registrado con éxito')),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Ocurrió un error al registrarse';
        if (e.code == 'weak-password') {
          message = 'La contraseña ingresada es demasiado débil.';
        } else if (e.code == 'email-already-in-use') {
          message = 'Ya existe una cuenta con este correo electrónico.';
        } else if (e.code == 'invalid-email') {
          message = 'El correo electrónico no es válido.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(
                  Icons.app_registration,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su correo';
                    }
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Ingrese un formato de correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Registrarse'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PÁGINA PRINCIPAL CON DRAWER Y NAVEGACIÓN
// -----------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final List<Widget> pages = [
      _buildInicioView(user),
      const ClientesView(),
      const ClasificacionesView(),
      const PokemonView(),
      const ContactosView(),
      const ScannerView(),
    ];

    final List<String> titles = [
      'Inicio',
      'Gestión de Clientes',
      'Clasificaciones de Clientes',
      'APIs REST Pokémon',
      'Contactos UTTEC',
      'Escáner QR y Código de Barras',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              accountName: Text(
                user?.displayName ?? 'Usuario',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.displayName ?? user?.email ?? 'U')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.blue),
              title: const Text('Inicio'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.blue),
              title: const Text('Clientes'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.blue),
              title: const Text('Clasificaciones'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.catching_pokemon, color: Colors.redAccent),
              title: const Text('APIs REST Pokémon'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts, color: Colors.green),
              title: const Text('Contactos UTTEC'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.purple),
              title: const Text('Escáner QR / Barras'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);

                // Limpiar la sesión guardada en SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('is_logged_in');
                await prefs.remove('user_email');
                await prefs.remove('user_uid');

                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
    );
  }

  Widget _buildInicioView(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola, ${user?.displayName ?? 'Usuario'}!',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Módulos de la Aplicación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clientes')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalClientes = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Card(
                      color: Colors.blue.shade50,
                      elevation: 2,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.group, size: 36, color: Colors.blue),
                              const SizedBox(height: 8),
                              const Text('Clientes',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('$totalClientes registrados',
                                  style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clasificaciones')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalCat = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Card(
                      color: Colors.indigo.shade50,
                      elevation: 2,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = 2),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.category, size: 36, color: Colors.indigo),
                              const SizedBox(height: 8),
                              const Text('Clasificaciones',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('$totalCat registradas',
                                  style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.catching_pokemon, size: 40, color: Colors.redAccent),
              title: const Text('APIs REST Pokémon'),
              subtitle: const Text('Explora Pokémon consumiendo PokéAPI en tiempo real.'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => setState(() => _selectedIndex = 3),
                child: const Text('Explorar', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.green.shade50,
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.contacts, size: 40, color: Colors.green),
              title: const Text('Contactos UTTEC'),
              subtitle: const Text('Accede a los contactos del dispositivo y envía mensajes de bienvenida por WhatsApp.'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => setState(() => _selectedIndex = 4),
                child: const Text('Contactos', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.purple.shade50,
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner, size: 40, color: Colors.purple),
              title: const Text('Escáner QR / Barras'),
              subtitle: const Text('Escanea códigos QR de la universidad y códigos de barras con la cámara.'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () => setState(() => _selectedIndex = 5),
                child: const Text('Escanear', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISTA CRUD DE CLASIFICACIONES
// -----------------------------------------------------------------------------
class ClasificacionesView extends StatefulWidget {
  const ClasificacionesView({super.key});

  @override
  State<ClasificacionesView> createState() => _ClasificacionesViewState();
}

class _ClasificacionesViewState extends State<ClasificacionesView> {
  final CollectionReference _clasificacionesRef =
      FirebaseFirestore.instance.collection('clasificaciones');
  final CollectionReference _clientesRef =
      FirebaseFirestore.instance.collection('clientes');

  void _showAssignClientsDialog(String clasificacionNombre) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Asignar Clientes a "$clasificacionNombre"'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: StreamBuilder<QuerySnapshot>(
              stream: _clientesRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clientDocs = snapshot.data!.docs;

                if (clientDocs.isEmpty) {
                  return const Center(
                    child: Text('No hay clientes registrados en Firebase.'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: clientDocs.length,
                  itemBuilder: (context, index) {
                    final clientDoc = clientDocs[index];
                    final clientData = clientDoc.data() as Map<String, dynamic>;
                    final String clientId = clientDoc.id;
                    final String clientName = clientData['nombre'] ?? 'Sin nombre';
                    final String currentCat =
                        clientData['clasificacion'] ?? 'Sin clasificación';
                    final bool isAssigned = currentCat == clasificacionNombre;

                    return CheckboxListTile(
                      value: isAssigned,
                      title: Text(clientName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isAssigned
                            ? 'Pertenece a esta categoría'
                            : 'Categoría actual: $currentCat',
                        style: TextStyle(
                          color: isAssigned ? Colors.indigo : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      activeColor: Colors.indigo,
                      onChanged: (bool? checked) async {
                        if (checked == true) {
                          await _clientesRef.doc(clientId).update({
                            'clasificacion': clasificacionNombre,
                          });
                        } else {
                          await _clientesRef.doc(clientId).update({
                            'clasificacion': 'Sin clasificación',
                          });
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  void _showFormDialog({String? docId, Map<String, dynamic>? currentData}) {
    final nameController =
        TextEditingController(text: currentData?['nombre'] ?? '');
    final descController =
        TextEditingController(text: currentData?['descripcion'] ?? '');
    final String oldName = currentData?['nombre'] ?? '';

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
              docId == null ? 'Nueva Clasificación' : 'Editar Clasificación'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Clasificación',
                      hintText: 'Ej. VIP, Frecuente, Potencial',
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (Opcional)',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(dialogContext);

                  final String newName = nameController.text.trim();
                  final data = {
                    'nombre': newName,
                    'descripcion': descController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (docId == null) {
                    data['createdAt'] = FieldValue.serverTimestamp();
                    await _clasificacionesRef.add(data);
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Clasificación guardada en Firebase')),
                    );
                  } else {
                    await _clasificacionesRef.doc(docId).update(data);

                    if (oldName.isNotEmpty && oldName != newName) {
                      final affectedClients = await _clientesRef
                          .where('clasificacion', isEqualTo: oldName)
                          .get();
                      for (var clientDoc in affectedClients.docs) {
                        await _clientesRef
                            .doc(clientDoc.id)
                            .update({'clasificacion': newName});
                      }
                    }

                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Clasificación actualizada')),
                    );
                  }
                  nav.pop();
                }
              },
              child: Text(docId == null ? 'Guardar' : 'Actualizar'),
            ),
          ],
        );
      },
    );
  }

  void _deleteClasificacion(String docId, String nombre) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Clasificación'),
          content:
              Text('¿Estás seguro de que deseas eliminar la categoría "$nombre"?\nLos clientes con esta clasificación pasarán a "Sin clasificación".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);

                await _clasificacionesRef.doc(docId).delete();

                final affectedClients = await _clientesRef
                    .where('clasificacion', isEqualTo: nombre)
                    .get();
                for (var clientDoc in affectedClients.docs) {
                  await _clientesRef
                      .doc(clientDoc.id)
                      .update({'clasificacion': 'Sin clasificación'});
                }

                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Clasificación eliminada de Firebase')),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _clasificacionesRef
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay clasificaciones registradas.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text('Presiona el botón "+" para agregar una categoría.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;
              final String catNombre = data['nombre'] ?? 'Sin Nombre';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.indigo.shade100,
                    child: const Icon(Icons.label, color: Colors.indigo),
                  ),
                  title: Text(
                    catNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['descripcion'] != null &&
                          data['descripcion'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Text(data['descripcion']),
                        ),
                      StreamBuilder<QuerySnapshot>(
                        stream: _clientesRef
                            .where('clasificacion', isEqualTo: catNombre)
                            .snapshots(),
                        builder: (context, clientSnap) {
                          int count =
                              clientSnap.hasData ? clientSnap.data!.docs.length : 0;
                          return Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Text(
                              '$count cliente${count == 1 ? '' : 's'} asignado${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.indigo.shade800,
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1,
                            color: Colors.indigo),
                        tooltip: 'Asignar Clientes',
                        onPressed: () => _showAssignClientsDialog(catNombre),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showFormDialog(docId: docId, currentData: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteClasificacion(
                            docId, catNombre),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Clasificación'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISTA CRUD DE CLIENTES
// -----------------------------------------------------------------------------
class ClientesView extends StatefulWidget {
  const ClientesView({super.key});

  @override
  State<ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends State<ClientesView> {
  final CollectionReference _clientesRef =
      FirebaseFirestore.instance.collection('clientes');
  final CollectionReference _clasificacionesRef =
      FirebaseFirestore.instance.collection('clasificaciones');

  String _selectedFilter = 'Todos';

  void _showFormDialog({String? docId, Map<String, dynamic>? currentData}) {
    final nameController =
        TextEditingController(text: currentData?['nombre'] ?? '');
    final emailController =
        TextEditingController(text: currentData?['email'] ?? '');
    final phoneController =
        TextEditingController(text: currentData?['telefono'] ?? '');
    final addressController =
        TextEditingController(text: currentData?['direccion'] ?? '');

    String selectedClasificacion =
        currentData?['clasificacion'] ?? 'Sin clasificación';

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(docId == null ? 'Agregar Cliente' : 'Editar Cliente'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Campo obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: _clasificacionesRef.snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final List<DropdownMenuItem<String>> items = [
                            const DropdownMenuItem<String>(
                              value: 'Sin clasificación',
                              child: Text('Sin clasificación'),
                            ),
                          ];

                          final catDocs = snapshot.data!.docs;
                          for (var doc in catDocs) {
                            final catData = doc.data() as Map<String, dynamic>;
                            final catNombre =
                                catData['nombre']?.toString().trim() ?? '';
                            if (catNombre.isNotEmpty &&
                                catNombre != 'Sin clasificación') {
                              items.add(DropdownMenuItem(
                                value: catNombre,
                                child: Text(catNombre),
                              ));
                            }
                          }

                          final initialValue = items.any(
                                  (item) => item.value == selectedClasificacion)
                              ? selectedClasificacion
                              : 'Sin clasificación';

                          return DropdownButtonFormField<String>(
                            initialValue: initialValue,
                            decoration: const InputDecoration(
                              labelText: 'Clasificación de Cliente',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(),
                            ),
                            items: items,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedClasificacion = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dialogContext);

                      final data = {
                        'nombre': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'telefono': phoneController.text.trim(),
                        'direccion': addressController.text.trim(),
                        'clasificacion': selectedClasificacion,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (docId == null) {
                        data['createdAt'] = FieldValue.serverTimestamp();
                        await _clientesRef.add(data);
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Cliente guardado en Firebase')),
                        );
                      } else {
                        await _clientesRef.doc(docId).update(data);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Cliente actualizado')),
                        );
                      }
                      nav.pop();
                    }
                  },
                  child: Text(docId == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCliente(String docId, String nombre) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Cliente'),
          content: Text('¿Estás seguro de que deseas eliminar a "$nombre"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                await _clientesRef.doc(docId).delete();
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Cliente eliminado de Firebase')),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _clasificacionesRef.snapshots(),
            builder: (context, snapshot) {
              final List<String> categories = ['Todos', 'Sin clasificación'];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final catData = doc.data() as Map<String, dynamic>;
                  final name = catData['nombre']?.toString().trim() ?? '';
                  if (name.isNotEmpty && !categories.contains(name)) {
                    categories.add(name);
                  }
                }
              }

              return Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final catName = categories[index];
                    final isSelected = _selectedFilter == catName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(catName),
                        selected: isSelected,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = catName;
                          });
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _clientesRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final filteredDocs = docs.where((doc) {
                  if (_selectedFilter == 'Todos') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final clasificacion =
                      data['clasificacion'] ?? 'Sin clasificación';
                  return clasificacion == _selectedFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'Todos'
                              ? 'No hay clientes registrados.'
                              : 'No hay clientes en la categoría "$_selectedFilter".',
                          style: const TextStyle(
                              fontSize: 18, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text('Presiona el botón "+" para agregar uno.'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String docId = doc.id;
                    final String clasificacion =
                        data['clasificacion'] ?? 'Sin clasificación';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            (data['nombre'] ?? 'C').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['nombre'] ?? 'Sin Nombre',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: clasificacion == 'Sin clasificación'
                                    ? Colors.grey.shade200
                                    : Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: clasificacion == 'Sin clasificación'
                                      ? Colors.grey
                                      : Colors.indigo.shade300,
                                ),
                              ),
                              child: Text(
                                clasificacion,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: clasificacion == 'Sin clasificación'
                                      ? Colors.grey.shade700
                                      : Colors.indigo,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(data['email'] ?? '',
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(data['telefono'] ?? ''),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(data['direccion'] ?? '',
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showFormDialog(
                                  docId: docId, currentData: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCliente(
                                  docId, data['nombre'] ?? 'este cliente'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar Cliente'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECCIÓN: APIs REST PÓKEMON
// -----------------------------------------------------------------------------
class PokemonView extends StatefulWidget {
  const PokemonView({super.key});

  @override
  State<PokemonView> createState() => _PokemonViewState();
}

class _PokemonViewState extends State<PokemonView> {
  late Future<List<Map<String, dynamic>>> _pokemonListFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pokemonListFuture = _fetchPokemonList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchPokemonList() async {
    final response = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=100&offset=0'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;

      return results.map((item) {
        final String name = item['name'] ?? '';
        final String url = item['url'] ?? '';
        final parts = url.split('/').where((p) => p.isNotEmpty).toList();
        final String id = parts.last;
        final String imageUrl =
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

        return {
          'id': id,
          'name': name,
          'url': url,
          'imageUrl': imageUrl,
        };
      }).toList();
    } else {
      throw Exception(
          'Error al conectar con PokéAPI (Código de estado: ${response.statusCode})');
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar Pokémon...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _pokemonListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.redAccent),
                        SizedBox(height: 16),
                        Text('Cargando lista de Pokémon desde PokéAPI...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off,
                              size: 80, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          const Text(
                            'Error de Conexión con PokéAPI',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _pokemonListFuture = _fetchPokemonList();
                              });
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Reintentar',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final pokemonList = snapshot.data ?? [];
                final filteredList = pokemonList.where((p) {
                  return p['name'].toString().toLowerCase().contains(_searchQuery) ||
                      p['id'].toString().contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron Pokémon con esa búsqueda.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _pokemonListFuture = _fetchPokemonList();
                    });
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final pokemon = filteredList[index];
                      final String id = pokemon['id'];
                      final String name = pokemon['name'];
                      final String imageUrl = pokemon['imageUrl'];

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PokemonDetailPage(
                                  pokemonId: id,
                                  pokemonName: name,
                                  imageUrl: imageUrl,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '#${id.padLeft(3, '0')}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.red.shade900),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.catching_pokemon,
                                            size: 60, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _capitalize(name),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA DE DETALLE DE PÓKEMON
// -----------------------------------------------------------------------------
class PokemonDetailPage extends StatefulWidget {
  final String pokemonId;
  final String pokemonName;
  final String imageUrl;

  const PokemonDetailPage({
    super.key,
    required this.pokemonId,
    required this.pokemonName,
    required this.imageUrl,
  });

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchPokemonDetail();
  }

  Future<Map<String, dynamic>> _fetchPokemonDetail() async {
    final response = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemonId}/'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'No se pudo obtener la información de ${widget.pokemonName}');
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.orange.shade700;
      case 'water':
        return Colors.blue;
      case 'grass':
        return Colors.green;
      case 'electric':
        return Colors.amber.shade700;
      case 'ice':
        return Colors.cyan;
      case 'fighting':
        return Colors.deepOrange;
      case 'poison':
        return Colors.purple;
      case 'ground':
        return Colors.brown;
      case 'flying':
        return Colors.indigo.shade300;
      case 'psychic':
        return Colors.pink;
      case 'bug':
        return Colors.lightGreen.shade700;
      case 'rock':
        return Colors.grey.shade700;
      case 'ghost':
        return Colors.indigo.shade900;
      case 'dragon':
        return Colors.deepPurple;
      case 'dark':
        return Colors.black87;
      case 'steel':
        return Colors.blueGrey;
      case 'fairy':
        return Colors.pink.shade200;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedName = _capitalize(widget.pokemonName);

    return Scaffold(
      appBar: AppBar(
        title: Text(formattedName),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.redAccent),
                  SizedBox(height: 16),
                  Text('Cargando detalles del Pokémon...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar detalles',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _detailFuture = _fetchPokemonDetail();
                        });
                      },
                      child: const Text('Reintentar',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final double heightMeters = (data['height'] ?? 0) / 10.0;
          final double weightKg = (data['weight'] ?? 0) / 10.0;

          final typesList = (data['types'] as List<dynamic>? ?? [])
              .map((t) => t['type']['name'].toString())
              .toList();

          final abilitiesList = (data['abilities'] as List<dynamic>? ?? [])
              .map((a) => tAbility(a))
              .toList();

          final statsList = data['stats'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade100,
                          Colors.red.shade50,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            '#${widget.pokemonId.padLeft(3, '0')}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                        Hero(
                          tag: 'pokemon_${widget.pokemonId}',
                          child: SizedBox(
                            height: 200,
                            child: Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.catching_pokemon,
                                      size: 100, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formattedName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: typesList.map((type) {
                            return Chip(
                              label: Text(
                                _capitalize(type),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: _getTypeColor(type),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.straighten,
                                color: Colors.blue, size: 30),
                            const SizedBox(height: 4),
                            const Text('Altura',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${heightMeters.toStringAsFixed(1)} m',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ],
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Column(
                          children: [
                            const Icon(Icons.fitness_center,
                                color: Colors.orange, size: 30),
                            const SizedBox(height: 4),
                            const Text('Peso',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${weightKg.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Habilidades',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: abilitiesList.map((ability) {
                            return Chip(
                              avatar: const Icon(Icons.star,
                                  size: 16, color: Colors.amber),
                              label: Text(_capitalize(ability)),
                              backgroundColor: Colors.amber.shade50,
                              side: BorderSide(color: Colors.amber.shade300),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text(
                              'Estadísticas de Base',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        ...statsList.map((st) {
                          final String statName = st['stat']['name'] ?? '';
                          final int baseStat = st['base_stat'] ?? 0;
                          final double progress =
                              (baseStat / 150.0).clamp(0.0, 1.0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatStatName(statName),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '$baseStat pts',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _getStatColor(baseStat),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String tAbility(dynamic item) {
    final name = item['ability']['name'].toString();
    final isHidden = item['is_hidden'] == true;
    return isHidden ? '$name (Oculta)' : name;
  }

  String _formatStatName(String raw) {
    switch (raw.toLowerCase()) {
      case 'hp':
        return 'Puntos de Vida (HP)';
      case 'attack':
        return 'Ataque';
      case 'defense':
        return 'Defensa';
      case 'special-attack':
        return 'Ataque Especial';
      case 'special-defense':
        return 'Defensa Especial';
      case 'speed':
        return 'Velocidad';
      default:
        return _capitalize(raw);
    }
  }

  Color _getStatColor(int val) {
    if (val < 50) return Colors.red;
    if (val < 80) return Colors.orange;
    if (val < 100) return Colors.green;
    return Colors.blue;
  }
}

// -----------------------------------------------------------------------------
// SECCIÓN: CONTACTOS Y WHATSAPP UTTEC
// -----------------------------------------------------------------------------
class ContactosView extends StatefulWidget {
  const ContactosView({super.key});

  @override
  State<ContactosView> createState() => _ContactosViewState();
}

class _ContactosViewState extends State<ContactosView> {
  List<Contact>? _contacts;
  bool _permissionDenied = false;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
        if (mounted) {
          setState(() {
            _contacts = contacts;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openWhatsApp(
      BuildContext context, String rawPhone, String contactName) async {
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El contacto no tiene un número de teléfono válido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.length == 10) {
        cleanPhone = '52$cleanPhone';
      }
    } else {
      cleanPhone = cleanPhone.substring(1);
    }

    const String message =
        'Bienvenido a la UTTEC, en los próximos días recibirás más información acerca de la carrera.';
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUri =
        Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      bool launched =
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final Uri fallbackUri =
            Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir WhatsApp para $contactName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showContactDetailModal(Contact contact) {
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : 'Sin número disponible';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green.shade100,
                backgroundImage:
                    contact.photo != null ? MemoryImage(contact.photo!) : null,
                child: contact.photo == null
                    ? Text(
                        (contact.displayName.isNotEmpty
                                ? contact.displayName[0]
                                : 'C')
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                contact.displayName.isNotEmpty
                    ? contact.displayName
                    : 'Contacto sin nombre',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    phone,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send),
                label: const Text(
                  'Enviar Bienvenida UTTEC por WhatsApp',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  if (contact.phones.isNotEmpty) {
                    _openWhatsApp(context, phone, contact.displayName);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Este contacto no tiene un número asignado.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Obteniendo contactos del dispositivo...'),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts, size: 80, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'Permiso de Contactos Requerido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para enviar el mensaje de bienvenida de la UTTEC, la aplicación necesita acceso a los contactos almacenados en tu dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _fetchContacts,
                icon: const Icon(Icons.security),
                label: const Text('Conceder Permisos'),
              ),
            ],
          ),
        ),
      );
    }

    final contactsList = _contacts ?? [];
    final filteredContacts = contactsList.where((c) {
      final nameMatches =
          c.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatches = c.phones.any((p) => p.number.contains(_searchQuery));
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar contacto...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
          Expanded(
            child: filteredContacts.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron contactos.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final String phone = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : 'Sin número';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => _showContactDetailModal(contact),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green.shade100,
                            backgroundImage: contact.photo != null
                                ? MemoryImage(contact.photo!)
                                : null,
                            child: contact.photo == null
                                ? Text(
                                    (contact.displayName.isNotEmpty
                                            ? contact.displayName[0]
                                            : 'C')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  )
                                : null,
                          ),
                          title: Text(
                            contact.displayName.isNotEmpty
                                ? contact.displayName
                                : 'Sin Nombre',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            phone,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.message, size: 18),
                            label: const Text('WhatsApp'),
                            onPressed: () {
                              if (contact.phones.isNotEmpty) {
                                _openWhatsApp(
                                    context, phone, contact.displayName);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'El contacto no tiene número telefónico.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECCIÓN: ESCÁNER QR Y CÓDIGO DE BARRAS
// -----------------------------------------------------------------------------
class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  String? _scannedValue;
  String? _scannedFormat;
  bool _isUrl = false;

  Future<void> _startScan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );

    if (result != null && mounted) {
      final String val = result['value'] ?? '';
      final String fmt = result['format'] ?? 'DESCONOCIDO';
      final bool urlFlag = result['isUrl'] == true;

      setState(() {
        _scannedValue = val;
        _scannedFormat = fmt;
        _isUrl = urlFlag;
      });

      if (urlFlag) {
        _openScannedUrl(val);
      }
    }
  }

  Future<void> _openScannedUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      bool launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la URL: $url ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lector de Códigos QR y Barras',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escanea códigos QR con enlaces web (como la URL oficial de la UTTEC) o códigos de barras de credenciales y productos.',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Activar Lector de Cámara',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _startScan,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_scannedValue != null) ...[
            Card(
              elevation: 4,
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.purple.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isUrl ? Icons.link : Icons.bar_chart,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Resultado Detectado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Tipo / Formato de Código:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _scannedFormat ?? 'DESCONOCIDO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Valor Leído:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _scannedValue!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isUrl)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Abrir URL en Navegador Web'),
                        onPressed: () => _openScannedUrl(_scannedValue!),
                      ),
                    if (!_isUrl)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Valor al Portapapeles'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _scannedValue!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Valor copiado al portapapeles.'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ] else
            Card(
              color: Colors.grey.shade100,
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Aún no se ha escaneado ningún código.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isHandled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandled) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final Barcode barcode = barcodes.first;
    final String? rawValue = barcode.rawValue;

    if (rawValue != null && rawValue.trim().isNotEmpty) {
      _isHandled = true;

      final String formatName = barcode.format.name.toUpperCase();
      final bool isUrl = Uri.tryParse(rawValue)?.hasAbsolutePath == true &&
          (rawValue.startsWith('http://') || rawValue.startsWith('https://'));

      Navigator.pop(context, {
        'value': rawValue,
        'format': formatName,
        'isUrl': isUrl,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.white70);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purpleAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
