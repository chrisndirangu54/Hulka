/// Public-health tips paraphrased from cited agencies. Not medical advice.
enum SafetyTipCategory { general, emergency, outbreak }

class SafetyTip {
  const SafetyTip({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.source,
    required this.sourceUrl,
    required this.year,
  });

  final String id;
  final SafetyTipCategory category;
  final String title;
  final String body;
  final String source;
  final String sourceUrl;
  final int year;
}

abstract final class SafetyTipsCatalog {
  static const disclaimer =
      'Safety tips are public-health information from the cited agencies. '
      'They are not a diagnosis or a replacement for local emergency services. '
      'In Kenya call 999 or 112 for a life-threatening emergency.';

  static const tips = <SafetyTip>[
    SafetyTip(
      id: 'wash-hands',
      category: SafetyTipCategory.general,
      title: 'Wash hands with soap at the key moments',
      body:
          'Use soap and running water before eating, after using the toilet, after coughing or caring for someone who is ill, and after handling raw food or animals. Alcohol-based rub (at least 60% alcohol) is a backup when hands are not visibly dirty.',
      source: 'WHO — Hand hygiene',
      sourceUrl: 'https://www.who.int/health-topics/hand-hygiene',
      year: 2023,
    ),
    SafetyTip(
      id: 'safe-water',
      category: SafetyTipCategory.general,
      title: 'Drink water that has been made safe',
      body:
          'If the tap is not trusted, boil water until it rolls, then keep it covered. Chlorine tablets or a certified filter also work. Use the same water for brushing teeth and washing food that will be eaten raw.',
      source: 'WHO — Drinking-water',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/drinking-water',
      year: 2023,
    ),
    SafetyTip(
      id: 'ors-diarrhoea',
      category: SafetyTipCategory.general,
      title: 'Give oral rehydration for watery diarrhoea',
      body:
          'Mix oral rehydration salts (ORS) with the volume of safe water on the packet. Keep giving small sips, continue breastfeeding, and add zinc where a clinician has advised it. Seek care fast if there is blood in stool, repeated vomiting, or the person cannot drink.',
      source: 'WHO — Diarrhoeal disease',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/diarrhoeal-disease',
      year: 2024,
    ),
    SafetyTip(
      id: 'activity-sleep',
      category: SafetyTipCategory.general,
      title: 'Move most days and protect night sleep',
      body:
          'Adults do well with at least 150 minutes of moderate activity a week, plus muscle work twice a week. Keep a regular sleep window. Tobacco and heavy alcohol undo a large part of that gain.',
      source: 'WHO — Physical activity',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
      year: 2024,
    ),
    SafetyTip(
      id: 'vaccines',
      category: SafetyTipCategory.general,
      title: 'Keep routine vaccines on the national schedule',
      body:
          'Childhood immunisation (including measles) and recommended adult boosters prevent outbreaks. Bring the mother-and-child booklet or adult record to the clinic. Missed doses can usually be caught up — ask a clinician rather than restarting on your own.',
      source: 'WHO — Immunization',
      sourceUrl: 'https://www.who.int/health-topics/vaccines-and-immunization',
      year: 2024,
    ),
    SafetyTip(
      id: 'malaria-nets',
      category: SafetyTipCategory.general,
      title: 'Sleep under an insecticide-treated net',
      body:
          'In malaria-risk parts of Kenya, use a treated net every night, especially for children and pregnant people. Seek same-day testing for fever. Do not wait for a cycle of “it will pass” in a high-transmission season.',
      source: 'WHO — Malaria',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/malaria',
      year: 2024,
    ),
    SafetyTip(
      id: 'call-999',
      category: SafetyTipCategory.emergency,
      title: 'Call 999 or 112 before anything else if life is at risk',
      body:
          'Unconsciousness, severe bleeding, chest pain, difficulty breathing, seizure that does not stop, or major trauma: phone national emergency services first. Then request a partner-hospital ambulance in Hulka. Stay on the line and give a landmark the driver can find.',
      source: 'Kenya Red Cross / national emergency numbers',
      sourceUrl: 'https://www.redcross.or.ke/',
      year: 2024,
    ),
    SafetyTip(
      id: 'bleeding',
      category: SafetyTipCategory.emergency,
      title: 'Press firmly on severe bleeding',
      body:
          'Use a clean cloth and continuous direct pressure. Do not remove a soaked cloth — add another on top. Raise the limb if you can do so without causing more harm. Do not use a tourniquet unless you have been trained.',
      source: 'IFRC — International first aid',
      sourceUrl: 'https://www.ifrc.org/our-work/health-and-care/community-health-and-first-aid',
      year: 2023,
    ),
    SafetyTip(
      id: 'choking',
      category: SafetyTipCategory.emergency,
      title: 'If a person cannot cough or speak, treat choking',
      body:
          'Ask “are you choking?” If they cannot make sound, give back blows then abdominal thrusts if you are trained. For infants, use back blows and chest thrusts, never abdominal thrusts. Call 999 if the blockage does not clear.',
      source: 'IFRC — First aid',
      sourceUrl: 'https://www.ifrc.org/our-work/health-and-care/community-health-and-first-aid',
      year: 2023,
    ),
    SafetyTip(
      id: 'recovery-position',
      category: SafetyTipCategory.emergency,
      title: 'Unconscious but breathing: recovery position',
      body:
          'If there is no trauma to the neck and the person is breathing, roll them onto their side so the airway stays open and vomit can drain. Keep checking breath until help arrives. If they stop breathing, start CPR if you are trained.',
      source: 'WHO — First aid / basic emergency care',
      sourceUrl: 'https://www.who.int/emergencies/overview',
      year: 2023,
    ),
    SafetyTip(
      id: 'burns',
      category: SafetyTipCategory.emergency,
      title: 'Cool a burn with running water, then cover',
      body:
          'Cool the burn under cool running water for about 20 minutes. Remove tight items near the area. Do not apply ice, oil, toothpaste or butter. Cover loosely with clean cloth and seek care for deep, large, facial, hand or genital burns.',
      source: 'WHO — Burns',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/burns',
      year: 2023,
    ),
    SafetyTip(
      id: 'chest-pain',
      category: SafetyTipCategory.emergency,
      title: 'Chest pain with breathlessness is an emergency',
      body:
          'Sit the person upright and still. Chew aspirin only if a clinician has previously said it is safe for them and they are not bleeding or allergic. Call 999/112. Do not drive them yourself if an ambulance can come.',
      source: 'WHO — Cardiovascular diseases',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/cardiovascular-diseases-(cvds)',
      year: 2025,
    ),
    SafetyTip(
      id: 'outbreak-hygiene',
      category: SafetyTipCategory.outbreak,
      title: 'During an outbreak, tighten hygiene and stay home if febrile',
      body:
          'Follow the Ministry of Health and county alerts. Wash hands, wear a well-fitted mask if the disease spreads in air or droplets, and keep distance in crowds. If you have fever, cough or unexplained diarrhoea, stay home and call a clinic before walking into a waiting room.',
      source: 'WHO — Disease Outbreak News',
      sourceUrl: 'https://www.who.int/emergencies/disease-outbreak-news',
      year: 2025,
    ),
    SafetyTip(
      id: 'cholera',
      category: SafetyTipCategory.outbreak,
      title: 'Cholera: safe water, ORS, and rapid care for severe dehydration',
      body:
          'Use boiled or treated water, wash produce, and use a latrine. Start ORS at the first watery stool. Go immediately to a cholera treatment centre if the person is dizzy, has sunken eyes, or cannot drink. Vaccination is an extra layer where MoH offers it, not a substitute for water safety.',
      source: 'WHO — Cholera',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/cholera',
      year: 2024,
    ),
    SafetyTip(
      id: 'measles',
      category: SafetyTipCategory.outbreak,
      title: 'Measles: two vaccine doses and isolation of suspected cases',
      body:
          'Measles spreads in the air before the rash. Keep the suspected case in a separate room and send immune caregivers only. Confirm vaccine status. Seek care for children with fever and cough — do not give aspirin to children.',
      source: 'WHO — Measles',
      sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/measles',
      year: 2024,
    ),
    SafetyTip(
      id: 'mpox-ebola-hygiene',
      category: SafetyTipCategory.outbreak,
      title: 'Do not touch bodies, bushmeat or unexplained rashes in an alert',
      body:
          'For viral haemorrhagic fever or mpox alerts: avoid funerals that involve washing the body unless health teams lead, cook animal products thoroughly, and report clusters of fever with bleeding or blistering rash to the county disease surveillance officer.',
      source: 'WHO AFRO / CDC outbreak guidance',
      sourceUrl: 'https://www.afro.who.int/health-topics/disease-outbreaks',
      year: 2024,
    ),
    SafetyTip(
      id: 'cdc-prep',
      category: SafetyTipCategory.outbreak,
      title: 'Keep a seven-day household kit when an outbreak is announced',
      body:
          'Store ORS, soap, a thermometer, any regular medicines, treated water, and the clinic phone numbers. Write the nearest Hulka partner hospital and its ambulance line on paper. Official updates come from MoH, WHO, and county public-health channels — not forwarded rumours.',
      source: 'CDC — Emergency preparedness',
      sourceUrl: 'https://www.cdc.gov/emergency/index.html',
      year: 2024,
    ),
  ];

  static List<SafetyTip> byCategory(SafetyTipCategory category) =>
      tips.where((t) => t.category == category).toList(growable: false);

  static String label(SafetyTipCategory category) {
    switch (category) {
      case SafetyTipCategory.general:
        return 'General health';
      case SafetyTipCategory.emergency:
        return 'Emergencies';
      case SafetyTipCategory.outbreak:
        return 'Outbreaks';
    }
  }
}
