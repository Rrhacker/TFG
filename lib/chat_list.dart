import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_model.dart';

class ChatList extends StatelessWidget {
  const ChatList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatModel>(
      builder: (context, chatModel, child) {
        return ListView.builder(
          itemCount: chatModel.messages.length,
          itemBuilder: (context, index) {
            final message = chatModel.messages[index];
            final isBot = message['sender'] == 'bot';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBot)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.asset(
                        'images/bot_sabor.png', // Reemplaza con la ruta de tu imagen de robot
                        width: 40,
                        height: 40,
                      ),
                    ),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isBot ? Colors.grey[200] : Colors.blue[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        message['message']!,
                        style: TextStyle(
                          color: isBot ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isBot)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Image.asset(
                        'images/logo_usuario.gif', // Reemplaza con la ruta de tu imagen de usuario
                        width: 30,
                        height: 30,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}