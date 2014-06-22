###
  Copyright 2010~2014 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'model/BaseModel'
  'utils/utilities'
], (Base, utils) ->

  # Client cache of FSItems.
  class _FSItems extends Base.Collection

    # Flag used to distinguish moves from removals
    # Must be set to true when moving file.
    moveInProgress: false

    # **private**
    # Temporary stores callback of `restorables()` calls
    _restorablesCallback: []

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FSItem'
      
    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (model, @options) ->
      super model, options
      
      utils.onRouterReady =>
        # bind consultation response
        app.sockets.admin.on 'read-resp', @_onRead
        app.sockets.admin.on 'move-resp', (reqId, err) =>
          return app.router.trigger 'serverError', err, method:'FSItem.sync', details:'move' if err? 
          @moveInProgress = false

        # history() and readVersion() handlers
        app.sockets.admin.on 'history-resp', @_onHistory
        app.sockets.admin.on 'readVersion-resp', @_onReadVersion
        app.sockets.admin.on 'restorables-resp', (reqId, err, restorables) =>
          if err?
            app.router.trigger 'serverError', err, method:'FSItem.restorables' 
            restorables = []
          else
            # build FSItems
            restorable.item = new FSItem restorable.item for restorable in restorables

          # invoke all registered callbacks
          callback restorables for callback in @_restorablesCallback
          @_restorablesCallback = []

        app.sockets.admin.on 'deployement', (state, number, version) =>
          switch state
            when 'VERSION_CREATED', 'VERSION_RESTORED' 
              # update content and history for items that need it
              for model in @models
                @fetch item: model if model.content?
                model.fetchHistory() if model.history?

    # Provide a custom sync method to wire FSItems to the server.
    # Only read operation allowed.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments. May content:
    # @options item [FSItem] the read FSItem. If undefined, read root
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on Items" unless 'read' is method
      item = args?.item
      # Ask for the root content if no item specified
      return app.sockets.admin.emit 'list', utils.rid(), 'FSItem' unless item?
      # Or read the item
      return app.sockets.admin.emit 'read', utils.rid(), item._serialize()

    # List all restorables files
    #
    # @param callback [Function] end callback, invoked with
    # @option callback restorables [Array] an array (may be empty) containing for each restorable file an objects with `item` and `id` attributes
    restorables: (callback) =>
      # stores callback and ask to server if we have one callback. 
      @_restorablesCallback.push callback
      app.sockets.admin.emit 'restorables', utils.rid() if @_restorablesCallback.length is 1

    # **private**
    # Enhanced to dencode file content from base64.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      
      # manage restored state
      existing = @get model.path
      if existing?
        existing.restored = false
        @_onUpdate className, model
      else
        # transforms from base64 to utf8 string
        model.content = atob model.content unless model.isFolder or model.content is null
        super className, model

    # **private**
    # Enhanced to decode file content from base64.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      # transforms from base64 to utf8 string
      changes.content = atob changes.content unless changes.isFolder or changes.content is null
      super className, changes

      # update history if needed
      model = @get changes[@model.prototype.idAttribute]
      if model?.history?
        if model.history[0]?.id isnt ''
          # add a fake history entry for current version
          model.history.splice 0, 0, 
            id: ''
            author: null
            message: null
        # update date to now
        model.history[0].date = new Date changes.updated
        model.trigger 'history', model

    # **private**
    # Enhanced to remove item under the removed one
    #
    # @param className [String] the deleted object className
    # @param model [Object] deleted model.
    # @param options [Object] remove event options
    _onRemove: (className, model, options = {}) =>
      return unless className is @_className
      # removes also models under the removed one
      if model.isFolder
        subModels = @find (item) -> 0 is item.id.indexOf model.path  
        @remove new @model(removed), silent:true for removed in subModels

      # at last, removes from its parent content
      parent = model.path.substring 0, model.path.lastIndexOf conf.separator
      if parent isnt ''
        parent = @where path: parent
        if parent.length is 1 and parent[0].content?
          # search within parent content, and remove at relevant index
          for contained, i in parent[0].content when contained.id is model.path
            parent[0].get('content').splice i, 1
            break

      # add a special flag to distinguish removal from move
      options.move= true if @moveInProgress
      super className, model, options

    # **private**
    # End of a FSItem content retrieval. For a folder, adds its content. For a file, triggers an update.
    #
    # @param reqId [String] client request id
    # @param err [String] an error message, or null if no error occured
    # @param rawItem [Object] the raw FSItem, populated with its content
    _onRead: (reqId, err, rawItem) =>
      return app.router.trigger 'serverError', err, method:"FSItem.collection.sync", details:'read' if err?
      if rawItem.isFolder
        # add all folder content inside collection
        @add rawItem.content
        
        # replace raw content by models
        rawItem.content[i] = @get subItem.path for subItem, i in rawItem.content

        # insert folder to allow further update
        item = @get rawItem.path
        @add rawItem unless item?

      # trigger update 
      @_onUpdate 'FSItem', rawItem

    # **private**
    # File history retrieval handler. 
    # Triggers an 'history' event on the concerned FSItem after having filled its history attribute
    # Wired on collection to avoid multiple listeners. 
    #
    # @param reqId [String] client request id
    # @param err [String] error string, or null if no error occured
    # @param item [FSItem] raw concerned FSItem
    # @param history [Array] array of commits, containing `author`, `date`, `id` and `message` attributes
    _onHistory: (reqId, err, item, history) =>
      # silently ignore errors regarding unexisting items when fetching history:
      # can occur when displaying file not yet saved on server
      # and when restoring version that do not include an opened file
      return if err?.toString()?.indexOf('Unexisting item') >= 0
      return app.router.trigger 'serverError', err, method:"FSItem.fetchHistory" if err? 
      item = @get item.path
      if item?
        item.history = history
        # reconstruct dates
        commit.date = new Date commit.date for commit in history
        item.trigger 'history', item

    # **private**
    # File version retrieval handler. 
    # Triggers an 'version' event on the concerned FSItem with its content as parameter
    # Wired on collection to avoid multiple listeners. 
    #
    # @param reqId [String] client request id
    # @param err [String] error string, or null if no error occured
    # @param item [FSItem] raw concerned FSItem
    # @param content [String] utf8 encoded file content
    _onReadVersion: (reqId, err, item, content) =>
      return app.router.trigger 'serverError', err, method:"FSItem.fetchVersion" if err? 
      item = @get(item.path)
      if item?
        item.restored = true
        item.trigger 'version', item, atob content

  # Modelisation of a single File System Item.
  class FSItem extends Base.Model

    # FSItem local cache.
    # A Backbone.Collection subclass
    @collection: new _FSItems @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FSItem'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['path', 'isFolder', 'content', 'updated']

    # bind the Backbone attribute to the path name
    idAttribute: 'path'

    # File extension, if relevant
    extension: ''

    # Special status to indicate this FSItem in restoration.
    restored: false

    # File history. Null until retrieved with `fetchHistory()`
    history: null

    # FSItem constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes
      restored = false
      history = null
      # update file extension
      @extension = @get('path').substring(@get('path').lastIndexOf('.')+1).toLowerCase() unless @get 'isFolder'

    # Allows to move the current FSItem
    move: (newPath) =>
      newPath = newPath.replace( /\\/g, conf.separator).replace /\//g, conf.separator
      FSItem.collection.moveInProgress = true
      app.sockets.admin.emit 'move', utils.rid(), @_serialize(), newPath

    # fetch history on server, only for files
    # an `history` event will be triggered on model once retrieved
    fetchHistory: =>
      return if @get 'isFolder'
      app.sockets.admin.emit 'history', utils.rid(), @_serialize()

    # fetch a given version on server, only for files.
    # an `version` event will be triggered on model once retrieved
    #
    # @param version [String] retrieved version id. null or empty to restore last uncommited version
    fetchVersion: (version) =>
      return if @get 'isFolder'
      console.debug "fetch version #{version or 'current'} for #{@id}"
      if version
        app.sockets.admin.emit 'readVersion', utils.rid(), @_serialize(), version
      else
        @restored = false
        @trigger 'version', @

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Enhanced to encode in base64 file content.
    #
    # @return a serialized version of this model
    _serialize: => 
      raw = super()
      # transforms from utf8 to base64 string
      raw.content = btoa raw.content unless raw.isFolder or raw.content is null
      raw
