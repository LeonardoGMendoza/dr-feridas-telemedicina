import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'main.dart'; // Para acessar o FilaEsperaScreen
import 'medico_screen.dart'; // Para acessar o Painel Médico

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String _erro = '';

  Future<void> _autenticarEmailSenha() async {
    setState(() {
      _loading = true;
      _erro = '';
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilaEsperaScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erro = e.message ?? 'Ocorreu um erro de autenticação.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() {
      _loading = true;
      _erro = '';
    });

    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FilaEsperaScreen()),
          );
        }
      } else {
        setState(() {
          _erro = 'O Login do Google no Android requer configurações extras. Por favor, teste no Chrome por enquanto!';
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro ao logar com o Google: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _isLogin ? 'Acesso ao Paciente' : 'Criar Conta',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pronto-Socorro Online Dr. Feridas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      if (_erro.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_erro, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _loading ? null : _autenticarEmailSenha,
                          child: _loading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_isLogin ? 'ENTRAR' : 'CADASTRAR', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _loading ? null : _loginComGoogle,
                          icon: Image.network('https://cdn-icons-png.flaticon.com/512/2991/2991148.png', height: 24),
                          label: const Text('Entrar com o Google', style: TextStyle(fontSize: 16, color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _erro = '';
                          });
                        },
                        child: Text(
                          _isLogin ? 'Não tem conta? Cadastre-se aqui' : 'Já tem conta? Faça login',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const Divider(height: 32),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MedicoScreen()),
                          );
                        },
                        icon: const Icon(Icons.medical_services, color: Colors.blue),
                        label: const Text('Acesso Restrito (Médicos)', style: TextStyle(color: Colors.blue)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

