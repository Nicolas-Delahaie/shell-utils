# Todo

1. Ecrire une documentation dans le code
2. Echo un gros message explicatif au debut du script
3. Tout mettre en anglais
4. Améliorer la partie moche de
   1. Suppression backup
   2. Renommage backup
   3. Suppression du upstream
5. Ecrire le readme
6. Retirer les commits squashés de la backup (pick UNIQUEMENT les commits de la branche elle même)

Ameliorations

1. Vérifier l'état avant le script
   1. Aucune modification en attente
   2. Pas de branche en cours de merge
   3. Branches à merger bien à jour avec le remote ?
2. Vérifier que le tag avec le numero du merge precedent est bien present
3. Créer la branche de backup si elle n'existe pas
4. Créer un catch all qui remet le git dans l'etat precedent, en retirant toutes les modifs en attente etc
5. Ne plus regarder la branche de destination, mais l'emplacement actuel
   1. Plus besoins de reset master au commit de merge souhaité, juste de se déplacer dessus
6. Rédiger des tests unitaires avec 100% de couverture
