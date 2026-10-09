class Cinema {
  const Cinema({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.description,
    this.imageUrl,
    this.imageReference,
    this.commons,
    this.wikidata,
    this.wikipedia,
    this.website,
    this.screens,
    this.equipment,
    this.photo,
    this.descriptionSource,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? description;
  final String? imageUrl;
  final String? imageReference;
  final String? commons;
  final String? wikidata;
  final String? wikipedia;
  final String? website;
  final String? screens;
  final String? equipment;
  final CinemaPhoto? photo;
  final String? descriptionSource;

  /// A factual summary of the OSM fields when no editorial text is available.
  String get displayDescription =>
      description ??
      [
        '$name est un cinéma répertorié dans OpenStreetMap${city != null ? ' à $city' : ''}.',
        if (address != null) 'Adresse renseignée : $address.',
        if (screens != null) 'Nombre de salles renseigné : $screens.',
        if (equipment != null) 'Équipements renseignés : $equipment.',
        'Consultez le site du cinéma pour les séances et les horaires.',
      ].join(' ');

  String get displayDescriptionSource =>
      descriptionSource ?? 'https://www.openstreetmap.org/$id';

  Cinema enriched({CinemaPhoto? photo, String? description, String? source}) =>
      Cinema(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
        imageUrl: imageUrl,
        imageReference: imageReference,
        commons: commons,
        wikidata: wikidata,
        wikipedia: wikipedia,
        website: website,
        screens: screens,
        equipment: equipment,
        photo: photo ?? this.photo,
        description: this.description ?? description,
        descriptionSource: this.description != null
            ? descriptionSource
            : source,
      );

  factory Cinema.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'];
    final type = json['type'];
    final id = json['id'];
    final coordinates = type == 'node' ? json : json['center'];
    if (tags is! Map ||
        tags['amenity'] != 'cinema' ||
        !['node', 'way', 'relation'].contains(type) ||
        id is! int ||
        coordinates is! Map ||
        coordinates['lat'] is! num ||
        coordinates['lon'] is! num) {
      throw const FormatException('Établissement ou coordonnées invalides.');
    }
    final lat = (coordinates['lat'] as num).toDouble();
    final lon = (coordinates['lon'] as num).toDouble();
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      throw const FormatException('Coordonnées invalides.');
    }
    String? text(String key) {
      final value = tags[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final street = text('addr:street') ?? text('contact:street');
    final address =
        text('addr:full') ??
        [
          if (street != null)
            [
              text('addr:housenumber') ?? text('contact:housenumber'),
              street,
            ].whereType<String>().join(' '),
          text('addr:postcode'),
          text('addr:city'),
        ].whereType<String>().join(', ');
    final image = text('image');
    final uri = image == null ? null : Uri.tryParse(image);
    final equipment = [
      if (text('cinema:3D') == 'yes') 'Projections 3D',
      if (text('wheelchair') == 'yes') 'Accès en fauteuil roulant',
      if (text('hearing_loop') == 'yes') 'Boucle auditive',
    ].join(' · ');
    return Cinema(
      id: '$type/$id',
      name: text('name:fr') ?? text('name') ?? 'Nom indisponible',
      latitude: lat,
      longitude: lon,
      city: text('addr:city'),
      address: address.isEmpty ? null : address,
      description: text('description:fr') ?? text('description'),
      descriptionSource:
          text('description:fr') != null || text('description') != null
          ? 'https://www.openstreetmap.org/$type/$id'
          : null,
      commons: text('wikimedia_commons'),
      imageReference: image,
      wikidata: RegExp(r'^Q[1-9]\d*$').hasMatch(text('wikidata') ?? '')
          ? text('wikidata')
          : null,
      wikipedia: text('wikipedia'),
      website: text('website') ?? text('contact:website'),
      screens: text('screen'),
      equipment: equipment.isEmpty ? null : equipment,
      imageUrl: uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
          ? image
          : null,
    );
  }
}

class CinemaPhoto {
  const CinemaPhoto({
    required this.url,
    required this.sourceUrl,
    required this.author,
    required this.license,
    required this.licenseUrl,
    this.credit = '',
    this.sourceName = 'Wikimedia Commons',
  });
  final String url;
  final String sourceUrl;
  final String author;
  final String license;
  final String licenseUrl;
  final String credit;
  final String sourceName;
}
