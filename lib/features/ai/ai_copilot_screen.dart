import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});
  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final prompt = TextEditingController();
  final api = HulkaFunctions();
  bool loading = false;
  String answer = 'Ask Hulka to explain your permitted health data or prepare questions for a clinician.';

  Future<void> send() async {
    final text = prompt.text.trim();
    if (text.isEmpty) return;
    setState(() => loading = true);
    try {
      final r = await api.askClinicalAi(text);
      setState(() => answer = (r['answer'] as String?) ?? 'No answer returned.');
    } catch (e) {
      setState(() => answer = 'AI service unavailable: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('AI Health Copilot', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('For explanation and workflow support, not autonomous diagnosis or prescribing.'),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(answer))),
        const SizedBox(height: 16),
        TextField(
          controller: prompt,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Ask about your health record',
            hintText: 'Example: What changed in my blood pressure this month?',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : send,
          icon: const Icon(Icons.auto_awesome),
          label: Text(loading ? 'Checking…' : 'Ask Hulka'),
        ),
      ],
    );
  }
}
