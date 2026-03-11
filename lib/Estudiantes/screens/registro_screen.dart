import 'package:flutter/material.dart';
import 'package:gestion_dormitorios/services/auth_service.dart';
import 'package:gestion_dormitorios/Estudiantes/models/institutional_user.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final matriculaCtrl = TextEditingController();
  final emailVerifyCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  // Estado
  int _currentStep = 0; // 0:Buscar, 1:Datos, 2:Código, 3:Pass
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  InstitutionalUser? _foundUser;

  // --- LOGICA ---

  // Paso 0: Buscar en API Profesor y VALIDAR ACCESO
  void _searchUser() async {
    if (matriculaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una matrícula')));
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    // 1. Buscamos los datos básicos (Nombre, correo, etc)
    final user = await _authService.checkInstitutionalUser(matriculaCtrl.text.trim());

    if (user != null) {
      // Deducir Rol temporalmente para la validación
      int rol = 3; // Estudiante por defecto
      String idParaValidar = user.matricula.toString();
      
      if (user.numEmpleado != null && user.numEmpleado! > 0) {
        rol = 1; // Preceptor
        idParaValidar = user.numEmpleado.toString();
      }

      // 2. AHORA VALIDAMOS EL ACCESO CON TU BACKEND (NUEVO)
      final acceso = await _authService.checkAccess(idParaValidar, rol);

      setState(() => _isLoading = false);

      if (acceso['success'] == true) {
        // SI TIENE PERMISO, AVANZAMOS
        setState(() {
          _foundUser = user;
          _currentStep = 1; // Pasamos a verificar correo
        });
      } else {
        // NO TIENE PERMISO (Externo o Depto incorrecto)
        // Mostramos Alerta Roja y NO avanzamos
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(acceso['message'] ?? 'Acceso denegado'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          )
        );
      }

    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario no encontrado en la API escolar.')));
    }
  }
  // Paso 1: Verificar Correo
 void _verifyEmail() async {
    if (_foundUser == null) return;
    
    // Validación de correo
    if (emailVerifyCtrl.text.trim().toLowerCase() != _foundUser!.correoInstitucional.toLowerCase()) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El correo no coincide con el registro oficial.')));
       return;
    }

    setState(() => _isLoading = true);
    
    // --- CAMBIO AQUÍ: LLAMADA REAL ---
    final enviado = await _authService.sendOtpToEmail(emailVerifyCtrl.text.trim());

    setState(() => _isLoading = false);

    if (enviado) {
      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Código enviado! Revisa tu correo institucional.'))
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar el código. Intenta de nuevo.'))
      );
    }
  }

// Paso 2: Validar Código REAL
  void _validateCode() async {
    if (codeCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // --- CAMBIO AQUÍ: VALIDACIÓN REAL ---
    final esValido = await _authService.verifyOtpCode(
      emailVerifyCtrl.text.trim(), 
      codeCtrl.text.trim()
    );

    setState(() => _isLoading = false);

    if (esValido) {
      // Si es válido, pasamos al siguiente paso
      setState(() => _currentStep = 3);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código correcto.'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código incorrecto o expirado.'), backgroundColor: Colors.red)
      );
    }
  }

