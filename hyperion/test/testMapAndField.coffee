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

Map = require '../src/model/Map'
Field = require '../src/model/Field'
FieldType = require '../src/model/FieldType'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

awaited = false

fieldType = null
map = null

describe 'Map and Field tests', -> 

  beforeEach (done) ->
    Map.collection.drop -> Field.collection.drop -> FieldType.collection.drop -> 
      new FieldType({name: 'plain'}).save (err, saved) ->
        throw new Error err if err?
        fieldType = saved
        done()

  it 'should map be created', (done) -> 
    # given a new map
    map = new Map {name: 'map1'}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal 'Map', className
      assert.equal 'creation', operation
      assert.ok map.equals instance
      awaited = true

    # when saving it
    awaited = false
    map.save (err) ->
      throw new Error "Can't save map: #{err}" if err?

      # then it is in mongo
      Map.find {}, (err, docs) ->
        throw new Error "Can't find map: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].get('name'),  'map1'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  describe 'given a map', ->

    beforeEach (done) ->
      map = new Map {name: 'map2'}
      map.save -> done()

    it 'should map be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Map'
        assert.equal operation, 'deletion'
        assert.ok map.equals instance
        awaited = true

      # when removing a map
      awaited = false
      map.remove ->

        # then it's not in mongo anymore
        Map.find {}, (err, docs) ->
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should map be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Map'
        assert.equal operation, 'update'
        assert.ok map.equals instance
        assert.equal instance._name.default, 'map3'
        awaited = true

      # when modifying and saving an item
      map.set 'name', 'map3'
      awaited = false
      map.save ->

        Map.find {}, (err, docs) ->
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].get('name'), 'map3'
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should field be created', (done) ->
      # when creating a field on the map
      field = new Field {mapId:map._id, typeId:fieldType._id, x:0, y:0}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # then its retrievable by map
        Field.find {mapId: map._id}, (err, fields) ->
          throw new Error "Can't find field by map: #{err}" if err?
          assert.equal fields.length, 1
          assert.ok field.equals fields[0]
          assert.equal fields[0].get('mapId'), map._id
          assert.equal fields[0].get('x'), 0
          assert.equal fields[0].get('y'), 0
          done()

    it 'should field be removed', (done) ->
      # given an exiting a field on the map
      field = new Field {mapId:map._id, typeId:fieldType._id, x:10, y:10}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # when removing it
        field.remove (err) ->
          throw new Error "Can't remove field: #{err}" if err?
          # then it's not in the map anymore
          Field.findOne {_id: field._id}, (err, field) ->
            throw new Error "Can't find field by id: #{err}" if err?
            assert.ok field is null
            done()

    it 'should field cannot be updated', (done) ->
      # given an exiting a field on the map
      field = new Field {mapId:map._id, typeId:fieldType._id, x:10, y:10}
      field.save (err)->
        throw new Error "Can't save field: #{err}" if err?
        # when updating it
        field.set 'x', 20
        field.save (err) ->
          assert.ok err isnt null
          assert.equal err.message, 'only creations are allowed on fields', "Unexpected error: #{err}"
          done()