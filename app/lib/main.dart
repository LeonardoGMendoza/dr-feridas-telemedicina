import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart'; // PACOTE DE VÍDEO
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
    // Conecta ao servidor Node.js no Render
    socket = IO.io('https://dr-feridas-telemedicina.onrender.com', IO.OptionBuilder()
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
        String salaVideo = dados['salaVideo'];
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Chegou sua vez!', style: TextStyle(color: Colors.green)),
            content: const Text('O médico está pronto para iniciar a chamada de vídeo.'),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Fecha o aviso
                  
                  // Tira da fila da interface
                  setState(() {
                    naFila = false;
                  });

                  // Abre a câmera num servidor Jitsi livre sem login e força abrir no navegador
                  final url = Uri.parse('https://meet.ffmuc.net/$salaVideo?config.disableDeepLinking=true');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro ao abrir o vídeo. Tente novamente.')),
                    );
                  }
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
    final user = FirebaseAuth.instance.currentUser;
    final nomePaciente = user?.displayName ?? user?.email?.split('@')[0] ?? 'Paciente';

    return Center(
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
                  const Icon(Icons.local_hospital, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Olá, $nomePaciente!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por favor, descreva o que está sentindo hoje para que o médico possa se preparar.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _queixaController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Sintomas / Motivo da Consulta',
                      border: OutlineInputBorder(),
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
                      onPressed: () {
                        // REMOVIDA A TRAVA! Agora o paciente não é obrigado a digitar nada.
                        // Pode simplesmente entrar na fila com 1 clique.
                        String queixaFinal = _queixaController.text.trim();
                        if (queixaFinal.isEmpty) {
                          queixaFinal = 'Retorno / Consulta de Rotina (Prontuário já preenchido)';
                        }

                        // O paciente pede para entrar na fila informando o nome (automático) e a queixa
                        socket.emit('entrarFila', {
                          'nome': nomePaciente,
                          'queixa': queixaFinal,
                        });

                        setState(() {
                          naFila = true;
                        });
                      },
                      child: const Text('ENTRAR NA FILA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
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
        // NOVO: Painel de alinhamento de expectativa (Médicos de Plantão)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Equipe de Plantão Hoje',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• Dr. Evandro\n• Dra. Glória\n• Dr. Alexander\n• Dr. Leonardo',
                    style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Para garantir o seu atendimento o mais rápido possível, você será chamado(a) pelo primeiro especialista que ficar livre.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
