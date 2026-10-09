# CinéScope

Application universitaire Flutter/Dart pour découvrir des films et des cinémas,
puis vérifier sa distance à un établissement avec le GPS.

## Fonctionnalités

- **Films** : catalogue TMDB en français, affiches, date de sortie, note et fiche
  avec synopsis complet.
- **Cinémas** : établissements et coordonnées récupérés au format JSON via
  Overpass/OpenStreetMap, recherche d’une ville française et recherche « Autour
  de moi » avec le GPS. Le rayon de recherche est de 10 km.
- **Responsivité** : liste verticale sous 600 pixels, grille à partir de
  600 pixels ; pages de détail adaptées aux petits et grands écrans.
- **Navigation** : onglets Films/Cinémas, ouverture des fiches et retour au
  catalogue avec go_router.
- **« J’y suis ! »** : permission demandée à l’action, distance à vol d’oiseau,
  précision GPS annoncée et seuil de proximité de 200 mètres. GPS désactivé,
  permission refusée et délai dépassé sont gérés.
- **Robustesse** : chargement, erreurs, listes vides, relance manuelle, cache
  pendant la session et copie locale OSM de secours pour les zones couvertes.
- **Présentation** : interface shadcn_ui, thèmes clair/sombre et mascotte.

La fonction native choisie est le **GPS**. La caméra n’est pas implémentée :
le cahier des charges permet caméra **ou** GPS.

## Architecture et SDK

Flutter **3.47.6**, Dart **3.13.5**. Conserver `pubspec.lock` pour reproduire
les versions résolues.

```text
lib/
  app/         Application, navigation et configuration
  models/      Films, cinémas, zones et crédits photo
  services/    HTTP, recherche, enrichissement et GPS
  providers/   État partagé Riverpod
  pages/       Catalogues et fiches de détail
  widgets/     Cartes, images, recherche et informations de source
  theme/       Thèmes shadcn_ui
assets/data/   Copie OSM de secours, limitée à sa zone réelle
test/          Tests de services, modèles et interfaces
```

`ProviderScope` entoure l’application. Les services sont injectés par Riverpod,
les catalogues utilisent des `FutureProvider` et la zone sélectionnée un
`NotifierProvider`. L’interface écoute l’état avec `ref.watch` ; les actions
utilisent `ref.read`. Les clients HTTP et contrôleurs sont libérés.

| Dépendance principale | Version résolue |
| --- | --- |
| flutter_riverpod | 3.4.3 |
| go_router | 18.0.2 |
| http | 1.6.0 |
| shadcn_ui | 0.57.1 |
| geolocator | 14.1.1 |

## Installation et lancement

Installer Flutter, puis Android Studio avec la plateforme Android API 36,
Build-Tools, Platform-Tools et Command-line Tools. Examiner et accepter les
licences avec `flutter doctor --android-licenses` si nécessaire.
La compilation iOS nécessite macOS et Xcode.

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
```

Pour l’onglet Films, créer une configuration locale à partir du modèle :

```powershell
Copy-Item config/tmdb.example.json tmdb.env.json
```

Renseigner `TMDB_API_KEY` dans ce fichier. **Ne pas écraser un fichier local
déjà renseigné.** `tmdb.env.json` est ignoré par Git et n’est pas un asset.
Une variable de compilation peut être extraite de l’application compilée ;
elle ne constitue pas un coffre à secrets.

```powershell
flutter run -d chrome --dart-define-from-file=tmdb.env.json
```

Sans clé, l’application démarre et les cinémas restent disponibles ; l’onglet
Films signale l’absence de configuration TMDB.

## Sources et photos

- Cinémas et coordonnées : [OpenStreetMap](https://www.openstreetmap.org/copyright)
  via Overpass, attribution ODbL affichée dans l’application.
- Recherche de villes : [API Découpage administratif](https://geo.api.gouv.fr/).
- Descriptions : texte OpenStreetMap, introduction Wikipédia en français si
  un article explicitement lié correspond au lieu, puis description Wikidata.
  À défaut, une synthèse des champs OSM disponibles est affichée avec sa source
  (nom, ville, adresse, salles et équipements renseignés).
- Photos : références Commons présentes dans OSM, propriété P18 de Wikidata
  ou image libre de l'article Wikipédia vérifié. L'identifiant, les coordonnées,
  la page du fichier, l'auteur et la licence sont contrôlés. Les crédits sont
  accessibles depuis l'image et la fiche. Les coordonnées GPS restent celles
  d'OpenStreetMap.

Une photo réelle ne peut être garantie pour chaque lieu : les bases ouvertes
ne renseignent pas toujours une image exploitable. Le pictogramme signale alors
l'absence de photo ; aucune photo d'un autre cinéma n'est substituée. Une panne
de Wikimedia conserve le catalogue et les informations OSM. Les séances et
les horaires se consultent auprès des cinémas.

La copie `cinemas_osm.json` couvre quatre établissements d’Aix-en-Provence et
Marseille. Elle est filtrée par zone et son utilisation est signalée ; elle
ne remplace pas une API nationale ni un cache persistant des recherches.

## Vérifications

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Vérification du 9 octobre 2026 : **143 tests réussis**, `flutter analyze --no-pub`
sans problème et `git diff --check` sans erreur. `flutter doctor -v` ne
signalait aucun problème après la réinstallation.

Les tests couvrent notamment le JSON, HTTP et les délais, le cache et le
secours local, la recherche de villes, la navigation, les largeurs de 320 à
1200 pixels, les permissions GPS et le calcul de distance avec un plugin simulé.
Les tests d’enrichissement vérifient les sources, la correspondance géographique,
les licences, les erreurs réseau et le maintien des données existantes.

## Démonstration GPS sur Samsung

1. Brancher le téléphone, activer le débogage USB, déverrouiller l’écran et
   accepter l’autorisation de cet ordinateur. Activer la localisation.
2. Relever son identifiant avec `flutter devices`, puis lancer :

   ```powershell
   flutter run -d IDENTIFIANT_SAMSUNG --dart-define-from-file=tmdb.env.json
   ```

3. Ouvrir **Cinémas**, rechercher sa ville, choisir
   la commune proposée et ouvrir une fiche. Vérifier les informations, la photo
   et ses crédits si disponibles, puis les coordonnées. Appuyer sur **J’y suis !**
   et autoriser la localisation précise pendant l’utilisation.
4. Vérifier l’affichage de la distance et de la précision. Une distance
   supérieure à 200 m doit indiquer que le téléphone est éloigné ; ne pas
   attendre une confirmation de proximité depuis son domicile.
5. Désactiver la localisation et recommencer : un message explicite doit
   apparaître. Réactiver le GPS ensuite.
6. Refuser la permission dans les paramètres Android de l’application et
   recommencer : aucune présence ne doit être confirmée. Rétablir la
   permission après le test. Vérifier également « Autour de moi ».

La position est obtenue à la demande. Le calcul de distance s’effectue dans
l’application ; la recherche « Autour de moi » transmet le centre de la zone
de recherche à Overpass. Aucun historique de positions n’est enregistré.
