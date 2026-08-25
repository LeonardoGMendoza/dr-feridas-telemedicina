const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// Configuração do CORS
app.use(cors());
app.use(express.json());

// Configuração do Socket.io para a Fila em Tempo Real
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Fila em memória (para protótipo inicial, depois passamos para o PostgreSQL)
let filaPacientes = [];

io.on('connection', (socket) => {
  console.log('Novo usuário conectado:', socket.id);

  // Enviar o status inicial da fila para quem acabou de entrar
  socket.emit('atualizacaoFila', filaPacientes);

  // Evento: Paciente entra na fila
  socket.on('entrarFila', (paciente) => {
    const novoPaciente = { id: socket.id, nome: paciente.nome, queixa: paciente.queixa, entrada: new Date() };
    filaPacientes.push(novoPaciente);
    console.log(`${paciente.nome} entrou na fila.`);
    
    // Notifica todo mundo (médicos e pacientes) que a fila atualizou
    io.emit('atualizacaoFila', filaPacientes);
  });

  // Evento: Médico puxa o próximo paciente (Remove da fila)
  socket.on('atenderProximo', (medicoId) => {
    if (filaPacientes.length > 0) {
      const pacienteAtendido = filaPacientes.shift();
      console.log(`Paciente ${pacienteAtendido.nome} encaminhado para o médico.`);
      
      // Envia uma mensagem direta para o paciente informando que é a vez dele
      io.to(pacienteAtendido.id).emit('suaVez', { medico: medicoId, salaVideo: `sala-${pacienteAtendido.id}` });
      
      // Atualiza a fila para todos os outros
      io.emit('atualizacaoFila', filaPacientes);
    }
  });

  socket.on('disconnect', () => {
    console.log('Usuário desconectado:', socket.id);
    // Remove da fila caso o paciente feche o app
    filaPacientes = filaPacientes.filter(p => p.id !== socket.id);
    io.emit('atualizacaoFila', filaPacientes);
  });
});

// Rota básica de teste
app.get('/', (req, res) => {
  res.send('API Pronto-Socorro Online Dr. Feridas operando com sucesso!');
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
