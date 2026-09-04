import 'package:google_generative_ai/google_generative_ai.dart';
import 'config_service.dart';

class AiService {
  late final GenerativeModel _model;
  ChatSession? _chat;

  AiService() {
    _model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: ConfigService.geminiApiKey,
      systemInstruction: Content.system(
          'You are the CarDecide AI Assistant, an expert in the Malaysian automotive market and public transportation. '
          'Your role is to help users decide whether to buy a car, and which one, using data-backed insights. '
          'You favor fuel-efficient, Hybrid, and EV recommendations to support SDG 9. '
          'When answering, you must: '
          '1. Recommend cars based on real registration trends and fuel types in Malaysia. '
          '2. Nudge users to consider public transport (LRT/MRT/RapidKL) for city commutes. '
          '3. Use the provided car data context to give specific price and spec advice. '
          '4. Offer to calculate monthly instalments or road tax using your internal tools. '
          'Tone: Professional, helpful, and sustainability-conscious. '
          'Limit your answers to 3-4 concise sentences suitable for mobile users.'
      ),
    );
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String userMessage, {String? dataContext}) async {
    try {
      String finalMessage = userMessage;
      if (dataContext != null) {
        finalMessage = "CAR DATA CONTEXT (Registration Trends/Prices):\n$dataContext\n\nUSER QUESTION: $userMessage";
      } else {

        finalMessage = "CAR DATA CONTEXT:\n${_getMockDataContext()}\n\nUSER QUESTION: $userMessage";
      }
      
      final response = await _chat!.sendMessage(Content.text(finalMessage));
      return response.text ?? 'Error: Empty response';
    } catch (e) {
      print('AiService Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') || 
          errorStr.contains('clientexception') || 
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection')) {
        return 'No internet connection. Please connect to Wi-Fi or Mobile Data.';
      }
      return 'Error: Cannot connect to AI service. ($e)';
    }
  }

  String _getMockDataContext() {
    return "Available Cars: Perodua Bezza (Petrol, RM34.5k), Proton X50 (Petrol, RM86.3k), BYD Atto 3 (EV, RM149.8k). "
           "Fuel Prices: RON95 RM2.05/L, RON97 RM3.47/L, Diesel RM2.15/L.";
  }

  void resetChat() {
    _chat = _model.startChat();
  }
}
