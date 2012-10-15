###
  Copyright 2010,2011,2012 Damien Feugas
  
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
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/item.html'
  'view/moderation/BaseLinkedView'
  'model/Item'
  'model/Map'
  'widget/carousel'
], ($, i18n, i18nModeration, template, BaseLinkedView, Item, Map) ->

  i18n = $.extend true, i18n, i18nModeration

  # Displays and edit an Item in moderation perspective
  class ItemView extends BaseLinkedView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Item.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeItemConfirm

    # **private**
    # Message displayed when an external message was applied.
    _externalChangeMessage: i18n.msgs.itemExternalChange

    # **private**
    # indicates wether or not this item has quantity
    _hasQuantity: false

    # **private**
    # select to display current map
    _mapList: null

    # **private**
    # field to input abscissa
    _xWidget: null

    # **private**
    # field to input ordinate
    _yWidget: null

    # **private**
    # image carousel widget
    _imageWidget: null

    # **private**
    # widget to manage quantity
    _quantityWidget: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, null for creation
    # @param @_created [Object] a freshly created model, null for existing model
    constructor: (id, @_created) ->
      # superclass constructor
      super id, 'item-type', @_created

      # bind to map collection events: update map list.
      @bindTo Map.collection, 'add', @_onMapListRetrieved
      @bindTo Map.collection, 'remove', (map) => 
        if @model.get('map')?.equals map 
          # the item's map is removed: closes view
          @_removeInProgress = true
          @_onRemoved @model
        else 
          @_onMapListRetrieved()
      console.log "creates item edition view for #{if id? then @model.id else 'a new object'}"

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> i18n: i18n, title: _.sprintf i18n.titles.item, @model.get('type').get('name'), @model.id or '~'

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Adds image carousel, map controls, and properties rendering
    _specificRender: =>
      # creates image carousel and map rendering
      @_imageWidget = @$el.find('.left .image').carousel(
        images: _.pluck @model.get('type').get('images'), 'file'
        change: @_onChange
      ).data 'carousel'

      @_mapList = @$el.find '.map.field'
      @_mapList.on 'change', =>
        # enable/disable coordinates
        mapId = @_mapList.find('option').filter(':selected').val()
        if mapId is 'none'
          @_xWidget?.setOption 'value', null
          @_yWidget?.setOption 'value', null
        else
          @_xWidget?.setOption 'value', @model.get('x') or 0
          @_yWidget?.setOption 'value', @model.get('y') or 0
        @_onChange()

      @_onMapListRetrieved()

      @_xWidget = @$el.find('.x.field').property(
        type: 'integer'
        allowNull: true
        change: @_onChange
      ).data 'property'

      @_yWidget = @$el.find('.y.field').property(
        type: 'integer'
        allowNull: true
        change: @_onChange
      ).data 'property' 

      @_quantityWidget = @$el.find('.quantity.field').property(
        type: 'float'
        allowNull: false
        change: @_onChange
      ).data 'property'

      super()

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      super()

      # image number
      @model.set 'imageNum', @_imageWidget.options.current

      # map ownership
      @model.set 'map', Map.collection.get @_mapList.find('option').filter(':selected').val()
      @model.set 'x', @_xWidget.options.value
      @model.set 'y', @_yWidget.options.value
      @model.set 'quantity', @_quantityWidget.options.value if @_hasQuantity
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_hasQuantity = @model.get('type')?.get 'quantifiable'
      @$el.find('.quantity').toggle @_hasQuantity
      
      # image number
      @_imageWidget.setOption 'current', @model.get 'imageNum'

      # map ownership
      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected'
      @_xWidget.setOption 'value', @model.get 'x'
      @_yWidget.setOption 'value', @model.get 'y'
      @_quantityWidget.setOption 'value', @model.get 'quantity' if @_hasQuantity

      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      comparable = super()
      return comparable unless @_yWidget?

      mapValue =  @_mapList.find('option').filter(':selected').val()
      mapValue = undefined if mapValue is 'none'
      comparable.push
        # image number
        name: 'imageNum'
        original: @model.get 'imageNum'
        current: @_imageWidget.options.current
      ,
        # map ownership
        name: 'map'
        original: @model.get('map')?.id
        current: mapValue
      ,
        name: 'x'
        original: @model.get 'x'
        current: @_xWidget.options.value
      ,
        name: 'y'
        original: @model.get 'y'
        current: @_yWidget.options.value

      if @_hasQuantity
        comparable.push 
          name: 'quantity'
          original: @model.get 'quantity'
          current: @_quantityWidget.options.value 

      comparable

    # **private**
    # Empties and fills the map list.
    _onMapListRetrieved: =>
      maps = "<option value='none'>#{i18n.labels.noMap}</option>"
      maps += "<option value='#{map.id}'>#{map.get 'name'}</option>" for map in Map.collection.models   
      @_mapList.empty().append maps      

      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected' if @model?.get('map')?