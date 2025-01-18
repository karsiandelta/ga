// Establecer la conexión con el servidor
const socket = io();

// Referencias a los elementos del DOM
const messageForm = document.getElementById("message-form");
const messageInput = document.getElementById("message-input");
const messagesContainer = document.getElementById("messages");
const channelSelect = document.getElementById("channel-select");

// Unirse al canal seleccionado al cargar
let currentRoom = "bienvenida"; // Canal por defecto
socket.emit('join room', currentRoom);

// Cambiar de canal
channelSelect.addEventListener("change", (e) => {
    const newRoom = e.target.value;
    if (newRoom !== currentRoom) {
        socket.emit('join room', newRoom);  // Unirse al nuevo canal
        currentRoom = newRoom;
        messagesContainer.innerHTML = ''; // Limpiar el chat
        updateChatStyle(newRoom); // Actualizar el estilo de acuerdo al canal
    }
});

// Enviar mensaje al canal seleccionado
messageForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const message = messageInput.value;

    if (message.trim() !== "") {
        socket.emit("chat message", message, currentRoom); // Enviar al canal actual
        messageInput.value = "";
    }
});

// Recibir mensajes del servidor
socket.on("chat message", (msg) => {
    const messageElement = document.createElement("div");
    messageElement.textContent = msg;
    messageElement.style.backgroundColor = getChannelColor(currentRoom); // Colocar el color adecuado
    messagesContainer.appendChild(messageElement);

    messagesContainer.scrollTop = messagesContainer.scrollHeight;
});

// Función para obtener el color del canal
function getChannelColor(room) {
    if (room === "bienvenida") {
        return "#cce7ff"; // Azul claro
    } else if (room === "amigos") {
        return "#dfffd6"; // Verde claro
    } else if (room === "libre") {
        return "#fff3d6"; // Naranja suave
    }
    return "#fafafa"; // Color por defecto
}

// Actualizar el estilo de la conversación
function updateChatStyle(room) {
    const color = getChannelColor(room);
    messagesContainer.style.backgroundColor = color;
}
