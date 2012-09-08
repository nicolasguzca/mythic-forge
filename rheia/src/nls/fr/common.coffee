###
  Copyright 2010,2011,2012 Damien Feugas
  
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
    serverError: 'Erreur server'
    loginError: 'Erreur de connexion'
    editionPerspective: 'Edition du monde'
    authoringPerspective: 'Client de jeu'
    removeConfirm: 'Suppression'
    closeConfirm: 'Fermeture'
    external: 'Modification externe'
    categories:
      items: 'Objets'
      maps: 'Cartes'
      events: 'Evènements'
      rules: 'Règles'
      turnRules: 'Règles de tour'
      fields: 'Terrains'
    login: 'Rheia - Connexion'
      
  labels:
    create: 'Créer'
    enterLogin: 'Identifiant : '
    enterPassword: 'Mot de passe : '
    connectWith: 'Connectez vous avec :'
    orConnect: 'ou'

  buttons:
    login: 'Entrer'
    google: 'Google'
    yes: 'Oui'
    no: 'Non'
    ok: 'Ok'
    cancel: 'Annuler'
    logout: 'Sortir'

  validator:
    required: 'la valeur de "%s" est requise'
    spacesNotAllowed: '"%s" ne peut pas contenir d\'espaces'
    unmatch: '"%s" ne correspond pas à la valeur attendue'

  msgs:
    closeConfirm: "<p>Vous avez modifié <b>%s</b>.</p><p>Voulez-vous sauver les modifications avant de fermer l'onglet ?</p>"
    externalChange: "<p><b>%s</b> a été modifié par un autre administrateur.</p><p>Ses valeurs ont été mises à jour.</p>"
    externalRemove: "<p><b>%s</b> a été supprimé par un autre administrateur.</p><p>L'onglet a été fermé.</p>"
    saveFailed: "<p><b>%1s</b> n'a pas pû être sauvé sur le serveur :</p><p>%2s</p>" 
    removeFailed: "<p><b>%1s</b> n'a pas pû être supprimé du serveur :</p><p>%2s</p>"
    searchFailed: 'La recherche à échouée :<br/><br/>%s'
    powered: 'Powered by <a target="blanck" href="http://github.com/feugy/mythic-forge">Mythic-Forge</a>'
    copyright: '&copy; 2010-2012 Damien Feugas'
    wrongCredentials: '<p>Le login est inconnu ou le mot de passe érroné.</p><p>Veuillez rééssayer</p>'
    expiredToken: '<p>Votre session a expirée.</p><p>Veuillez vous reconnecter</p>'