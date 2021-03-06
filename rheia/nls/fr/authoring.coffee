###
  Copyright 2010~2014 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

define
  titles:
    newFolder: "Création d'un dossier"
    newFile: "Création d'un fichier"
    renameFSItem: "Renommage/déplacement"

  buttons:
    rename: 'renommer'
    
  labels:
    fsItemName: 'nom'
    newFile: 'Créer un fichier'
    newFolder: 'Créer un dossier'
    openFSItem: 'Ouvrir "%s"'
    removeFSItem: 'Supprimer "%s"'
    renameFSItem: 'Renommer "%s"'
    rootFolder: 'la racine'

  msgs:
    closeFileConfirm: "<p>Vous avez modifié le fichier <b>%s</b>.</p><p>Voulez-vous sauver les modifications avant de fermer l'onglet ?</p>"
    externalChangeFSItem: "Ce fichier a été modifié par ailleurs. Son contenu à été mis à jour"
    fsItemCreationFailed: "<p><b>%1$s</b> n'a pas pû être sauvé sur le serveur :</p><p>%2$s</p>" 
    newFile: 'Veuillez choisir un nom (avec extension) pour le fichier dans <b>%s</b> :'
    newFolder: 'Veuillez choisir un nom pour le dossier dans <b>%s</b> :'
    removeFileConfirm: "<p>Voulez-vous vraiment supprimer le fichier <b>%s</b> ?</p>"
    removeFolderConfirm: "<p>Voulez-vous vraiment supprimer le dosser <b>%s</b> et tout son contenu ?</p>"
    renameFile: 'Veuillez choisir un nouveau nom ou chemin pour le fichier :'
    renameFolder: 'Veuillez choisir un nouveau nom ou chemin pour le dossier :'

  tips:
    newFile: 'Crée un nouveau fichier dans le dossier séléctioné ou la racine'
    newFolder: 'Crée un nouveau dossier dans le dossier séléctioné ou la racine'
    uploadInSelected: 'Upload un nouveau fichier dans le dossier séléctioné ou la racine'
    removeFile: "Supprime le fichier en cours d'édition"
    removeFolder: 'Supprime le dossier séléctioné'
    renameSelected: 'Renome le fichier ou dossier séléctioné'
    saveFile: "Sauve le fichier en cours d'édition"
    searchFiles: """
      <p>Filtrez les fichiers de l'explorateur en fonction de leur contenu.</p>
      <p>Vous pouvez utiliser une expression régulière, avec le caractère '/' en début et en fin.</p>
      <p>Les modifieurs 'i' et 'm' sont supportés : par exemple <var>/app(llication)?/i</var></p>
      <p>Vous pouvez indiquer les extensions des fichiers dans lesquels rechercher, en les séparant par des virgules. Par exemple <var>css,styl</var> pour chercher dans les feuilles de styles.</p>
      <p>Pour exclure des extensions, préfixez le tout par '-'. Par exemple : <var>-jpg,png,gif</var> pour chercher partout sauf dans les images.</p>
    """