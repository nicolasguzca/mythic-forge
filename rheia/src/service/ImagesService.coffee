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
  'underscore'
  'utils/utilities'
], (_, utils) ->

  # Instanciated as a singleton in `app.imagesService` by the Router
  class ImagesService

    # **private**        
    # Temporary storage of loading images.
    _pendingImages: []

    # **private**
    # Image local cache, that store Image objects
    _cache: {}
    
    # **private**
    # Timestamps added to image request to server, avoiding cache
    _timestamps: {}

    # Constructor. 
    constructor: ->
      app.router.on 'loadImage', @load
    
    # Load an image. Once it's available, `imageLoaded` event will be emitted on the bus.
    # If this image has already been loaded (url used as key), the event is imediately emitted.
    #
    # @param image [String] the image **ABSOLUTE** url
    # @return true if the image wasn't loaded, false if the cache will be used
    load: (image) =>
      isLoading = false
      return isLoading unless image?
      # Use cache if available, with a timeout to simulate asynchronous behaviour
      if image of @_cache
        _.defer =>
          app.router.trigger 'imageLoaded', true, image, "#{image}?#{@_timestamps[image]}"
      else unless image in @_pendingImages
        @_pendingImages.push image
        # creates an image facility
        imgData = new Image()
        # bind loading handlers
        $(imgData).load @_onImageLoaded
        $(imgData).error @_onImageFailed
        @_timestamps[image] = new Date().getTime()
        # adds a timestamped value to avoid browser cache
        imgData.src = "#{image}?#{@_timestamps[image]}"
        isLoading = true
      isLoading

    # Returns the image content from the cache, or null if the image was not requested yet
    getImage: (image) =>
      return null unless image of @_cache
      @_cache[image]

    # Uploads a type or instance image for a given model.
    # Triggers the `imageUploaded` event at the end, with the image name and model id in parameter.
    #  
    # @param modelName [String] class name of the saved model
    # @param id [String] the concerned model's id
    # @param file [File] file object containing datas
    # @param idx [Number] for instance images, specify the image rank. null for type images
    upload: (modelName, id, file, idx = null) =>
      reader = new FileReader()

      # when image data was read
      reader.onload = (event) =>
        # computes image type, and remove the type prefix
        ext = file.type.replace 'image/', ''
        data = event.target.result.replace "data:#{file.type};base64,", ''

        # file's name for cache
        src = "/images/#{id}-#{if idx? then idx else 'type'}.#{ext}"
        
        # update cache content
        delete @_cache[src]
        delete @_timestamps[src]

        # wait for server response
        app.sockets.admin.on 'uploadImage-resp', (reqId, err, saved) =>
          throw new Error "Failed to upload image for model #{modelName} #{id}: #{err}" if err?
          # populate cache
          @load src

          console.log "image #{src} uploaded"
          # trigger end of upload
          app.router.trigger 'imageUploaded', saved.id, src

        console.log "upload new image #{src}..."
        # upload data to server
        if idx?
          console.log "upload image ##{idx} of type #{modelName} #{id}"
          app.sockets.admin.emit 'uploadImage', utils.rid(), modelName, id, ext, data, idx
        else 
          console.log "upload type image of type #{modelName} #{id}"
          app.sockets.admin.emit 'uploadImage', utils.rid(), modelName, id, ext, data

      # read data from file
      reader.readAsDataURL file

    # Removes a type or instance image for a given model.
    # Triggers the `imageRemoved` event at the end, with the image name and model id in parameter.
    #  
    # @param modelName [String] class name of the saved model
    # @param id [String] the concerned model's id
    # @param oldName [String] oldName for cache invalidation
    # @param ids [Number] for instance images, specify the image rank. null for type images
    remove: (modelName, id, oldName, idx = null) =>       
      # file's name for cache
      src = "/images/#{oldName}"
      # update cache content
      delete @_cache[src]

      # wait for server response
      rid = utils.rid()
      listener = (reqId, err, saved) =>
        return unless reqId is rid
        app.sockets.admin.on 'removeImage-resp', listener
        throw new Error "Failed to remove image for model #{modelName} #{id}: #{err}" if err?
        console.log "image #{src} removed"
        # trigger end of upload
        app.router.trigger 'imageRemoved', saved.id, src
      app.sockets.admin.on 'removeImage-resp', listener

      console.log "removes new image #{src}..."
      # remove image from server
      if idx?
        app.sockets.admin.emit 'removeImage', rid, modelName, id, idx
      else 
        app.sockets.admin.emit 'removeImage', rid, modelName, id

    # **private**
    # Handler invoked when an image finisedh to load. Emit the `imageLoaded` event. 
    #
    # @param event [Event] image loading success event
    _onImageLoaded: (event) =>
      src = event.target.src.replace /\?\d*$/, ''
      src = _.find @_pendingImages, (image) -> _(src).endsWith image
      return unless src?
      # Remove event from pending array
      @_pendingImages.splice @_pendingImages.indexOf(src), 1
      # Store Image object and emit on the event bus
      console.log 'store in cache src', src
      @_cache[src] = event.target
      app.router.trigger 'imageLoaded', true, src, "#{src}?#{@_timestamps[src]}"
  
    # **private**
    # Handler invoked when an image failed loading. Also emit the `imageLoaded` event.
    # @param event [Event] image loading fail event
    _onImageFailed: (event) =>
      src = event.target.src.replace /\?\d*$/, ''
      src = _.find @_pendingImages, (image) -> _(src).endsWith image
      return unless src?
      console.log "image #{src} loading failed"
      # Remove event from pending array
      @_pendingImages.splice @_pendingImages.indexOf(src), 1
      # Emit an error on the event bus
      app.router.trigger 'imageLoaded', false, src