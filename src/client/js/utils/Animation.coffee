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
###

define [
  'backbone'
  'underscore'
  'jquery'
], (Backbone, _, $) ->

  # List of executing animations
  _anims = []

  # The unic animation loop
  _loop = (time) ->
    # request another animation frame for next rendering.
    requestAnimationFrame _loop 
    if document.hidden
      # if document is in background, animations will stop, so stop animations.
      time = null
    # trigger onFrame for each executing animations
    for anim in _anims
      anim._onFrame time if anim isnt undefined

  # starts the loop at begining of the game
  _loop new Date().getTime()

  # getter for document visibility
  prefix = if $.browser.webkit then 'webkit' else 'moz'
  # define a getter for page visibility
  Object.defineProperty document, 'hidden', 
    get: () ->
      document[prefix+'Hidden']
  
  # The Animation class performs the sprite animation loop for a given item.
  # It changes sprite, and moves the rendering if needed, all along the animation
  # Two events are triggered: 'start' and 'end'
  #
  class Animation

    # the concerned item
    item: null

    # the corresponding rendering.
    rendering: null

    # if the animation also moves the rendering, the final position's left.
    left: null

    # if the animation also moves the rendering, the final position's bottom.
    bottom: null

    # **private**
    # start of the animation
    _start: null

    # **private**
    # sprite definition of the animated item, enhanced with tile width
    _sprite: null
    
    # **private**
    # current sprite number displayed
    _step: 0

    # Construct an animation, but do not starts it.
    #
    # @param item [Item] the concerned item
    # @param rendering [DOM] its animated rendering.
    #
    constructor: (@item, @rendering) ->
      # remove the transition used
      transitions = @item.get('transition').split ','
      transition = transitions.splice(0, 1)[0]
      @item.set 'transition', if transitions.length isnt 0 then transitions.join ',' else null
      # gets the item sprite.
      imageDef = @item.get('type').get('images')[@item.get('imageNum')]
      @_sprite = imageDef.sprites[transition]
      @_sprite.width = imageDef.width
      @_step= 0
      # set the sprite row
      @item.shiftLeft = 0
      @item.shiftTop = -@_sprite.vOffset          

    # Starts effectively the animation, and trigger the 'start' event.
    # 
    start: =>
      @_start = new Date().getTime()

      # if we moved, compute the steps
      if @left?
        @_stepLeft = (@left-parseInt @rendering.css 'left')/@_sprite.number
        @_stepBottom = (@bottom-parseInt @rendering.css 'bottom')/@_sprite.number

      # console.log "#{@item.id} animated, start"
      # Starts the animation, with an event and the first frame.
      @trigger 'start', @
      if document.hidden
        # document not visible: drop directly to last frame.
        @_onFrame @_start+@_sprite.duration+1000
      else 
        # add it to animations
        _anims.push @

    # **private**
    # Animation loop: request another animation frame, and if it's time to switch sprites,
    # alter the rendering.
    # At the end of the animation, triggers the 'end' event.
    #
    # @param current [Number] the current timestamp. Null to stop current animation.
    #
    _onFrame: (current) ->
      # loop until the end of the animation
      if current? and current-@_start < @_sprite.duration
        # only animate at needed frames
        if current-@_start >= (@_step+1)*@_sprite.duration/@_sprite.number
          # console.log "#{@item.id} animated, sprite #{@_step}"
          
          # changes frame 
          if @item.shiftLeft <= -(@_sprite.number*@_sprite.width) 
            @item.shiftLeft = 0 
          else 
            @item.shiftLeft -= @_sprite.width

          @rendering.css 'backgroundPosition', "#{@item.shiftLeft}px #{@item.shiftTop}px"

          # moves the rendering
          @_step++
          if @left?
            @rendering.css 
              left: @left-@_stepLeft*(@_sprite.number-@_step)
              bottom: @bottom-@_stepBottom*(@_sprite.number-@_step)

      else 
        # removes from executing animations first.
        _anims.splice _anims.indexOf(@), 1
        # console.log "#{@item.id} animated, end"
        # end of the animation: displays first sprite
        @item.shiftLeft = 0
        @rendering.css 'backgroundPosition', "#{@item.shiftLeft}px #{@item.shiftTop}px"

        # and goes to last position if needed
        if @left?
          correction = -(0.8*@item.get('x')-4)
          # Last position of the animation
          @rendering.css 
            left: @left
            bottom: @bottom
            '-moz-transform': "skewX(#{correction}deg)"
            '-webkit-transform': "skewX(#{correction}deg)"
            'z-index': @item.get('y')*2+@item.get('x')

        # indicates end
        @trigger 'end', @

  # do not use `class Animation extens Backbone.Events`
  _.extend(Animation::, Backbone.Events)

  return Animation
