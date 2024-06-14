
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const {Configuration, OpenAIApi} = require("openai");

const openai = new OpenAIApi(
  new Configuration({
    apiKey: functions.config().openai.key
  })
);

exports.generateMix = functions.https.onRequest(async (req, res) => {
  try {
    const {userId, query} = req.body;

    if (!userId || !query) {
      return res.status(400).json({
        error: {
          message: "Missing userId or query in request body.",
          status: "INVALID_ARGUMENT"
        }
      });
    }

    // Consulta a Firestore para obtener los sabores
    const snapshot = await admin.firestore().collection("iaSabor").get();
    const sabores = snapshot.docs.map((doc) => doc.data());

    // Construir el prompt para OpenAI
    const prompt = `
      Eres un experto en cachimbas y tu tarea es crear una 
      mezcla de sabores personalizada para los usuarios basándote en 
      sus preferencias.
      Aquí tienes una lista de sabores de cachimba con sus tipos 
      e ingredientes:${sabores.map((sabor) => `Nombre: ${sabor.Nombre}, 
      Tipo: ${sabor.Tipo}, Ingredientes: ${sabor.Ingredientes}`).join("; ")}.
      Basado en esta lista, crea una única 
      mezcla de sabores para una cachimba que sea ${query}.
      La respuesta debe incluir los nombres exactos 
      de los sabores y sus ingredientes en una única mezcla.
    `;

    // Hacer la solicitud a OpenAI
    const response = await openai.createChatCompletion({
      model: "gpt-3.5-turbo",
      messages: [
        {role: "system", content: "Eres un experto en cachimbas."},
        {role: "user", content: prompt}
      ],
      max_tokens: 150
    });

    const aiResponse = response.data.choices[0].message.content.trim();
    res.status(200).json({response: aiResponse});
  } catch (error) {
    console.error("Error generating mix:", error);
    res.status(500).json({
      error: {
        message: "Internal Server Error",
        status: "INTERNAL"
      }
    });
  }
});

