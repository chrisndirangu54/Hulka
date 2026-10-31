import 'package:flutter/material.dart';
import '../../services/functions_service.dart';

class ClinicianCopilotScreen extends StatefulWidget {
  const ClinicianCopilotScreen({super.key});
  @override
  State<ClinicianCopilotScreen> createState() => _ClinicianCopilotScreenState();
}
class _ClinicianCopilotScreenState extends State<ClinicianCopilotScreen> {
  final patient = TextEditingController();
  final question = TextEditingController();
  final api = HulkaFunctions();
  String task = 'questions', model = 'medgemma-1.5-4b';
  String result = 'Clinician-only research assistance. No diagnosis or prescriptions.';
  bool busy = false;
  @override
  void dispose() {patient.dispose();question.dispose();super.dispose();}
  Future<void> ask() async {
    setState(() => busy = true);
    try {
      final r = await api.clinicianCopilot({
        'patientId': patient.text.trim(), 'task':task,'modelId':model,
        'question':question.text.trim(), 'evidenceIds':<String>[]
      });
      if (!mounted) return;
      setState(() => result = r['configured'] == true
          ? '${r['response']}\n\nModel: ${(r['model'] as Map?)?['displayName']}\n'
            'Model card: ${(r['model'] as Map?)?['source']}\n'
            'Clinical review required. No verified literature supplied.'
          : r['message'].toString());
    } catch (e) {
      if (mounted) setState(() => result = 'Copilot unavailable: $e');
    } finally {if (mounted) setState(() => busy = false);}
  }
  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20), children:[
      Text('Clinician Copilot',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:8),
      const Text('Research-grade medical assistance. A licensed clinician must independently verify every suggestion.'),
      TextField(controller:patient,decoration:const InputDecoration(labelText:'Consented patient identifier')),
      DropdownButtonFormField<String>(value:task,decoration:const InputDecoration(labelText:'Assist with'),
        items:const [
          DropdownMenuItem(value:'questions',child:Text('Questions to ask')),
          DropdownMenuItem(value:'summary',child:Text('Summarize clinical information')),
          DropdownMenuItem(value:'differential_review',child:Text('Review diagnostic considerations')),
          DropdownMenuItem(value:'lab_review',child:Text('Review laboratory findings')),
          DropdownMenuItem(value:'evidence_review',child:Text('Organize evidence'))
        ], onChanged:(v)=>setState(()=>task=v??task)),
      DropdownButtonFormField<String>(value:model,decoration:const InputDecoration(labelText:'Research model'),
        items:const [
          DropdownMenuItem(value:'medgemma-1.5-4b',child:Text('Google MedGemma 1.5 4B')),
          DropdownMenuItem(value:'medgemma-27b',child:Text('Google MedGemma 27B'))
        ],onChanged:(v)=>setState(()=>model=v??model)),
      TextField(controller:question,minLines:3,maxLines:6,
        decoration:const InputDecoration(labelText:'Clinical question (avoid direct identifiers)')),
      const SizedBox(height:12),
      FilledButton(onPressed:busy?null:ask,child:Text(busy?'Evaluating…':'Request clinical assistance')),
      const SizedBox(height:16),
      SelectableText(result),
    ]);
}
