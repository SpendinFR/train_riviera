import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horaires SNCF',
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
  String? departureStation = 'Antibes';
  String? arrivalStation = 'Nice Saint-Augustin';
  List<String> stations = [
    'Les Arcs - Draguignan',
    'Saint-Raphaël - Valescure',
    'Cannes',
    'Le Golfe Juan - Vallauris',
    'Juan les Pins',
    'Antibes',
    'Biot',
    'Villeneuve-Loubet - Plage',
    'Cagnes-sur-Mer',
    'Cros de Cagnes',
    'Saint-Laurent-du-Var',
    'Nice Saint-Augustin',
    'Nice',
    'Nice Riquier',
    'Villefranche-sur-Mer',
    'Beaulieu-sur-Mer',
    'Èze',
    'Cap-d\'Ail',
    'Monaco Monte Carlo',
    'Roquebrune-Cap-Martin',
    'Carnoles',
    'Menton',
    'Menton Garavan',
    'Ventimiglia'
  ];


  List<dynamic> trainData = [];
  final String apiKey = '82bf07a6-ebce-47a6-86e0-adebf1ae6024';

  // Fonction pour inverser les gares de départ et d'arrivée
  void swapStations() {
    setState(() {
      String? temp = departureStation;
      departureStation = arrivalStation;
      arrivalStation = temp;
    });
    fetchTrainSchedules(); // Recharger les horaires après l'inversion
  }

  // Fonction pour récupérer les horaires des trains
  Future<void> fetchTrainSchedules() async {
    if (departureStation == null || arrivalStation == null) {
      print("Les gares de départ et d'arrivée doivent être sélectionnées.");
      return;
    }

    String departureStopArea = 'stop_area:SNCF:${getStopAreaCode(departureStation!)}';
    String arrivalStopArea = 'stop_area:SNCF:${getStopAreaCode(arrivalStation!)}';
    String currentDateTime = DateFormat('yyyyMMddTHHmmss').format(DateTime.now());

    final url =
        'https://api.sncf.com/v1/coverage/sncf/journeys?from=$departureStopArea&to=$arrivalStopArea&datetime=$currentDateTime&min_nb_journeys=5&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        setState(() {
          trainData = responseData['journeys'] ?? [];
        });

        // Obtenir les disruptions
        final disruptions = responseData['disruptions'] ?? [];

        // Parcourir chaque train pour associer les perturbations
        for (var train in trainData) {
          var sections = train['sections'] ?? [];
          var publicTransportSection = sections.firstWhere(
                (section) => section['type'] == 'public_transport',
            orElse: () => null,
          );

          if (publicTransportSection != null) {
            var trainName = publicTransportSection['display_informations']?['headsign'];
            var departureTime = publicTransportSection['departure_date_time'];

            // Initialisation des perturbations
            train['disruption'] = null;

            // Associer le train aux disruptions
            for (var disruption in disruptions) {
              var impactedObjects = disruption['impacted_objects'] ?? [];
              for (var obj in impactedObjects) {
                var tripName = obj['pt_object']?['trip']?['name'];
                var impactedStops = obj['impacted_stops'] ?? [];

                // Vérifie si le train actuel est celui qui a une perturbation
                if (tripName == trainName) {
                  // Chercher la gare de départ parmi les impacted_stops
                  for (var stop in impactedStops) {
                    var stopPointId = stop['stop_point']?['id'] ?? '';
                    var baseDepartureTime = stop['base_departure_time'] ?? '';
                    var amendedDepartureTime = stop['amended_departure_time'] ?? ''; // Récupérer l'heure de départ modifiée
                    var cause = stop['cause'] ?? '';

                    // Extraire uniquement le code de la gare (après 'stop_point:SNCF:')
                    var stopCode = stopPointId.split(':')[2]; // Extraction du code de la gare

                    // Log des valeurs pour débogage
                    print('Train: $trainName');
                    print('stopPointId: $stopPointId');
                    print('Extracted stopCode: $stopCode');
                    print('baseDepartureTime: $baseDepartureTime');
                    print('Amended departure time: $amendedDepartureTime');
                    print('Cause: $cause');
                    print('Expected stop area code: ${getStopAreaCode(departureStation!)}');

                    // Vérification si c'est la gare de départ et si l'heure correspond
                    if (stopCode == getStopAreaCode(departureStation!) &&
                        baseDepartureTime == departureTime.substring(9)) {
                      // Ajouter les perturbations au train
                      train['disruption'] = {
                        'amendedDeparture': amendedDepartureTime.isNotEmpty ? amendedDepartureTime : baseDepartureTime, // Utiliser l'heure modifiée de départ
                        'cause': cause.isNotEmpty ? cause : 'Aucune cause', // Afficher la cause si disponible
                      };
                      break; // Sortie de la boucle dès qu'on trouve la perturbation
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        throw Exception(
            'Erreur lors du chargement des horaires des trains : ${response.statusCode}');
      }
    } catch (error) {
      print('Erreur lors de la récupération des horaires des trains: $error');
    }
  }

  // Fonction pour obtenir le code de la zone d'arrêt (stop_area) en fonction du nom de la gare
  String getStopAreaCode(String station) {
    switch (station) {
      case 'Les Arcs - Draguignan':
        return '87755447';
      case 'Saint-Raphaël - Valescure':
        return '87757526';
      case 'Cannes':
        return '87757625';
      case 'Le Golfe Juan - Vallauris':
        return '87757641';
      case 'Juan les Pins':
        return '87757666';
      case 'Antibes':
        return '87757674';
      case 'Biot':
        return '87757690';
      case 'Villeneuve-Loubet - Plage':
        return '87756304';
      case 'Cagnes-sur-Mer':
        return '87756320';
      case 'Cros de Cagnes':
        return '87756338';
      case 'Saint-Laurent-du-Var':
        return '87756346';
      case 'Nice Saint-Augustin':
        return '87756254';
      case 'Nice':
        return '87756056';
      case 'Nice Riquier':
        return '87756353';
      case 'Villefranche-sur-Mer':
        return '87756361';
      case 'Beaulieu-sur-Mer':
        return '87756379';
      case 'Èze':
        return '87756387';
      case 'Cap-d\'Ail':
        return '87756395';
      case 'Monaco Monte Carlo':
        return '87756403';
      case 'Roquebrune-Cap-Martin':
        return '87756460';
      case 'Carnoles':
        return '87756478';
      case 'Menton':
        return '87756486';
      case 'Menton Garavan':
        return '87756494';
      case 'Ventimiglia':
        return '83045013'; // Code pour Ventimiglia
      default:
        return '87757674'; // Par défaut, Antibes
    }
  }


  // Fonction pour formater l'heure (ex: 20241125T161059 => 16:10)
  String formatTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return 'Invalide';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(dateTime));
    } catch (e) {
      return 'Invalide';
    }
  }
  String formatAmendedDeparture(String? amendedDeparture) {
    if (amendedDeparture == null || amendedDeparture.isEmpty || amendedDeparture.length != 6) {
      return 'Invalide';
    }
    try {
      String hours = amendedDeparture.substring(0, 2); // Heures
      String minutes = amendedDeparture.substring(2, 4); // Minutes
      return '$hours:$minutes'; // Retourne au format HH:mm
    } catch (e) {
      return 'Invalide';
    }
  }


  // Fonction pour formater la durée du trajet (en minutes)
  String formatDuration(int durationInSeconds) {
    int durationInMinutes = (durationInSeconds / 60).round();
    return '$durationInMinutes min';
  }

  String calculateNewArrivalTime(String? amendedDeparture, int durationInSeconds) {
    if (amendedDeparture == null || amendedDeparture.isEmpty || amendedDeparture.length != 6) {
      return 'Invalide';
    }

    try {
      // Extraire les heures et les minutes de l'heure de départ modifiée (format HHmmss, comme "122000")
      String hoursStr = amendedDeparture.substring(0, 2); // Les deux premiers caractères sont les heures
      String minutesStr = amendedDeparture.substring(2, 4); // Les deux caractères suivants sont les minutes

      // Convertir ces heures et minutes en entiers
      int hours = int.parse(hoursStr);
      int minutes = int.parse(minutesStr);

      // Ajouter la durée du trajet en minutes
      int durationInMinutes = (durationInSeconds / 60).round();

      // Ajouter la durée au temps de départ en ajustant les minutes et les heures
      minutes += durationInMinutes;

      // Ajuster les minutes et heures si nécessaire (par exemple, si les minutes dépassent 60)
      while (minutes >= 60) {
        minutes -= 60;
        hours += 1;
      }

      // Ajuster les heures si nécessaire (par exemple, si l'heure dépasse 24)
      while (hours >= 24) {
        hours -= 24;
      }

      // Retourner l'heure d'arrivée modifiée au format HH:mm
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalide';
    }
  }


  @override
  Widget build(BuildContext context) {
    // Obtenir la largeur et la hauteur de l'écran
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.train, size: 24), // Icône de train
            SizedBox(width: 8), // Espacement
            Text("TrainRiviera"), // Titre de l'application
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Bloc contenant les dropdowns et l'icône d'inversion
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Alignement en haut
              children: [
                // Colonne pour les dropdowns avec design arrondi
                Expanded(
                  child: Column(
                    children: [
                      // Bloc pour la gare de départ
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16), // Espacement entre les blocs
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200, // Couleur d'arrière-plan gris clair
                          borderRadius: BorderRadius.circular(12), // Bord arrondi
                          border: Border.all(color: Colors.grey, width: 1), // Bordure grise
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true, // Étend le dropdown pour prendre toute la largeur
                          value: departureStation,
                          hint: Text("Gare de départ"),
                          underline: SizedBox(), // Supprime la ligne par défaut
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
                      ),

                      // Bloc pour la gare d'arrivée
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200, // Couleur d'arrière-plan gris clair
                          borderRadius: BorderRadius.circular(12), // Bord arrondi
                          border: Border.all(color: Colors.grey, width: 1), // Bordure grise
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true, // Étend le dropdown pour prendre toute la largeur
                          value: arrivalStation,
                          hint: Text("Gare d'arrivée"),
                          underline: SizedBox(), // Supprime la ligne par défaut
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
                      ),
                    ],
                  ),
                ),

                // Icône d'inversion à côté des deux dropdowns
                Padding(
                  padding: const EdgeInsets.only(left: 8.0), // Petit espacement à gauche
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        // Inversion des gares
                        String? temp = departureStation;
                        departureStation = arrivalStation;
                        arrivalStation = temp;
                      });
                    },
                    icon: Icon(Icons.swap_vert, size: 32), // Icône avec une taille ajustée
                    tooltip: "Inverser les gares", // Texte explicatif au survol
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Bouton pour récupérer les horaires
            SizedBox(
              width: double.infinity, // Cela rend le bouton aussi large que son parent
              child: ElevatedButton(
                onPressed: fetchTrainSchedules,
                child: Text(
                  'Afficher les horaires',
                  style: TextStyle(
                    fontSize: 18, // Taille du texte
                    fontWeight: FontWeight.bold, // Texte en gras
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1A237E), // Couleur de fond bleu foncé
                  foregroundColor: Colors.white, // Couleur du texte en blanc
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0), // Espacement autour du texte
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Coins arrondis
                  ),
                ),
              ),
            ),



            // Affichage des horaires récupérés
            Expanded(
              child: trainData.isEmpty
                  ? Center(child: Text("", style: TextStyle(fontSize: 20))) // Message si aucun horaire
                  : ListView.builder(
                itemCount: trainData.length,
                itemBuilder: (context, index) {
                  var journey = trainData[index];
                  var sections = journey['sections'] ?? [];
                  var trainSection = sections.firstWhere(
                        (section) => section['type'] == 'public_transport',
                    orElse: () => null,
                  );

                  if (trainSection == null) {
                    return ListTile(
                      title: Text("Aucun train trouvé", style: TextStyle(fontSize: 18)),
                      subtitle: Text("Ce trajet ne contient pas de train.", style: TextStyle(fontSize: 16)),
                    );
                  }

                  var headsign = trainSection['display_informations']?['headsign'] ?? 'Non spécifié';
                  var departureTime = trainSection['departure_date_time'] ?? 'Non précisé';
                  var arrivalTime = trainSection['arrival_date_time'] ?? 'Non précisé';
                  var duration = journey['duration'] ?? 0;

                  // Vérifie si le train a une perturbation
                  var disruption = journey['disruption'];
                  var hasDelay = disruption != null;

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 12), // Espacement entre les blocs
                    padding: EdgeInsets.all(20), // Padding interne agrandi
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // Fond gris clair pour les blocs
                      borderRadius: BorderRadius.circular(16), // Coins arrondis
                      // Suppression de l'ombre
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Train n° $headsign",
                              style: TextStyle(
                                fontSize: 22.0, // Taille du titre du train
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (hasDelay)
                              Container(
                                padding: EdgeInsets.all(4.0), // Ajouter un peu d'espace autour de l'icône
                                decoration: BoxDecoration(
                                  color: Colors.yellow, // Fond jaune pour l'icône
                                  shape: BoxShape.circle, // Icône avec forme ronde
                                ),
                                child: Icon(
                                  Icons.access_time,  // Icône de temps (minuteur)
                                  color: Colors.black, // Icône noire
                                  size: 24.0,           // Taille de l'icône agrandie
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 12.0),
                        // Affichage de l'heure de départ et de l'heure modifiée sur la même ligne
                        Row(
                          children: [
                            Text(
                              "Heure de départ : ${formatTime(departureTime)}",
                              style: hasDelay
                                  ? TextStyle(
                                fontSize: 18.0,
                                decoration: TextDecoration.lineThrough,  // Barré si perturbation
                              )
                                  : TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasDelay)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  color: Colors.yellow,  // Définir la couleur de fond jaune
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Un peu d'espace autour du texte
                                  child: Text(
                                    "Retardée : ${formatAmendedDeparture(disruption['amendedDeparture'])}",
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,  // Texte en noir pour contraste
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),

                        SizedBox(height: 12.0),
                        // Affichage de l'heure d'arrivée et de l'heure modifiée sur la même ligne
                        Row(
                          children: [
                            Text(
                              "Heure d'arrivée : ${formatTime(arrivalTime)}",
                              style: hasDelay
                                  ? TextStyle(
                                fontSize: 18.0,
                                decoration: TextDecoration.lineThrough,  // Barré si perturbation
                              )
                                  : TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasDelay)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),  // Ajout d'un peu d'espace entre les textes
                                child: Container(
                                  color: Colors.yellow,  // Fond jaune
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),  // Espacement autour du texte
                                  child: Text(
                                    "Retardée : ${calculateNewArrivalTime(disruption['amendedDeparture'], duration)}",
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,  // Texte en noir pour le contraste
                                    ),
                                  ),
                                ),
                              )

                          ],
                        ),


                        SizedBox(height: 12.0),
                        // Affichage du temps de trajet et de la cause sur la même ligne
                        Row(
                          children: [
                            Text(
                              "Temps de trajet : ${formatDuration(duration)}",
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (disruption != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),  // Ajout d'un espace entre le temps et la cause
                                child: Container(
                                  color: Colors.yellow,  // Fond jaune
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),  // Espacement autour du texte
                                  child: Text(
                                    "Cause : ${disruption['cause']}",
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,  // Texte en noir pour un bon contraste avec le fond jaune
                                    ),
                                  ),
                                ),
                              )

                          ],
                        ),

                      ],
                    ),
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

