import 'package:base_project/data/trip.dart';

/// Canned trip content used to seed the local repository and by the
/// simulated GenUI trip agent until a real model endpoint is connected.
class SampleTrips {
  SampleTrips._();

  static Trip palawan({String id = 'palawan-coastal-loop'}) => Trip(
    id: id,
    name: 'Palawan Coastal Loop',
    destination: 'Palawan, Philippines',
    datesLabel: 'Aug 14–19, 2026',
    nights: 5,
    distanceTotal: '612 km',
    totalPerRider: '₱18,500',
    totalGroup: '₱111,000',
    isPast: false,
    days: [
      ItineraryDay(
        day: 1,
        title: 'Puerto Princesa → Port Barton',
        distance: '142 km',
        duration: '4h 20m',
        latitude: 10.479,
        longitude: 119.213,
        stay: 'Port Barton Beach Camp',
        stayPrice: '₱1,500–2,500 / night',
        stops: [
          TripStop(
            time: '7:30 AM',
            place: 'Rider meetup & bike check',
            note: 'Robinsons Place car park',
          ),
          TripStop(
            time: '9:15 AM',
            place: 'Underground River viewpoint',
            note: 'Photo stop, Sabang',
          ),
          TripStop(
            time: '1:00 PM',
            place: 'Lunch at Sabang seaside',
            note: 'Grilled seafood',
          ),
          TripStop(
            time: '4:30 PM',
            place: 'Port Barton beach camp',
            note: 'Check-in, sunset swim',
          ),
        ],
      ),
      ItineraryDay(
        day: 2,
        title: 'Port Barton → San Vicente',
        distance: '66 km',
        duration: '2h 00m',
        latitude: 10.5225,
        longitude: 119.2377,
        stay: 'Long Beach beachfront cottages',
        stayPrice: '₱1,200–2,000 / night',
        stops: [
          TripStop(
            time: '9:00 AM',
            place: 'Coastal ridge lookout',
            note: 'Ocean-view switchbacks',
          ),
          TripStop(
            time: '11:30 AM',
            place: 'Long Beach arrival',
            note: '14km white-sand stretch',
          ),
          TripStop(
            time: '6:00 PM',
            place: 'Bonfire & rider dinner',
            note: 'Beachfront cottages',
          ),
        ],
      ),
      ItineraryDay(
        day: 3,
        title: 'San Vicente → El Nido',
        distance: '83 km',
        duration: '2h 30m',
        latitude: 11.18,
        longitude: 119.391,
        stay: 'El Nido town inn',
        stayPrice: '₱1,800–3,000 / night',
        stops: [
          TripStop(
            time: '8:00 AM',
            place: 'Roadside buko stop',
            note: 'Fresh coconut break',
          ),
          TripStop(
            time: '10:30 AM',
            place: 'Nacpan Beach detour',
            note: 'Twin-beach viewpoint',
          ),
          TripStop(
            time: '1:00 PM',
            place: 'El Nido town arrival',
            note: 'Check-in, free afternoon',
          ),
        ],
      ),
      ItineraryDay(
        day: 4,
        title: 'El Nido Island-Hopping · Tour A',
        distance: 'Boat day',
        duration: 'Full day',
        latitude: 11.161,
        longitude: 119.313,
        stay: 'El Nido town inn',
        stayPrice: '₱1,800–3,000 / night',
        stops: [
          TripStop(time: '8:00 AM', place: 'Big Lagoon', note: 'Kayak entry'),
          TripStop(
            time: '10:00 AM',
            place: 'Small Lagoon',
            note: 'Snorkel stop',
          ),
          TripStop(
            time: '12:30 PM',
            place: 'Shimizu Island',
            note: 'Lunch on the boat',
          ),
          TripStop(
            time: '2:30 PM',
            place: 'Secret Lagoon',
            note: 'Swim-through cave',
          ),
        ],
      ),
      ItineraryDay(
        day: 5,
        title: 'El Nido Free Day',
        distance: '38 km',
        duration: 'Half day',
        latitude: 11.193,
        longitude: 119.439,
        stay: 'El Nido town inn',
        stayPrice: '₱1,800–3,000 / night',
        stops: [
          TripStop(
            time: '7:00 AM',
            place: 'Nagkalit-kalit Falls ride',
            note: 'Inland loop',
          ),
          TripStop(
            time: '1:00 PM',
            place: 'Rest & gear check',
            note: 'Prep for return leg',
          ),
          TripStop(
            time: '7:00 PM',
            place: 'Farewell dinner',
            note: 'El Nido waterfront',
          ),
        ],
      ),
      ItineraryDay(
        day: 6,
        title: 'El Nido → Puerto Princesa',
        distance: '238 km',
        duration: '5h 15m',
        latitude: 9.7421,
        longitude: 118.7588,
        stops: [
          TripStop(
            time: '6:30 AM',
            place: 'Early departure',
            note: 'Beat midday heat',
          ),
          TripStop(
            time: '9:30 AM',
            place: 'Roxas fuel & rest stop',
            note: 'Halfway break',
          ),
          TripStop(
            time: '12:00 PM',
            place: 'Taytay viewpoint',
            note: 'Final photo stop',
          ),
          TripStop(
            time: '1:45 PM',
            place: 'Puerto Princesa airport',
            note: 'Bike drop-off, trip ends',
          ),
        ],
      ),
    ],
    budgetItems: [
      BudgetItem(label: 'Motorbike rental (6 days)', amount: '₱4,800'),
      BudgetItem(label: 'Fuel', amount: '₱1,600'),
      BudgetItem(label: 'Accommodation (5 nights)', amount: '₱6,500'),
      BudgetItem(label: 'Island-hopping tour', amount: '₱2,200'),
      BudgetItem(label: 'Meals', amount: '₱2,400'),
      BudgetItem(label: 'Contingency', amount: '₱1,000'),
    ],
    gearItems: [
      'Riding jacket',
      'Gloves & boots',
      'Rain cover',
      'Dry bag',
      'GoPro mount',
      'Sunscreen SPF50',
      "Int'l driving permit",
      'Small-bill cash',
      'Power bank',
      'First-aid kit',
    ],
    riders: [
      Rider(initials: 'J', colorValue: 0xFF007AFF),
      Rider(initials: 'M', colorValue: 0xFFFF9500),
      Rider(initials: 'K', colorValue: 0xFF34C759),
      Rider(initials: 'R', colorValue: 0xFFAF52DE),
      Rider(initials: 'T', colorValue: 0xFF5AC8FA),
      Rider(initials: 'L', colorValue: 0xFFFF375F),
    ],
  );
}
