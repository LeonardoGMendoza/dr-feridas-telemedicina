import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';

class MedicoScreen extends StatefulWidget {
  const MedicoScreen({super.key});

  @override
  State<MedicoScreen> createState() => _MedicoScreenState();
}

class _MedicoScreenState extends State<MedicoScreen> {
  late IO.Socket socket;
  List filaPacientes = [];

  @override
  void initState() {
    super.initState();
    conectarServidor();
  }

  void conectarServidor() {
    socket = IO.io('http://localhost:3000', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    socket.connect();

    socket.onConnect((_) {
      print('Médico conectado ao servidor');
    });

    socket.on('atualizacaoFila', (dados) {
      if (mounted) {
        setState(() {
          filaPacientes = dados as List;
        });
      }
    });

    // O servidor manda o link do vídeo de volta pro médico também
    socket.on('entrarNaSalaMedico', (dados) async {
      String salaVideo = dados['salaVideo'];
      
      final url = Uri.parse('https://meet.jit.si/$salaVideo');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    });
  }

  void chamarProximo() {
    if (filaPacientes.isNotEmpty) {
      socket.emit('atenderProximo', 'Dr. Evandro');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente chamado! Abrindo sala de vídeo...'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Painel Médico - Dr. Feridas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800], // Azul para diferenciar do paciente (Vermelho)
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fila de Triagem',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${filaPacientes.length} aguardando',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filaPacientes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.coffee, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Nenhum paciente na fila.', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filaPacientes.length,
                      itemBuilder: (context, index) {
                        final paciente = filaPacientes[index];
                        final isPrimeiro = index == 0;

                        return Card(
                          elevation: isPrimeiro ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isPrimeiro ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: isPrimeiro ? Colors.blue : Colors.grey[300],
                              radius: 30,
                              child: Text(
                                '${index + 1}º',
                                style: TextStyle(color: isPrimeiro ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                            title: Text(paciente['nome'] ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('Queixa: ${paciente['queixa']}'),
                            ),
                            trailing: isPrimeiro
                                ? ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    onPressed: chamarProximo,
                                    icon: const Icon(Icons.video_call, color: Colors.white),
                                    label: const Text('CHAMAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
