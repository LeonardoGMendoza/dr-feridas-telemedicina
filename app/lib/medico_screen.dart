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

  // Banco de Dados Falso (Mock) de Prontuários
  String obterHistorico(String? nome) {
    if (nome == null) return 'Sem histórico localizado.';
    
    // Convertemos para minúsculo para facilitar a busca
    String nomeBusca = nome.toLowerCase();

    if (nomeBusca.contains('leonardo')) {
      return 'Paciente diabético tipo 2. Última consulta em Dez/2025 para tratar úlcera venosa na perna direita. Alérgico a penicilina.';
    } else if (nomeBusca.contains('sandra')) {
      return 'Hipertensa controlada. Tratamento contínuo de ferida cirúrgica no abdômen. Última troca de curativo: há 2 dias.';
    } else if (nomeBusca.contains('bruno')) {
      return 'Sem histórico de doenças crônicas no sistema. Primeira consulta de triagem.';
    }
    
    return 'Primeiro atendimento no sistema (Sem histórico).';
  }

  @override
  void initState() {
    super.initState();
    conectarServidor();
  }

  void conectarServidor() {
    socket = IO.io('https://dr-feridas-telemedicina.onrender.com', IO.OptionBuilder()
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

    // O servidor cuidará de encaminhar o paciente
  }

  void chamarProximo() {
    if (filaPacientes.isNotEmpty) {
      // 1. Pegamos o ID do primeiro paciente para gerar a mesma sala que o servidor gera
      final pacienteId = filaPacientes.first['id'];
      final salaVideo = 'dr-feridas-$pacienteId';

      // 2. Avisamos o servidor para tirar ele da fila e mandar o paciente para a sala
      socket.emit('atenderProximo', 'Dr. Evandro');
      
      // 3. O médico abre a sala IMEDIATAMENTE no momento do clique!
      // Isso dribla o bloqueador de pop-ups do iPhone (Safari), que bloqueia links
      // se não forem clicados diretamente pelo usuário.
      final url = Uri.parse('https://meet.ffmuc.net/$salaVideo?config.disableDeepLinking=true');
      launchUrl(url, mode: LaunchMode.externalApplication);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abrindo sala de vídeo...'),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Motivo Hoje: ${paciente['queixa']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Historico (Prontuario):\n${obterHistorico(paciente['nome'])}',
                                    style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
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
