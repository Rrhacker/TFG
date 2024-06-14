import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_model.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      color: const Color(0xFF5C0A04),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '¿Qué quieres fumar?',
                hintStyle: const TextStyle(color: Color(0xFFABE7E6)), // Color del texto del hint
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(color: Color(0xFFABE7E6)), // Color del texto ingresado
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFABE7E6)), // Color del icono
            onPressed: () {
              String message = controller.text;
              if (message.isNotEmpty) {
                Provider.of<ChatModel>(context, listen: false).sendMessage(message);
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}