// Paso 3: Guardar en TU Base de Datos SQL
  void _finalizeRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Deducir Rol
    int rol = 3; // Estudiante
    if (_foundUser!.numEmpleado != null && _foundUser!.numEmpleado! > 0) {
      rol = 1; // Preceptor
    }

    String idAGuardar = (_foundUser!.matricula ?? _foundUser!.numEmpleado).toString();
    
    // --- AQUÍ ESTÁ LA MAGIA ---
    // Usamos los datos que ya bajamos de la API del profe para llenar tu BD
    final result = await _authService.register(
      usuarioID: idAGuardar, 
      password: passCtrl.text.trim(), 
      idRol: rol,
      nombre: '${_foundUser!.nombre} ${_foundUser!.apellidos}', // Nombre completo armado
      carrera: _foundUser!.leNombreEscuelaOficial ?? 'No especificada',
      correo: _foundUser!.correoInstitucional
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      
      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cuenta creada con éxito! Tus datos han sido sincronizados.'))
      );
      
      // Regresamos al Login para que entre
      Navigator.pop(context); 
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al registrar'), backgroundColor: Colors.red)
      );
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
             if (_currentStep > 0) setState(() => _currentStep--);
             else Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
             Image.asset('assets/logoulv.png', height: 100),
             const SizedBox(height: 10),
             const Text('HOGAR DE VARONES\nUNIVERSITARIOS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             const SizedBox(height: 25),

             Container(
               margin: const EdgeInsets.symmetric(horizontal: 20),
               padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
               decoration: BoxDecoration(
                 color: const Color(0xFF002D62),
                 borderRadius: BorderRadius.circular(30)
               ),
               child: _isLoading 
                 ? const Center(child: CircularProgressIndicator(color: Colors.white))
                 : Form(key: _formKey, child: _buildStepContent()),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _step0Search();
      case 1: return _step1Verify();
      case 2: return _step2Code();
      case 3: return _step3Pass();
      default: return Container();
    }
  }

  // UI Pasos
  Widget _step0Search() {
    return Column(
      children: [
        const Text('Registro', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _field(matriculaCtrl, 'Matrícula / No. de Colaborador', Icons.person_search),
        const SizedBox(height: 20),
        _btn('BUSCAR', _searchUser)
      ],
    );
  }

  Widget _step1Verify() {
    final u = _foundUser!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Text('Verifica tus datos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 15),
        _row('Nombre:', '${u.nombre} ${u.apellidos}'),
        _row('ID:', (u.matricula ?? u.numEmpleado).toString()),
        _row('Carrera:', u.leNombreEscuelaOficial ?? ''),
        _row('Correo:', u.correoOculto),
        
        const SizedBox(height: 20),
        const Text('Confirma tu correo completo:', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        _field(emailVerifyCtrl, 'Correo Institucional', Icons.email),
        const SizedBox(height: 20),
        _btn('ES MI CORREO', _verifyEmail)
      ],
    );
  }

  Widget _step2Code() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read, color: Colors.white, size: 60),
        const SizedBox(height: 20),
        Text('Código enviado a:\n${_foundUser?.correoOculto}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 20),
        _field(codeCtrl, 'Código (1234)', Icons.pin, isNumber: true),
        const SizedBox(height: 20),
        _btn('VALIDAR', _validateCode)
      ],
    );
  }

  Widget _step3Pass() {
    return Column(
      children: [
        const Text('Crea tu Contraseña', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _passField(passCtrl, 'Contraseña', _obscurePass, () => setState(()=>_obscurePass=!_obscurePass)),
        const SizedBox(height: 15),
        _passField(confirmPassCtrl, 'Confirmar Contraseña', _obscureConfirm, () => setState(()=>_obscureConfirm=!_obscureConfirm)),
        const SizedBox(height: 30),
        _btn('FINALIZAR REGISTRO', _finalizeRegister)
      ],
    );
  }

  // Widgets pequeños
  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [Text('$l ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), Expanded(child: Text(v, style: const TextStyle(color: Colors.white)))]));
  
  Widget _field(TextEditingController c, String l, IconData i, {bool isNumber = false}) {
    return TextFormField(
      controller: c, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(filled: true, fillColor: Colors.white, prefixIcon: Icon(i), labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
    );
  }

  Widget _passField(TextEditingController c, String l, bool obs, VoidCallback toggle) {
    return TextFormField(
      controller: c, obscureText: obs,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (l.contains('Confirmar') && v != passCtrl.text) return 'No coinciden';
        if (v.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
      decoration: InputDecoration(
        filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.lock), labelText: l,
        suffixIcon: IconButton(icon: Icon(obs ? Icons.visibility_off : Icons.visibility), onPressed: toggle),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
      )
    );
  }

  Widget _btn(String t, VoidCallback p) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: p, style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold))));
}