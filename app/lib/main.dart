import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProntoSocorroApp());
}

class ProntoSocorroApp extends StatelessWidget {
  const ProntoSocorroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pronto-Socorro Dr. Feridas',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const LoginScreen(), // Agora começa na tela de Login!
      debugShowCheckedModeBanner: false,
    );
  }
}

class FilaEsperaScreen extends StatefulWidget {
  const FilaEsperaScreen({super.key});

  @override
  State<FilaEsperaScreen> createState() => _FilaEsperaScreenState();
}

class _FilaEsperaScreenState extends State<FilaEsperaScreen> {
  late IO.Socket socket;
  bool naFila = false;
  int minhaPosicao = 0;
  int totalFila = 0;
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _queixaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    conectarServidor();
  }

  void conectarServidor() {
    // Conecta ao servidor Node.js local (ajustar IP se rodar no celular físico)
    socket = IO.io('http://localhost:3000', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    socket.connect();

    socket.onConnect((_) {
      print('Conectado ao Servidor do Pronto-Socorro');
    });

    socket.on('atualizacaoFila', (dados) {
      if (mounted) {
        setState(() {
          List fila = dados as List;
          totalFila = fila.length;
          
          if (naFila) {
            // Acha a posição do usuário atual na fila
            int pos = fila.indexWhere((p) => p['id'] == socket.id);
            if (pos != -1) {
              minhaPosicao = pos + 1; // +1 porque índice começa em 0
            }
          }
        });
      }
    });

    socket.on('suaVez', (dados) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Chegou sua vez!', style: TextStyle(color: Colors.green)),
            content: const Text('O médico está pronto para iniciar a chamada de vídeo.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha o aviso
                  // Aqui futuramente abrirá a tela do Jitsi Meet (Vídeo)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abrindo câmera e microfone...')),
                  );
                },
                child: const Text('Entrar na Consulta'),
              )
            ],
          )
        );
      }
    });
  }

  void entrarNaFila() {
    if (_nomeController.text.isEmpty) return;
    
    socket.emit('entrarFila', {
      'nome': _nomeController.text,
      'queixa': _queixaController.text.isEmpty ? 'Avaliação Geral' : _queixaController.text
    });

    setState(() {
      naFila = true;
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pronto-Socorro Online', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: !naFila ? _buildFormularioEntrada() : _buildPainelFila(),
        ),
      ),
    );
  }

  Widget _buildFormularioEntrada() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_hospital, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Bem-vindo à Dr. Feridas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preencha seus dados para entrar na fila de triagem médica virtual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Seu Nome Completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _queixaController,
              decoration: const InputDecoration(
                labelText: 'Qual é a sua queixa ou ferida? (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.healing),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: entrarNaFila,
                child: const Text('ENTRAR NA FILA AGORA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPainelFila() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Aguarde o seu atendimento...',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 40),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.red, width: 8),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('SUA POSIÇÃO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(
                '$minhaPosicaoº',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('Total de pacientes aguardando agora: $totalFila', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '👨‍⚕️ Fique tranquilo! Nossos médicos (Dr. Evandro, Dra. Glória e equipe) já estão analisando a fila. Você será chamado em instantes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
