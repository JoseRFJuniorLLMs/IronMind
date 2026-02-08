importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyCiixeeaJd7GtQ1ml-_F46YiMCGYiLyytw",
    authDomain: "eva-push-01.firebaseapp.com",
    projectId: "eva-push-01",
    storageBucket: "eva-push-01.firebasestorage.app",
    messagingSenderId: "1017997949026",
    appId: "1:1017997949026:web:7cffacd452dadfecda793b",
});

const messaging = firebase.messaging();

// Opcional: Manipular notificações em segundo plano
messaging.onBackgroundMessage((payload) => {
    console.log("Recebi mensagem em background: ", payload);
});