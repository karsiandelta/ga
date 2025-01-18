const socket = io(); // Inicializa la conexión con el servidor

const messagesDiv = document.getElementById("messages");
const form = document.getElementById("message-form");
const input = document.getElementById("message-input");

// Escuchar mensajes desde el servidor
socket.on("message", (message) => {
    const msg = document.createElement("div");
    msg.textContent = message;
    messagesDiv.appendChild(msg);
    messagesDiv.scrollTop = messagesDiv.scrollHeight; // Scroll al final
});

// Enviar mensajes al servidor
form.addEventListener("submit", (e) => {
    e.preventDefault();
    if (input.value) {
        socket.emit("message", input.value);
        input.value = "";
    }
});
