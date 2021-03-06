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
  'jquery'
  'underscore'
  'view/BaseView'
  'i18n!nls/common'
  'utils/utilities'
  'utils/validators'
  'widget/property'
], ($, _, BaseView, i18n, utilities, validators) ->

  # Base class for edition views
  class BaseEditionView extends BaseView

    # **private**
    # arrays of validators.
    _validators: []

    # **private**
    # array of files that needs to be uploaded
    _pendingUploads: []

    # ** private**
    # the action bar with save, remove and addProperty buttons
    _actionBar: null

    # **private**
    # save button widget
    _saveButton: null

    # **private**
    # remove button widget
    _removeButton: null

    # **private**
    # description image widget
    _descImageWidget: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, of null for a creation.
    # @param className [String] rendering root node Css class.
    constructor: (id, className) ->
      super id, className

      # bind change event to the update of action button bar
      @on 'change', =>
        return unless @_actionBar?
        if @canSave() then @_saveButton.enable() else @_saveButton.disable()
        if @canRemove() then @_removeButton.enable() else @_removeButton.disable()

      @_pendingUploads = []

    # Indicates wether or not this object can be saved.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the savable status of this object
    canSave: => @_canSave and @_pendingUploads.length is 0

    # Returns the view's title
    #
    # @param confirm [Boolean] true to get the version of the title for confirm popups. Default to false.
    # @return the edited object name.
    getTitle: (confirm = false) => 
      if confirm then @model.id else _.truncate (@model.id), 15

    # Returns the view's action bar, and creates it if needed.
    # may be overriden by subclasses to add buttons
    #
    # @return the action bar rendering.
    getActionBar: =>
      return @_actionBar if @_actionBar?
      # creates the rendering
      @_actionBar = $('<div><a href="#" class="save"></a>'+
        '<a href="#" class="remove"></a>'+
        '<a href="#" class="addProperty"></a></div>')
      # wire the save button
      @_saveButton = @_actionBar.find('.save')
        .attr('title', i18n.tips.save)
        .button(
          icons: 
            primary: 'save small'
          text: false
        )
        .click(@saveModel)
        .data 'button'
      # wire the remove button
      @_removeButton = @_actionBar.find('.remove')
        .attr('title', i18n.tips.remove)
        .button(
          icons:
            primary: 'remove small'
          text: false
          disabled: true
        )
        .click(@removeModel)
        .data 'button'
      @_actionBar

    # Enrich the inherited dispose method to free validators.
    dispose: =>
      validator.dispose() for validator in @_validators
      super()

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Creates validator and instanciate widgets
    _specificRender: =>
      # creates all validators.
      @_createValidators()

    # **private**
    # Allows subclass to add specific errors to be displayed when validating.
    # **May be overriden by subclasses**
    #
    # @return an empty array of errors by default.
    _specificValidate: =>
      []

    # **private**
    # Performs view specific save operations, right before saving the model.
    # Manage uploads.
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: =>
      # manage uploads
      if @_descImageWidget? and @model.descImage isnt @_descImageWidget.options.source
        spec = file: @_descImageWidget.options.source
        if @_descImageWidget.options.source is null
          spec.oldName = @model.descImage
        @_pendingUploads.push spec

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # we only are concerned by setting to null, because image upload is managed by `_onSave`
      @model.descImage = null if @_descImageWidget? and @_descImageWidget.options.source is null
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_createImages()
      @_onChange()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      comparable = []
      # adds name and description
      if @_descImageWidget?
        comparable.push
          name: 'descImage'
          original: @model.descImage
          current: @_descImageWidget.options.source
      comparable

    # **private**
    # Creates LoadableImage for each images of the edited object
    _createImages: =>
      # the description image
      unless @_descImageWidget?
        @_descImageWidget = @$el.find('.desc.image').loadableImage(
          source: @model.descImage
        ).on('change', @_onChange
        ).data 'loadableImage'
      else 
        @_descImageWidget.setOption 'source', @model.descImage

    # **private**
    # Re-creates validators, when refreshing the properties.
    # Existing validators are trashed, and validators created for:
    # - name
    _createValidators: =>
      validator.dispose() for validator in @_validators
      @_validators = []

    # **private**
    # Allows to compute the rendering's validity.
    # 
    # @return true if all rendering's fields are valid
    _validate: =>
      isValid = true;
      errors = []
      # view own validators
      errors = errors.concat validator.validate() for validator in @_validators 
      # allows subclass to add specific errors
      errors = errors.concat @_specificValidate()

      container = @$el.find('.errors').empty()
      container.append "<p>#{error.msg}</p>" for error in errors
      @$el.toggleClass 'error', errors.length isnt 0
      errors.length is 0

    # **private**
    # Change handler, wired to any changes from the rendering.
    # Checks if the edited object effectively changed, and update if necessary the action bar state.
    _onChange: =>
      # first, rendering validity
      isValid = @_validate()
      hasChanged = false

      if isValid
        # compares rendering and model values
        comparableFields = @_getComparableFields()
        for field in comparableFields
          hasChanged = !(_.isEqual(field.original, field.current))
          if hasChanged
            console.log "field #{field.name} modified"
            break;

      console.log "is valid ? #{isValid} is modified ? #{hasChanged} is new ? #{@_isNew}"
      @_canSave = isValid and (hasChanged or @_isNew)

      # inherited method call
      super()

    # **private**
    # Invoked when a model is saved from the server.
    # Refresh internal and rendering if the saved object corresponds to the edited one.
    #
    # @param saved [Object] the saved model
    _onSaved: (saved) =>
      super(saved)
      return unless @_pendingUploads.length > 0

      spec = @_pendingUploads.splice(0, 1)[0]
      @_saveInProgress = true
      if 'oldName' of spec
        # removes existing data
        app.imagesService.remove @model._className, @model.id, spec.oldName, if spec.idx? then spec.idx
      else
        # upload new file data
        app.imagesService.upload @model._className, @model.id, spec.file, if spec.idx? then spec.idx