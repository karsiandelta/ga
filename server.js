const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');

// Crear la aplicación Express
const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Servir los archivos estáticos (CSS, JS, imágenes, etc.)
app.use(express.static(path.join(__dirname, 'static')));

// Página principal (index.html)
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'templates', 'index.html'));
});

// Manejando conexiones de Socket.IO
io.on('connection', (socket) => {
    console.log('Un usuario se ha conectado');

    // Evento para unirse a un canal
    socket.on('join room', (room) => {
        socket.join(room);
        console.log(`Usuario se unió al canal: ${room}`);
        socket.emit('chat message', `Te has unido al canal: ${room}`);
    });

    // Enviar mensaje al canal específico
    socket.on('chat message', (msg, room) => {
        io.to(room).emit('chat message', msg); // Emitir solo a los usuarios del canal
    });

    // Evento de desconexión
    socket.on('disconnect', () => {
        console.log('Un usuario se ha desconectado');
    });
});

// Configuración del servidor
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
    console.log(`Servidor corriendo en el puerto ${PORT}`);
});
