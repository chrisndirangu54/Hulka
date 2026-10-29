import 'package:flutter/material.dart';

class CareScene {
  const CareScene({
    required this.title,
    required this.kicker,
    required this.asset,
    required this.url,
    required this.credit,
    required this.icon,
  });

  final String title;
  final String kicker;
  final String asset;
  final String url;
  final String credit;
  final IconData icon;
}

/// Photographs are Unsplash License (free to use). Credits in [credit].
const careScenes = <CareScene>[
  CareScene(
    title: 'The atrium holds the waiting.',
    kicker: 'Care network',
    asset: 'assets/images/atrium.jpg',
    url: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=1800&q=75',
    credit: 'National Cancer Institute / Unsplash',
    icon: Icons.apartment_outlined,
  ),
  CareScene(
    title: 'Medicine finds the shelf that has it.',
    kicker: 'Pharmacy',
    asset: 'assets/images/pharmacy.jpg',
    url: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=1800&q=75',
    credit: 'Hal Gatewood / Unsplash',
    icon: Icons.local_pharmacy_outlined,
  ),
  CareScene(
    title: 'The consult travels without the file getting lost.',
    kicker: 'Telemedicine',
    asset: 'assets/images/telemedicine.jpg',
    url: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1800&q=75',
    credit: 'National Cancer Institute / Unsplash',
    icon: Icons.video_call_outlined,
  ),
  CareScene(
    title: 'The watch writes into the same story.',
    kicker: 'Wearables',
    asset: 'assets/images/wearable.jpg',
    url: 'https://images.unsplash.com/photo-1575311373937-040b8e1fd5b6?auto=format&fit=crop&w=1800&q=75',
    credit: 'Daniel Korpai / Unsplash',
    icon: Icons.watch_outlined,
  ),
  CareScene(
    title: 'Hands that already know the chart.',
    kicker: 'Clinical care',
    asset: 'assets/images/care.jpg',
    url: 'https://images.unsplash.com/photo-1631815588090-d4bfec5b1ccb?auto=format&fit=crop&w=1800&q=75',
    credit: 'Unsplash License',
    icon: Icons.health_and_safety_outlined,
  ),
  CareScene(
    title: 'A team that shares one timeline.',
    kicker: 'Hospitals',
    asset: 'assets/images/clinic.jpg',
    url: 'https://images.unsplash.com/photo-1538108149393-fbbd81895907?auto=format&fit=crop&w=1800&q=75',
    credit: 'Unsplash License',
    icon: Icons.local_hospital_outlined,
  ),
];
