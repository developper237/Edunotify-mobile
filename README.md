&#x20;EduNotify Mobile



Application mobile Flutter pour la plateforme EduNotify.



\## Prérequis



Installe les outils suivants avant de lancer le projet :



\### Git



Téléchargement :



https://git-scm.com/downloads



Vérification :



```bash

git --version

```



\### Flutter SDK



Téléchargement :



https://flutter.dev/docs/get-started/install



Vérification :



```bash

flutter --version

```



\### Android Studio



Téléchargement :



https://developer.android.com/studio



Composants requis :



\* Android SDK

\* Android SDK Platform

\* Android SDK Build Tools

\* Android Emulator



Vérification :



```bash

flutter doctor

```



\### Visual Studio Code



Téléchargement :



https://code.visualstudio.com



Extensions recommandées :



\* Flutter

\* Dart



\## Cloner le projet



```bash

git clone https://github.com/developper237/Edunotify-mobile.git

cd Edunotify-mobile

```



\## Installer les dépendances



```bash

flutter pub get

```



\## Vérifier la configuration Flutter



```bash

flutter doctor

```



Tous les éléments doivent être validés.



\## Configuration Firebase



Les fichiers Firebase ne sont pas inclus dans le dépôt.



Ajouter :



\### Android



```text

android/app/google-services.json

```



\### iOS



```text

ios/Runner/GoogleService-Info.plist

```



Obtenir ces fichiers depuis Firebase Console.



\## Lancer l'application



Lister les appareils disponibles :



```bash

flutter devices

```



Lancer l'application :



```bash

flutter run

```



\## Générer un APK



```bash

flutter build apk --release

```



L'APK sera généré dans :



```text

build/app/outputs/flutter-apk/

```



\## Structure du projet



```text

lib/

├── core/

├── features/

├── assets/

└── main.dart

```



\## Dépannage



Nettoyer le projet :



```bash

flutter clean

```



Réinstaller les dépendances :



```bash

flutter pub get

```



Vérifier la configuration :



```bash

flutter doctor

```



\## Technologies utilisées



\* Flutter

\* Dart

\* Firebase Cloud Messaging

\* REST API

\* Provider



