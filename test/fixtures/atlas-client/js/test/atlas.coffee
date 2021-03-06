'use strict'

define ['underscore', 'atlas', 'chai', 'async'], (_, AtlasFactory, chai, async) ->

  expect = chai.expect
  player = null
  adminNS = null
  types = {}
  models = {}
  rules = {}
  
  # for debugging purposes
  window.models = models
  window.types = types
  window.rules = rules

  makeRid = -> 
    "req#{Math.random()*10000}"

  create = (spec, end) ->
    rid = makeRid()
    adminNS.emit 'save', rid, spec.className, spec.obj
    adminNS.on 'save-resp', callback = (reqId, err, className, model) ->
      return unless reqId is rid
      adminNS.removeListener 'save-resp', callback
      return end JSON.stringify err if err?
      # do not store fields
      spec.container[model.id] = model unless className is 'Field'
      end()

  emitter = new (class EventEmitter

    events: {}

    emitted: []

    on: (type, listener) =>
      @events[type] = [] unless type of @events
      @events[type].push listener

    off: (type, listener) =>
      unless type?
        @events = {}
      else unless listener?
        delete @events[type]
      else
        idx = @events[type].indexOf listener
        @events[type].splice idx, 1 if idx isnt -1

    emit: (type, args...) =>
      @emitted.push type:type, args:args
      return unless type of @events
      listener.apply @, args for listener in @events[type]
  )()

  window.Atlas = AtlasFactory emitter, debug:false
  
  describe 'Atlas tests', ->

    beforeEach ->
      emitter.emitted = []

    it 'should existing player be connected', (done) ->
      # given a token
      $.ajax 
        url: "#{conf.apiBaseUrl}/auth/login"
        type: 'POST'
        crossDomain: true
        data: 
          username: 'admin'
          password: 'admin'
        dataType: 'json'
        error: (xhr, status, err) -> done err
        success: (data, status, xkr) ->
          return done data.error if data.error?

          # when connecting with this token
          Atlas.connect data.token, (err, result) ->
            player = result
            # then player is returned
            expect(err).not.to.exist
            expect(player).to.exist
            expect(player).to.be.an.instanceOf Atlas.Player
            expect(player.email).to.be.equal 'admin'
            # then a connected event was issued
            expect(emitter.emitted.length).to.be.least 2
            msg = emitter.emitted.pop()
            expect(msg.type).to.be.equal 'connected'
            expect(msg.args[0]).to.be.deep.equal player
            msg = emitter.emitted.pop()
            expect(msg.type).to.be.equal 'modelChanged'
            expect(msg.args[0]).to.be.equal 'creation'
            expect(msg.args[1]).to.be.deep.equal player
            adminNS = Atlas.socket.io.socket "/admin"
            adminNS.on 'connect', done

    describe 'given some types, models and rules', ->

      before (done) ->
        # create types
        async.each [
          {className: 'Executable', container: rules, obj: id: 'testRule1', content: """Rule = require 'hyperion/model/Rule'
              module.exports = new (class CustomRule extends Rule
                canExecute: (actor, target, context, callback) =>
                  callback null, if target.strength? then [] else null
                execute: (actor, target, params, context, callback) =>
                  target.strength++
                  callback null, 'target strengthened'
              )()"""}
          {className: 'Executable', container: rules, obj: id: 'testRule2', content: """Rule = require 'hyperion/model/Rule'
              module.exports = new (class CustomRule extends Rule
                canExecute: (actor, target, context, callback) =>
                  callback null, if target?.typeId? and target?.mapId? then [] else null
                execute: (actor, target, params, context, callback) =>
                  actor.x = target.x
                  actor.y = target.y
                  callback null, 'actor moved'
              )()"""}
          {className: 'Executable', container: rules, obj: id: 'testRule3', content: """Rule = require 'hyperion/model/Rule'
              module.exports = new (class CustomRule extends Rule
                canExecute: (actor, target, context, callback) =>
                  callback null, if target?._className is 'Player' then [] else null
                execute: (actor, target, params, context, callback) =>
                  for character in actor.characters
                    character.strength = 10
                  callback null, 'player characters strength reseted'
              )()"""}
          {className: 'Executable', container: rules, obj: id: 'testRule4', content: """Rule = require 'hyperion/model/Rule'
              module.exports = new (class CustomRule extends Rule
                canExecute: (actor, target, context, callback) =>
                  callback null, if target?._className is 'Player' then [] else null
                execute: (actor, target, params, context, callback) =>
                  callback null
              )()"""}
          {className: 'ItemType', container: types, obj: id: 'testCharacter', quantifiable: false, properties: strength:{type: 'integer', def:10}, linked:{type: 'array', def:'any'}}
          {className: 'EventType', container: types, obj: id: 'testTalk', properties: content:{type: 'text', def:'s.o.s.'}, to:{type: 'object', def: 'item'}}
          {className: 'FieldType', container: types, obj: id: 'testPlain'}
          {className: 'Map', container: models, obj: id: 'testMap1', kind: 'square'}
        ], create, (err) ->
          return done err if err?
          # then create instances
          async.each [
            {className: 'Item', container: models, obj: id: 'john', strength: 20, linked: [], type: id: 'testCharacter'}
            {className: 'Item', container: models, obj: id: 'bob', linked: [], type: id: 'testCharacter'}
            {className: 'Field', container: models, obj: [
              {mapId: 'testMap1', x:0, y:0, typeId: 'testPlain'}
              {mapId: 'testMap1', x:-5, y:0, typeId: 'testPlain'}
              {mapId: 'testMap1', x:5, y:2, typeId: 'testPlain'}
              {mapId: 'testMap1', x:2, y:-5, typeId: 'testPlain'}
            ]}
          ], create, (err) ->
            return done err if err?
            async.each [
              {className: 'Event', container: models, obj: id: 'evt1', from: 'john', type: id: 'testTalk'}
              {className: 'Event', container: models, obj: id: 'evt2', from: 'bob', content: 'yeah !', type: id: 'testTalk'}
            ], create, done

      after (done) ->
        # remove elements
        async.eachSeries _.values(rules).concat(_.values(models), _.values types), (obj, next) ->
          rid = makeRid()
          adminNS.emit 'remove', rid, obj._className or 'Executable', obj
          adminNS.on 'remove-resp', callback = (reqId, err) ->
            return unless reqId is rid
            adminNS.removeListener 'remove-resp', callback
            # silent errors
            console.error err if err?
            next()
        , done

      it 'should this character added to player', (done) ->
        # when saving the player with this character
        adminNS.emit 'save', makeRid(), 'Player', 
          id: player.id
          email: 'admin'
          password: player.password
          provider: player.provider
          characters: [models.john]
        adminNS.once 'save-resp', (reqId, err) ->
            return done "Failed to save player: #{err}" if err?
        
        # then a modelChanged event is triggered about player
        emitter.on 'modelChanged', listener = (kind, model, changes) -> 
          return unless model.id is player.id
          emitter.off 'modelChanged', listener
        
          # then player model is automatically updated
          expect(player.characters).to.have.lengthOf 1
          expect(player.characters[0]).to.be.an.instanceOf Atlas.Item
          expect(player.characters[0]).to.have.property('id').that.equal 'john'
          expect(player.characters[0]).to.have.property('strength').that.equal 20
          # then a modelChanged event was issued
          expect(kind).to.equal 'update'
          expect(model).to.deep.equal player
          expect(changes).to.deep.equal ['characters']
          done()

      it 'should character be added to a map', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          expect(character.map).not.to.exist
          # when adding the character to the map
          models.john.map = models.testMap1
          models.john.x = 5
          models.john.y = 2
          adminNS.emit 'save', makeRid(), 'Item', models.john
          adminNS.once 'save-resp', (reqId, err) ->
              return done "Failed to save character: #{err}" if err?
          
          # then a modelChanged event is triggered about character
          emitter.on 'modelChanged', listener = (kind, model, changes) -> 
            return unless model.id is character.id
            emitter.off 'modelChanged', listener
            
            # then character model is automatically updated
            expect(character.map).to.be.an.instanceOf Atlas.Map
            expect(character.map).to.have.property('id').that.equal 'testMap1'
            expect(character.map).to.be.deep.equal player.characters[0].map
            expect(character.x).to.be.equal 5
            expect(character.y).to.be.equal 2
            # then a modelChanged event was issued
            expect(kind).to.equal 'update'
            expect(model).to.deep.equal character
            expect(changes).to.deep.equal ['imageNum', 'y', 'x', 'map']
            done()

      it 'should event have populated from cache and server', (done) -> 
        # when fetching events by ids
        Atlas.Event.fetch ['evt1', 'evt2'], (err, events) ->
          return done "Failed to select events: #{err}" if err?
          expect(events).to.have.length 2
          # then default properties have been applied
          expect(events[0]).to.have.property('id').that.equal 'evt1'
          expect(events[0]).to.have.property('content').that.equal 's.o.s.'
          # then from have been populated from cache
          expect(events[0].from).to.be.an.instanceOf Atlas.Item
          expect(events[0].from).to.have.property('id').that.equal 'john'
          expect(events[1]).to.have.property('id').that.equal 'evt2'
          expect(events[1]).to.have.property('content').that.equal 'yeah !'
          # then from have been populated from server
          expect(events[1].from).to.be.an.instanceOf Atlas.Item
          expect(events[1].from).to.have.property('id').that.equal 'bob'
          Atlas.Item.findCached ['john', 'bob'], (err, items) ->
            return done "Failed to select items: #{err}" if err?
            expect(events[0].from).to.be.deep.equal items[0]
            expect(events[1].from).to.be.deep.equal items[1]
            done()

      it 'should character have linked object', (done) ->
        # given a brand new event with linked object
        create {className: 'Event', container: models, obj: id: 'evt3', to: 'bob', type: id: 'testTalk'}, (err) ->
          return done "Failed to create new event #{err}" if err?
          # given a brand new item with linked array
          create {className: 'Item', container: models, obj: id: 'tim', linked: ['bob', 'evt3'], type: id: 'testCharacter'}, (err) ->
            return done "Failed to create new item #{err}" if err?
            # when fetching the item
            Atlas.Item.fetch ['tim'], (err, items) ->
              return done "Failed to select item #{err}" if err?
              expect(items).to.have.length 1
              # then item is retrieved
              expect(items[0]).to.be.an.instanceOf Atlas.Item
              expect(items[0]).to.have.property('id').that.equal 'tim'
              expect(items[0], "tim has wrong strength").to.have.property('strength').that.equal 10
              expect(items[0].type).to.be.an.instanceOf Atlas.ItemType
              expect(items[0].type).to.have.property('id').that.equal 'testCharacter'
              expect(items[0]).to.have.property 'linked'
              # then item as linked array resolved
              expect(items[0].linked).to.have.length 2
              expect(items[0].linked[0]).to.be.an.instanceOf Atlas.Item
              expect(items[0].linked[0]).to.have.property('id').that.equal 'bob'
              expect(items[0].linked[0].type).to.be.an.instanceOf Atlas.ItemType
              expect(items[0].linked[0].type).to.have.property('id').that.equal 'testCharacter'
              expect(items[0].linked[0], "bob has wrong strength").to.have.property('strength').that.equal 10
              expect(items[0].linked[1]).to.be.an.instanceOf Atlas.Event
              expect(items[0].linked[1]).to.have.property('id').that.equal 'evt3'
              expect(items[0].linked[1].type).to.be.an.instanceOf Atlas.EventType
              expect(items[0].linked[1].type).to.have.property('id').that.equal 'testTalk'
              expect(items[0].linked[1]).to.have.property('content').that.equal 's.o.s.'
              # then linked object has their own linked object resolved
              expect(items[0].linked[1]).to.have.property 'to'
              expect(items[0].linked[1].to).to.be.an.instanceOf Atlas.Item
              expect(items[0].linked[1].to).to.have.property('id').that.equal 'bob'
              done()

      it 'should character linked object be changed', (done) ->
        # when modifiing an item
        models.bob.strength = 20
        models.bob.linked = ['evt1']
        create {className: 'Item', container: models, obj: models.bob}, (err) ->
          return done "Failed to select item #{err}" if err?
          
        # then a modelChanged event was issued
        emitter.on 'modelChanged', listener = (kind, model, changes) ->
          return unless model.id is 'bob'
          emitter.off 'modelChanged', listener
          
          expect(kind).to.equal 'update'
          expect(changes).to.deep.equal ['strength', 'linked']
          # when getting locally cached related object
          Atlas.Item.findById 'tim', (err, item) ->
            return done "Failed to select item #{err}" if err?
            expect(item).to.exist
            # then item is retrieved
            expect(item).to.be.an.instanceOf Atlas.Item
            expect(item).to.have.property('id').that.equal 'tim'
            expect(item.type).to.be.an.instanceOf Atlas.ItemType
            expect(item.type).to.have.property('id').that.equal 'testCharacter'
            expect(item).to.have.property 'linked'
            # then item as linked array resolved
            expect(item.linked).to.have.length 2
            expect(item.linked[0]).to.be.an.instanceOf Atlas.Item
            expect(item.linked[0]).to.have.property('id').that.equal 'bob'
            expect(item.linked[0].type).to.be.an.instanceOf Atlas.ItemType
            expect(item.linked[0].type).to.have.property('id').that.equal 'testCharacter'
            expect(item.linked[0]).to.have.property('strength').that.equal 20
            expect(item.linked[1]).to.be.an.instanceOf Atlas.Event
            expect(item.linked[1]).to.have.property('id').that.equal 'evt3'
            expect(item.linked[1].type).to.be.an.instanceOf Atlas.EventType
            expect(item.linked[1].type).to.have.property('id').that.equal 'testTalk'
            expect(item.linked[1]).to.have.property('content').that.equal 's.o.s.'
            # then linked object has their own linked object resolved
            expect(item.linked[0]).to.have.property 'linked'
            expect(item.linked[0].linked).to.have.length 1
            expect(item.linked[0].linked[0]).to.be.an.instanceOf Atlas.Event
            expect(item.linked[0].linked[0]).to.have.property('id').that.equal 'evt1'
            expect(item.linked[1]).to.have.property 'to'
            expect(item.linked[1].to).to.be.an.instanceOf Atlas.Item
            expect(item.linked[1].to).to.have.property('id').that.equal 'bob'
            done()

      it 'should map fields and items be consulted', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # given an enriched map
          Atlas.Map.findById 'testMap1', (err, map) ->
            return done "Failed to select map: #{err}" if err?
            # when consulting the map content
            map.consult {x:0, y:0}, {x:5, y:5}, (err, fields, items) ->
              return done "Failed to consult map: #{err}" if err?
              expect(emitter.emitted).to.have.length 0
              # then contained fields are returned
              expect(fields.length).to.be.least 2
              fields.sort (f1, f2) -> (f1.x or 0) - (f2.x or 0)
              expect(fields[0]).to.be.an.instanceOf Atlas.Field
              expect(fields[0]).to.have.property('x').that.equal 0
              expect(fields[0]).to.have.property('y').that.equal 0
              expect(fields[0]).to.have.property('typeId').that.equal 'testPlain'
              expect(fields[1]).to.be.an.instanceOf Atlas.Field
              expect(fields[1]).to.have.property('x').that.equal 5
              expect(fields[1]).to.have.property('y').that.equal 2
              expect(fields[1]).to.have.property('typeId').that.equal 'testPlain'
              # then contained items are returned
              expect(items).to.have.length 1
              expect(items[0]).to.be.an.instanceOf Atlas.Item
              expect(items[0]).to.deep.equal character
              done()

      it 'should field creation and removal triggers updates', (done) ->
        # when adding a field
        create {className: 'Field', container: models, obj: [mapId: 'testMap1', x:2, y:3, typeId: 'testPlain']}, (err) ->
          return done "Failed to create field: #{err}" if err?
          # then a creation event was emitted for this field
          _.defer ->
            expect(emitter.emitted).to.have.length 1
            expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
            expect(emitter.emitted[0].args[0]).to.equal 'creation'
            expect(emitter.emitted[0].args[1]).to.be.an.instanceOf Atlas.Field
            expect(emitter.emitted[0].args[1]).to.be.have.property('x').that.equal 2
            expect(emitter.emitted[0].args[1]).to.be.have.property('y').that.equal 3
            expect(emitter.emitted[0].args[1]).to.be.have.property('typeId').that.equal 'testPlain'
            expect(emitter.emitted[0].args[1]).to.be.have.property('mapId').that.equal 'testMap1'
            fieldId = emitter.emitted[0].args[1].id
            emitter.emitted = []
            # when removing this field
            rid = makeRid()
            adminNS.emit 'remove', rid, 'Field', [id: fieldId]
            adminNS.on 'remove-resp', callback = (reqId, err) ->
              return unless reqId is rid
              adminNS.removeListener 'remove-resp', callback
              return done "Failed to remove field: #{err}" if err?
              _.defer ->
                # then a creation event was emitted for this field
                expect(emitter.emitted).to.have.length 1
                expect(emitter.emitted[0].type).to.be.equal 'modelChanged'
                expect(emitter.emitted[0].args[0]).to.equal 'deletion'
                expect(emitter.emitted[0].args[1]).to.be.an.instanceOf Atlas.Field
                expect(emitter.emitted[0].args[1]).to.be.have.property('id').that.equal fieldId
                expect(emitter.emitted[0].args[1]).to.be.have.property('x').that.equal 2
                expect(emitter.emitted[0].args[1]).to.be.have.property('y').that.equal 3
                expect(emitter.emitted[0].args[1]).to.be.have.property('typeId').that.equal 'testPlain'
                expect(emitter.emitted[0].args[1]).to.be.have.property('mapId').that.equal 'testMap1'
                done()

      it 'should rules be resolved for a target', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when resolving rules for this model
          Atlas.ruleService.resolve character, character, null, (err, results) ->
            return done "Failed to resolve rules over target: #{err}" if err?
            expect(results).not.to.have.property 'testRule2'
            expect(results).not.to.have.property 'testRule3'
            expect(results).not.to.have.property 'testRule4'
            # then the first rule is appliable
            expect(results).to.have.property 'testRule1'
            expect(results.testRule1).to.have.length 1
            expect(results.testRule1[0].target).to.be.an.instanceOf Atlas.Item
            expect(results.testRule1[0].target).to.deep.equal character
            done()

      it 'should rules be resolved for a tile', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when resolving rules for a tile
          Atlas.ruleService.resolve character, 5, 2, null, (err, results) ->
            return done "Failed to resolve rules over tile: #{err}" if err?
            expect(results).not.to.have.property 'testRule3'
            expect(results).not.to.have.property 'testRule4'
            # then the item rule is appliable
            expect(results).to.have.property 'testRule1'
            expect(results.testRule1).to.have.length 1
            expect(results.testRule1[0].target).to.be.an.instanceOf Atlas.Item
            expect(results.testRule1[0].target).to.deep.equal character
            # then the field rule is appliable
            expect(results).to.have.property 'testRule2'
            expect(results.testRule2).to.have.length 1
            expect(results.testRule2[0].target).to.be.an.instanceOf Atlas.Field
            expect(results.testRule2[0].target).to.have.property('x').that.equal 5
            expect(results.testRule2[0].target).to.have.property('y').that.equal 2
            done()

      it 'should rules be resolved for a player', (done) ->
        # when resolving rules for current player
        Atlas.ruleService.resolve player, null, (err, results) ->
          return done "Failed to resolve rules over player: #{err}" if err?
          # then the player rule is appliable
          expect(results).not.to.have.property 'testRule1'
          expect(results).not.to.have.property 'testRule2'
          expect(results).to.have.property 'testRule3'
          expect(results.testRule3).to.have.length 1
          expect(results.testRule3[0].target).to.be.an.instanceOf Atlas.Player
          expect(results.testRule3[0].target).to.deep.equal player
          expect(results).to.have.property 'testRule4'
          expect(results.testRule4).to.have.length 1
          expect(results.testRule4[0].target).to.be.an.instanceOf Atlas.Player
          expect(results.testRule4[0].target).to.deep.equal player
          done()

      it 'should rules resolution error be handled', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when resolving rules for this item only
          Atlas.ruleService.resolve character, null, (err, results) ->
            expect(err).to.exist
            expect(err.message).to.include 'No player with id john'
            expect(results).not.to.exist
            done()

      it 'should rules resolution be ran in parallel and not collide', (done) ->
        ended = 0
        # given a rule resolution in progress
        Atlas.ruleService.resolve 'john', 'john', null, (err, results) ->
          expect(err).not.to.exist
          expect(results).to.have.property 'testRule1'
          expect(_.keys results).to.have.lengthOf 1
          ended++
          end()
        # when resolving rules in parrallel
        Atlas.ruleService.resolve 'john', 5, 2, null, (err, results) ->
          expect(err).not.to.exist
          expect(results).to.have.property 'testRule1'
          expect(results).to.have.property 'testRule2'
          expect(_.keys results).to.have.lengthOf 2
          ended++
          end()
        end = ->
          done() if ended is 2

      it 'should rules resolution return no results', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when resolving rules over an empty tile
          Atlas.ruleService.resolve character, -5, -5, null, (err, results) ->
            return done "Failed to resolve rules over tile: #{err}" if err?
            # then the player rule is appliable
            expect(_.keys results).to.have.length 0
            done()

      it 'should rule be executed for a target', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          # when executing a rule for this model
          Atlas.ruleService.execute 'testRule1', character, character, [], (err, result) ->
            return done "Failed to execute rule over target: #{err}" if err?
            # then rule results was returned
            expect(result).to.include 'strengthened'
            
          # then a modelChanged event was issued
          emitter.on 'modelChanged', listener = (kind, model, changes) ->
            return unless model.id is character.id
            emitter.off 'modelChanged', listener
            
            expect(kind).to.equal 'update'
            expect(model).to.deep.equal character
            expect(changes).to.deep.equal ['strength']
            # then the character strength has been modified
            expect(character).to.have.property('strength').that.equal 21
            # update raw model that have not been modified
            models.john.strength = character.strength
            done()

      it 'should rule be executed for a player', (done) ->
        # when executing a rule for player
        Atlas.ruleService.execute 'testRule3', player, [], (err, result) ->
          return done "Failed to execute rule over player: #{err}" if err?
          # then rule results was returned
          expect(result).to.include 'reseted'
          
        # then a modelChanged event was issued
        emitter.on 'modelChanged', listener = (kind, model, changes) ->
          return unless model.id is player.characters[0].id
          emitter.off 'modelChanged', listener
          
          expect(kind).to.equal 'update'
          expect(model).to.deep.equal player.characters[0]
          expect(changes).to.deep.equal ['strength']
          # then the character strength has been reseted
          expect(player.characters[0]).to.have.property('strength').that.equal 10
          # update raw model that have not been modified
          models.john.strength = player.characters[0].strength
          done()

      it 'should rule execution error be handled', (done) ->
        # when executing rule that does not apply to player
        Atlas.ruleService.execute 'testRule1', player, [], (err, result) ->
          expect(err).to.exist
          expect(err.message).to.include 'does not apply any more'
          expect(result).not.to.exist
          done()
          
      it 'should rules execution be ran in parallel and not collide', (done) ->
        ended = 0
        # given a rule resolution in progress
        Atlas.ruleService.execute 'testRule4', player, [], (err, results) ->
          expect(err).not.to.exist
          ended++
          end()
        # when resolving rules in parrallel
        Atlas.ruleService.execute 'testRule4', player, [], (err, results) ->
          expect(err).not.to.exist
          ended++
          end()
        end = ->
          done() if ended is 2

      it 'should rule execution return no result', (done) ->
        Atlas.ruleService.execute 'testRule4', player, [], (err, result) ->
          return done "Failed to execute rule over player: #{err}" if err?
          expect(result).not.to.exist
          done()

      it 'should character be removed from a map', (done) -> 
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          expect(character.map).to.exist
          # when removing characteritem from the map
          delete models.john.map
          adminNS.emit 'save', makeRid(), 'Item', models.john
          adminNS.once 'save-resp', (reqId, err) ->
            return done "Failed to save character: #{err}" if err?
            
          # then a modelChanged event was issued
          emitter.on 'modelChanged', listener = (kind, model, changes) ->
            return unless model.id is character.id
            emitter.off 'modelChanged', listener
            
            # then character model is automatically updated
            expect(character.map).not.to.exist
            expect(player.characters[0].map).not.to.exist
            # then a modelChanged event was issued
            expect(kind).to.equal 'update'
            expect(model).to.deep.equal character
            expect(changes).to.deep.equal ['map']
            done()

      it 'should character be removed', (done) ->
        # given the enriched character model
        Atlas.Item.findById 'john', (err, character) ->
          return done "Failed to select character: #{err}" if err?
          
          listener = (kind, model, changes) ->
            if model.id is player.id
              # then player is automatically updated
              expect(player.characters).to.have.length 0
              expect(kind).to.equal 'update'
              expect(model).to.deep.equal player
              expect(changes).to.deep.equal ['characters']
              next() if ++exec is 2
              
            else if model.id is character.id
              # then character was removed
              expect(kind).to.equal 'deletion'
              expect(model).to.deep.equal character
              next() if ++exec is 2
          
          next = ->
            emitter.off 'modelChanged', listener
            # then character is not in cache anymore
            Atlas.Item.findById 'john', (err, character) ->
              return done "Failed to remove character: #{err}" if err?
              expect(character).not.to.exist
              delete models.john
              done()
              
          # when removing character
          adminNS.emit 'remove', makeRid(), 'Item', models.john
          adminNS.once 'remove-resp', (reqId, err) ->
            return done "Failed to remove character: #{err}" if err?
              
          # then a modelChanged event was issued
          exec = 0
          emitter.on 'modelChanged', listener

    # Phantom is under test environment, where security is disabled
    if -1 is navigator.userAgent.indexOf 'PhantomJS'
      describe 'at the very end', ->
        
        it 'should unknown token not be connected', (done) ->
          Atlas.disconnect ->
            # given a token
            Atlas.connect 'unknown', (err, player) ->
              expect(err).to.be.an.instanceOf Error
              expect(err.message).to.equal 'handshake unauthorized'
              expect(player).not.to.exist
            done()