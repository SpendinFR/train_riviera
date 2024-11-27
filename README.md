import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'Sélection Train',
theme: ThemeData(
primarySwatch: Colors.blue,
),
home: TrainScheduleScreen(),
);
}
}

class TrainScheduleScreen extends StatefulWidget {
@override
_TrainScheduleScreenState createState() => _TrainScheduleScreenState();
}

class _TrainScheduleScreenState extends State<TrainScheduleScreen> {
String? departureStation;
String? arrivalStation;
List<String> stations = [
'Marseille', 'Antibes', 'Vintimille', 'Nice', 'Cannes', 'Monaco', 'Menton'
];

List<dynamic> trainData = [];
List<dynamic> disruptionsData = [];
final String apiKey = '82bf07a6-ebce-47a6-86e0-adebf1ae6024';

@override
void initState() {
super.initState();
}

// Fonction pour récupérer les trains
Future<void> fetchTrainSchedules() async {
if (departureStation == null || arrivalStation == null) return;

    // Format de la date et de l'heure actuelles
    String currentDateTime = DateFormat('yyyyMMddTHHmmss').format(DateTime.now());

    // Remplacer par les stop_area correspondant aux gares
    String departureStopArea = 'stop_area:SNCF:${getStopAreaCode(departureStation!)}';

    final url =
        'https://api.sncf.com/v1/coverage/sncf/stop_areas/$departureStopArea/departures?datetime=$currentDateTime';

    try {
      // Ajout de l'authentification via les en-têtes
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('$apiKey:')),
        },
      );

      if (response.statusCode == 200) {
        // Affichage de la réponse brute dans la console pour debug
        print('Response body: ${response.body}');

        // Décodage des données JSON
        final responseData = json.decode(response.body);
        setState(() {
          trainData = responseData['departures'];
          disruptionsData = responseData['disruptions'] ?? [];
        });
      } else {
        throw Exception('Failed to load train schedules');
      }
    } catch (error) {
      print('Error fetching train schedules: $error');
    }
}

// Fonction pour obtenir le code de la zone d'arrêt basé sur la gare
String getStopAreaCode(String station) {
switch (station) {
case 'Marseille':
return '87391003';
case 'Antibes':
return '87391006';
case 'Vintimille':
return '87391008';
case 'Nice':
return '87391010';
case 'Cannes':
return '87391012';
case 'Monaco':
return '87391014';
case 'Menton':
return '87391016';
default:
return '87391003'; // Valeur par défaut
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text('Sélection des trains'),
),
body: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
children: [
DropdownButton<String>(
value: departureStation,
hint: Text("Choisissez la gare de départ"),
items: stations.map((String station) {
return DropdownMenuItem<String>(
value: station,
child: Text(station),
);
}).toList(),
onChanged: (String? newValue) {
setState(() {
departureStation = newValue;
});
},
),
SizedBox(height: 20),
DropdownButton<String>(
value: arrivalStation,
hint: Text("Choisissez la gare d'arrivée"),
items: stations.map((String station) {
return DropdownMenuItem<String>(
value: station,
child: Text(station),
);
}).toList(),
onChanged: (String? newValue) {
setState(() {
arrivalStation = newValue;
});
},
),
SizedBox(height: 20),
ElevatedButton(
onPressed: fetchTrainSchedules,
child: Text("Afficher les trains"),
),
Expanded(
child: ListView.builder(
itemCount: trainData.length,
itemBuilder: (context, index) {
var train = trainData[index];

                  // Définir les horaires de départ et d'arrivée
                  var departureTime = train['stop_date_time']['departure_date_time'] ?? 'Non précisé';
                  var arrivalTime = train['stop_date_time']['arrival_date_time'] ?? 'Non précisé';

                  // Chercher si des perturbations sont présentes pour ce train
                  String delayMessage = '';
                  String newDepartureTime = departureTime;
                  String newArrivalTime = arrivalTime;
                  for (var disruption in disruptionsData) {
                    if (disruption['impacted_objects'][0]['pt_object']['id'] == train['id']) {
                      var impactedStop = disruption['impacted_objects'][0]['impacted_stops']
                          .firstWhere((stop) => stop['stop_point']['id'] == train['stop_date_time']['stop_point']['id']);
                      if (impactedStop['departure_status'] == 'delayed') {
                        delayMessage = 'Retard: ${impactedStop['cause']}';
                        newDepartureTime = impactedStop['amended_departure_time'] ?? departureTime;
                        newArrivalTime = impactedStop['amended_arrival_time'] ?? arrivalTime;
                      }
                    }
                  }

                  return ListTile(
                    title: Text("Train: ${train['display_informations']['name']}"),
                    subtitle: Text(
                      'Départ: $newDepartureTime\nArrivée: $newArrivalTime\n$delayMessage',
                    ),
                    trailing: Icon(Icons.train),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
}
}
