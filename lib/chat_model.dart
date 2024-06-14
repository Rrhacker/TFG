import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth

class ChatModel extends ChangeNotifier {
  final List<Map<String, String>> _messages = [];
  
  List<Map<String, String>> get messages => _messages;

  void addMessage(String sender, String message) {
    _messages.add({'sender': sender, 'message': message});
    notifyListeners();
  }

  Future<void> sendMessage(String message) async {
    addMessage('user', message);

    // Procesar la solicitud y obtener la respuesta de la IA
    String response = await _getResponseFromFirebaseFunction(message);

    // Añadir la respuesta de la IA al chat
    addMessage('bot', response);
  }

  Future<String> _getResponseFromFirebaseFunction(String query) async {
    try {
      // Verificar si el usuario está autenticado
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'Por favor, inicia sesión para usar esta funcionalidad.';
      }

      // Hacer la solicitud a la función de Firebase
      var response = await http.post(
        Uri.parse('https://us-central1-mixshishaipro-2190c.cloudfunctions.net/generateMix'), // Asegúrate de que la URL es correcta
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': user.uid,
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['response'];
      } else {
        // Añadir más información de depuración
        print('Error al obtener respuesta de Firebase Function. Código de estado: ${response.statusCode}');
        print('Cuerpo de la respuesta: ${response.body}');
        return 'Error al obtener respuesta de Firebase Function. Código de estado: ${response.statusCode}';
      }
    } catch (e) {
      print('Error: $e');
      return 'Error: $e';
    }
  }
}
