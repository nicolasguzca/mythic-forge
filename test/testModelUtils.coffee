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

moment = require 'moment'
async = require 'async'
{expect} = require 'chai'
utils = require '../hyperion/src/util/common'
modelUtils = require '../hyperion/src/util/model'
typeFactory = require '../hyperion/src/model/typeFactory'
ItemType = require '../hyperion/src/model/ItemType'
Item = require '../hyperion/src/model/Item'
EventType = require '../hyperion/src/model/EventType'
Event = require '../hyperion/src/model/Event'

# integer value tests
describe 'Model utilities tests', ->

  circular = {one: 1, two:2}
  circular.three = circular

  describe 'checkParameters() tests', ->

    it 'should multiple parameters be checked', (done) ->
      # when checking multiple correct parameters
      modelUtils.checkParameters
        p1: true
        param2: 10
        param3: ['hey', 'you']
      , [
        name: 'p1'
        type: 'boolean'
      ,
        name: 'param2'
        type: 'integer'
        min: 5
      ,
        name: 'param3',
        type: 'string'
        within: ['hey', 'you', 'joe', 'exies']
        numMax: 3
      ], null, null, (err) ->
        # then no error is raised
        expect(err).not.to.exist
        done()

    it 'should not fail on null, undefined or empty expected parameters', (done) ->
      fixtures = [
        [null, null]
        [null, undefined]
        [null, []]
        [undefined, null]
        [undefined, undefined]
        [undefined, []]
        [{}, null]
        [{}, undefined]
        [{}, {}]
        [{p1:true}, null]
        [{p1:true}, undefined]
        [{p1:true}, []]
      ]
      async.forEach fixtures, (fixture, next) ->
        # when checking actual vs null expected
        modelUtils.checkParameters fixture[0], fixture[1], null, null, (err) ->
          # then no error is raised
          expect(err).not.to.exist
          next()
      , done

    it 'should fail on missing null or undefined actual when waiting for parameters', (done) ->
      # when checking null actual parameters
      modelUtils.checkParameters null, [name: 'p1', type: 'boolean'], null, null, (err) ->
        # then an error is raised
        expect(err).to.include 'p1Missing'

        # when checking undefined actual parameters
        modelUtils.checkParameters undefined, [name: 'p1', type: 'boolean'], null, null, (err) ->
          # then an error is raised
          expect(err).to.include 'p1Missing'
          done()

    it 'should fail on missing parameter', (done) ->
      # when checking null actual parameters
      modelUtils.checkParameters {}, [name: 'p1', type: 'boolean'], null, null, (err) ->
        # then an error is raised
        expect(err).to.include 'p1Missing'
        done()

    fixtures = [
      type: 'integer'
      values: ['1', 10.5, true, null, undefined, [[]], {}, new Date()]

      'should fail if value is lower than min': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'integer', min: 20], null, null, (err) ->
          expect(err).to.include 'p1UnderMin 20'
          done()

      'should fail if value is higher than max': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'integer', max: -5], null, null, (err) ->
          expect(err).to.include 'p1OverMax -5'
          done()

      'should fail if value is out of bounds': (done) ->
        expected = [name: 'p1', type: 'integer', min: 0, max: 5]
        modelUtils.checkParameters {p1: 10}, expected, null, null, (err) ->
          expect(err).to.include 'p1OverMax 5'
          modelUtils.checkParameters {p1: -5}, expected, null, null, (err) ->
            expect(err).to.include 'p1UnderMin 0'
            done()

      'should accept value within bounds': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'integer', min: 0], null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: 1}, [name: 'p1', type: 'integer', max: 10], null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: 5}, [name: 'p1', type: 'integer', min: 0, max: 10], null, null, (err) ->
              expect(err).not.to.exist
              done()

      'should fail on few occurences than expected': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'integer', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        modelUtils.checkParameters {p1: [10,11,12]}, [name: 'p1', type: 'integer', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept optionnal values': (done) ->
        expected = [name: 'p1', type: 'integer', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: 1}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        expected = [name: 'p1', type: 'integer', numMax: 2]
        modelUtils.checkParameters {p1: 1}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: [1]}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: [1, 2]}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'float'
      values: ['1', false, null, undefined, [[]], {}, new Date()]

      'should fail if value is lower than min': (done) ->
        modelUtils.checkParameters {p1: -10.5}, [name: 'p1', type: 'float', min: 1.5], null, null, (err) ->
          expect(err).to.include 'p1UnderMin 1.5'
          done()

      'should fail if value is higher than max': (done) ->
        modelUtils.checkParameters {p1: 10.1}, [name: 'p1', type: 'float', max: -0.1], null, null, (err) ->
          expect(err).to.include 'p1OverMax -0.1'
          done()

      'should fail if value is out of bounds': (done) ->
        expected = [name: 'p1', type: 'float', min: 0, max: 5]
        modelUtils.checkParameters {p1: 20.2}, expected, null, null, (err) ->
          expect(err).to.include 'p1OverMax 5'
          modelUtils.checkParameters {p1: -0.9}, expected, null, null, (err) ->
            expect(err).to.include 'p1UnderMin 0'
            done()

      'should accept value within bounds': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'float', min: 0.5], null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: 0.8}, [name: 'p1', type: 'float', max: 1.1], null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: 1.4}, [name: 'p1', type: 'float', min: 0, max: 10], null, null, (err) ->
              expect(err).not.to.exist
              done()

      'should fail on few occurences than expected': (done) ->
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'float', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        modelUtils.checkParameters {p1: [10,11,12]}, [name: 'p1', type: 'float', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept optionnal values': (done) ->
        expected = [name: 'p1', type: 'float', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: 1}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        expected = [name: 'p1', type: 'float', numMax: 2]
        modelUtils.checkParameters {p1: 1}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: [1]}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: [1, 2]}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'string'
      values: [0, 4.5, true, null, undefined, [['yes']], {}, new Date()]

      'should fail if value is not within possibilities': (done) ->
        modelUtils.checkParameters {param2: 'stuff'}, [name: 'param2', type: 'string', within: ['one', 'two']], null, null, (err) ->
          expect(err).to.include 'param2UnallowedValue'
          done()

      'should accept value within possibilities': (done) ->
        modelUtils.checkParameters {p1: 'two'}, [name: 'p1', type: 'string', within: ['one', 'two']], null, null, (err) ->
          expect(err).not.to.exist
          done()

      'should fail if value does not match regular expression': (done) ->
        modelUtils.checkParameters {param2: 'stuff'}, [name: 'param2', type: 'string', match: '^.{1,3}$'], null, null, (err) ->
          expect(err).to.include 'param2UnallowedValue'
          done()

      'should accept value that match regular expression': (done) ->
        modelUtils.checkParameters {p1: 'two'}, [name: 'p1', type: 'string', match: '^.{1,3}$'], null, null, (err) ->
          expect(err).not.to.exist
          done()

      'should fail on few occurences than expected': (done) ->
        modelUtils.checkParameters {p1: 'stuff'}, [name: 'p1', type: 'string', numMin: 3], null, null, (err) ->
          expect(err).to.include 'p1TooFew 3'
          done()

      'should fail on more occurences than expected': (done) ->
        modelUtils.checkParameters {p1: ['one', 'two', 'three', 'four']}, [name: 'p1', type: 'string', numMax: 3], null, null, (err) ->
          expect(err).to.include 'p1TooMany 3'
          done()

      'should accept optionnal values': (done) ->
        expected = [name: 'p1', type: 'string', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: ''}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        expected = [name: 'p1', type: 'string', numMax: 2]
        modelUtils.checkParameters {p1: ''}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: ['']}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: ['one', 'two']}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'text'
      values: [18, -1.2, true, null, undefined, [['toto']], {test:'toto'}, new Date()]

      'should fail on few occurences than expected': (done) ->
        modelUtils.checkParameters {p1: 'stuff'}, [name: 'p1', type: 'text', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        modelUtils.checkParameters {p1: ['one', 'two', 'three']}, [name: 'p1', type: 'text', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept optionnal values': (done) ->
        expected = [name: 'p1', type: 'text', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: ''}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        expected = [name: 'p1', type: 'text', numMax: 2]
        modelUtils.checkParameters {p1: ''}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: ['']}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: ['one', 'two']}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'boolean'
      values: [18, -1.2, '', null, undefined, [[true]], {test:true}, new Date()]

      'should fail on few occurences than expected': (done) ->
        modelUtils.checkParameters {p1: false}, [name: 'p1', type: 'boolean', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        modelUtils.checkParameters {p1: [false, true, true]}, [name: 'p1', type: 'boolean', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept optionnal values': (done) ->
        expected = [name: 'p1', type: 'boolean', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: true}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        expected = [name: 'p1', type: 'boolean', numMax: 2]
        modelUtils.checkParameters {p1: false}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: [true]}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: [true, false]}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'date'
      values: [18, -1.2, '', null, undefined, [[new Date()]], {test:new Date()}, true]

      'should fail if value is lower than min': (done) ->
        modelUtils.checkParameters {p1: new Date()}, [name: 'p1', type: 'date', min: moment().add(1, 'd').toDate()], null, null, (err) ->
          expect(err).to.include 'p1UnderMin'
          done()

      'should fail if value is higher than max': (done) ->
        modelUtils.checkParameters {p1: new Date()}, [name: 'p1', type: 'date', max: moment().subtract(1, 'd').toDate()], null, null, (err) ->
          expect(err).to.include 'p1OverMax'
          done()

      'should fail if value is out of bounds': (done) ->
        now = moment()
        expected = [name: 'p1', type: 'date', min: now.clone().subtract(1, 'h').toDate(), max: now.clone().add(1, 'h').toDate()]
        modelUtils.checkParameters {p1: now.clone().subtract(2, 'h').toDate()}, expected, null, null, (err) ->
          expect(err).to.include 'p1UnderMin'
          modelUtils.checkParameters {p1: now.clone().add(2, 'h').toDate()}, expected, null, null, (err) ->
            expect(err).to.include 'p1OverMax'
            done()

      'should accept value within bounds': (done) ->
        now = moment()
        modelUtils.checkParameters {p1: now.toDate()}, [name: 'p1', type: 'date', min: now.clone().subtract(1, 'h').toDate()], null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: now.toDate()}, [name: 'p1', type: 'date', max: now.clone().add(1, 'h').toDate()], null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: now.toDate()}, [name: 'p1', type: 'date', min: now.clone().subtract(1, 'h').toDate(), max: now.clone().add(1, 'h').toDate()], null, null, (err) ->
              expect(err).not.to.exist
              done()

      'should fail on few occurences than expected': (done) ->
        now = moment().toDate()
        modelUtils.checkParameters {p1: now}, [name: 'p1', type: 'date', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        now = moment().toDate()
        modelUtils.checkParameters {p1: [now, now, now]}, [name: 'p1', type: 'date', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept optionnal values': (done) ->
        now = moment().toDate()
        expected = [name: 'p1', type: 'date', numMin: 0]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: now}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      'should accept value while waiting for at most 2': (done) ->
        now = moment().toDate()
        expected = [name: 'p1', type: 'date', numMax: 2]
        modelUtils.checkParameters {p1: now}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: [now]}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: [now, now]}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()
    ,
      type: 'json'
      values: [18, -1.2, '', null, undefined, new Date(), {test:()->}, true, [1], [{test:()->}], circular]

      'should fail on few occurences than expected': (done) ->
        now = moment().toDate()
        modelUtils.checkParameters {p1: {one:1, two:2}}, [name: 'p1', type: 'json', numMin: 2], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      'should fail on more occurences than expected': (done) ->
        now = moment().toDate()
        modelUtils.checkParameters {p1: [{one:1}, {two:2}, {three:3}]}, [name: 'p1', type: 'json', numMax: 2], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      'should accept array values': (done) ->
        modelUtils.checkParameters {p1: [{one:1}]}, [name: 'p1', type: 'json'], null, null, (err) ->
          expect(err).not.to.exist
          done()

      'should accept object values': (done) ->
        modelUtils.checkParameters {p1: {one:1, two:2}}, [name: 'p1', type: 'json'], null, null, (err) ->
          expect(err).not.to.exist
          done()
    ]

    for fixture in fixtures
      describe "given an #{fixture.type} awaited parameter", ((fixture) ->
        return ->
          for value in fixture.values
            ((value) ->
              it "should fail when passing #{utils.type value}", (done) ->
                # when expecting a number parameter
                modelUtils.checkParameters {p1: value}, [name: 'p1', type: fixture.type], null, null, (err) ->
                  # then an error is raised
                  if value?
                    expect(err).to.match new RegExp "isn't a valid #{fixture.type}|doesn't hold a valid|only accepts"
                  else
                    expect(err).to.include 'p1Missing'
                  done()
            )(value)

          it name, test for name, test of fixture when name isnt 'type' and name isnt 'values'
        )(fixture)

    describe 'given an object awaited parameter', ->

      brick = null
      spare = null
      thunder = null
      b1 = null
      b2 = null
      b3 = null
      s1 = null
      e1 = null

      before (done) ->
        # Drops existing items and events, as well as their types
        Item.remove {}, -> Event.remove {}, -> ItemType.remove {}, -> EventType.remove {}, -> Item.loadIdCache ->
          # given a first unquantifiable type with properties
          new ItemType(
            id: 'brick'
            quantifiable: false
            properties:
              parts:
                type: 'array'
                def: 'Item'
              compose:
                type: 'object'
                def: 'Item'
          ).save (err, saved) ->
            return done err if err?
            brick = saved
            # Creates some bricks
            new Item(type: brick).save (err, saved) ->
              return done err if err?
              b1 = saved
              new Item(type: brick).save (err, saved) ->
                return done err if err?
                b2 = saved
                new Item(type: brick, parts:[b1, b2]).save (err, saved) ->
                  return done err if err?
                  b3 = saved
                  b1.compose = b3
                  b1.save (err, saved) ->
                    return done err if err?
                    b1 = saved
                    b2.compose = b3
                    b2.save (err, saved) ->
                      return done err if err?
                      b2 = saved
                      # given another quantifiable type
                      new ItemType(
                        id: 'spare'
                        quantifiable: true
                      ).save (err, saved) ->
                        return done err if err?
                        spare = saved
                        # Creates some spare
                        new Item(type: spare, quantity: 3).save (err, saved) ->
                          return done err if err?
                          s1 = saved
                          # given an event type
                          new EventType(
                            id: 'thunder'
                            properties:
                              linked:
                                type: 'array'
                                def: 'Any'
                          ).save (err, saved) ->
                            return done err if err?
                            thunder = saved
                            new Event(type: thunder, from: b1, linked: [b3, s1]).save (err, saved) ->
                              return done err if err?
                              e1 = saved
                              done()

      it 'should fail when passing number', (done) ->
        # when expecting a number parameter
        modelUtils.checkParameters {p1: 10}, [name: 'p1', type: 'object', within: [b1, b2]], null, null, (err) ->
          # then an error is raised
          expect(err).to.include "p1: 10 isn't a valid object id or id+qty"
          done()

      it 'should fail when passing boolean', (done) ->
        # when expecting a number parameter
        modelUtils.checkParameters {p1: true}, [name: 'p1', type: 'object', within: [b1, b2]], null, null, (err) ->
          # then an error is raised
          expect(err).to.include "p1: true isn't a valid object id or id+qty"
          done()

      it 'should fail when passing date', (done) ->
        # when expecting a number parameter
        modelUtils.checkParameters {p1: new Date()}, [name: 'p1', type: 'object', within: [b1, b2]], null, null, (err) ->
          # then an error is raised
          expect(err).to.include "isn't a valid object id or id+qty"
          done()

      it 'should fail on few occurences than expected', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', numMin: 2, within: [b1.id]], null, null, (err) ->
          expect(err).to.include 'p1TooFew 2'
          done()

      it 'should fail on more occurences than expected', (done) ->
        modelUtils.checkParameters {p1: [b1.id, b1.id, b1.id]}, [name: 'p1', type: 'object', numMax: 2, within: [b1.id]], null, null, (err) ->
          expect(err).to.include 'p1TooMany 2'
          done()

      it 'should accept optionnal values', (done) ->
        expected = [name: 'p1', type: 'object', numMin: 0, within: [b1.id]]
        modelUtils.checkParameters {p1: []}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: b1.id}, expected, null, null, (err) ->
            expect(err).not.to.exist
            done()

      it 'should accept value while waiting for at most 2', (done) ->
        expected = [name: 'p1', type: 'object', numMax: 2, within: [b1.id]]
        modelUtils.checkParameters {p1: b1.id}, expected, null, null, (err) ->
          expect(err).not.to.exist
          modelUtils.checkParameters {p1: [b1.id]}, expected, null, null, (err) ->
            expect(err).not.to.exist
            modelUtils.checkParameters {p1: [b1.id, b1.id]}, expected, null, null, (err) ->
              expect(err).not.to.exist
              done()

      it 'should fail on value not within awaited values', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', within: [b2.id, b3.id]], null, null, (err) ->
          expect(err).to.include "p1UnallowedValue #{b1.id}"
          done()

      it 'should fail on value not within dynamic actor property', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', property: {from: 'actor', path: 'compose'}], b2, null, (err) ->
          expect(err).to.include "p1UnallowedValue #{b1.id}"
          done()

      it 'should fail on value not within dynamic target property', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', property: {from: 'target', path: 'parts'}], null, b2, (err) ->
          expect(err).to.include "p1UnallowedValue #{b1.id}"
          done()

      it 'should fail on missing quantity for quantifiable value', (done) ->
        modelUtils.checkParameters {p1: s1.id}, [name: 'p1', type: 'object', property: {from: 'actor', path: 'linked'}], e1, null, (err) ->
          expect(err).to.include "p1MissingQuantity #{s1.id}"
          done()

      it 'should fail on negative quantity for quantifiable value', (done) ->
        modelUtils.checkParameters {p1: {id:s1.id, qty:0}}, [name: 'p1', type: 'object', within: [s1.id]], null, null, (err) ->
          expect(err).to.include "p1NegativeQuantity #{s1.id}"
          done()

      it 'should fail when requesting more than possible quantity for quantifiable value', (done) ->
        modelUtils.checkParameters {p1: {id:s1.id, qty:10}}, [name: 'p1', type: 'object', within: [s1.id]], null, null, (err) ->
          expect(err).to.include "p1NotEnoughtFor #{s1.id} 10"
          done()

      it 'should accept value within fixed possibilities', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', within: [b1.id]], null, null, (err) ->
          expect(err).not.to.exist
          done()

      it 'should accept value within dynamic actor property', (done) ->
        modelUtils.checkParameters {p1: b1.id}, [name: 'p1', type: 'object', property: {from: 'actor', path: 'compose.parts'}], b2, null, (err) ->
          expect(err).not.to.exist
          done()

      it 'should accept value within dynamic target property', (done) ->
        modelUtils.checkParameters {p1: {id:s1.id, qty:2}}, [name: 'p1', type: 'object', property: {from: 'target', path: 'linked'}], b2, e1, (err) ->
          expect(err).not.to.exist
          done()

  describe 'checkPropertyType() tests',  ->
    property = {}

    generateTest = (type, def, specs) ->
      return ->
        beforeEach (done) ->
          property.type = type
          property.def = def
          done()

        specs.forEach (spec) ->
          it "should #{spec.name} be #{spec.status}", ->
            err = modelUtils.checkPropertyType spec.value, property
            if 'accepted' is spec.status
              expect(err).not.to.exist
            else
              expect(err).to.match /isn't a valid|doesn't hold a valid|only accepts/

    describe 'given an integer definition', generateTest 'integer', 10, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'a positive integer', value: 4, status: 'accepted'}
      {name: 'a negative integer', value: -100, status: 'accepted'}
      {name: 'a constructed integer', value: new Number(100), status: 'accepted'}
      {name: 'zero', value: 0, status: 'accepted'}
      {name: 'a positive float', value: 10.56, status: 'rejected'}
      {name: 'a negative float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # float value tests
    describe 'given a float definition', generateTest 'float', 0.1, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'a positive integer', value: 4, status: 'accepted'}
      {name: 'a negative integer', value: -100, status: 'accepted'}
      {name: 'zero', value: 0, status: 'accepted'}
      {name: 'a positive float', value: 10.56, status: 'accepted'}
      {name: 'a negative float', value: -0.4, status: 'accepted'}
      {name: 'a constructed float', value: new Number(-1.2), status: 'accepted'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # boolean value tests
    describe 'given a boolean definition', generateTest 'boolean', true, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: -100, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: 10.56, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'accepted'}
      {name: 'false', value: false, status: 'accepted'}
      {name: 'off', value: off, status: 'accepted'}
      {name: 'fAlse', value: false, status: 'accepted'}
      {name: 'a constructed boolean', value: new Boolean(false), status: 'accepted'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # string value tests
    describe 'given a string definition', generateTest 'string', null, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: -100, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'accepted'}
      {name: 'an empty string', value: '', status: 'accepted'}
      {name: 'an constructed string', value: new String('Coucou !'), status: 'accepted'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # text value tests
    describe 'given a text definition', generateTest 'text', null, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: -100, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'accepted'}
      {name: 'an empty string', value: '', status: 'accepted'}
      {name: 'an constructed string', value: new String('Coucou !'), status: 'accepted'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # date value tests
    describe 'given a date definition', generateTest 'date', null, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: 4, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'accepted'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # object value tests
    describe 'given an object definition', generateTest 'object', 'Item', [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: 4, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'accepted'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'accepted'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'rejected'}
    ]

    # array value tests
    describe 'given an array definition', generateTest 'array', 'Item', [
      {name: 'null', value: null, status: 'rejected'}
      {name: 'an integer', value: 4, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'accepted'}
      {name: 'an bigger Item array', value: [new Item(), new Item(), new Item()], status: 'accepted'}
      {name: 'an object', value: {test:true}, status: 'rejected'}
      {name: 'an object array', value: [{test:true}], status: 'rejected'}
      {name: 'an empty array', value: [], status: 'accepted'}
    ]

    # json value tests
    describe 'given an json definition', generateTest 'json', {}, [
      {name: 'null', value: null, status: 'accepted'}
      {name: 'an integer', value: 4, status: 'rejected'}
      {name: 'zero', value: 0, status: 'rejected'}
      {name: 'a float', value: -0.4, status: 'rejected'}
      {name: 'a string', value: 'hi !', status: 'rejected'}
      {name: 'an empty string', value: '', status: 'rejected'}
      {name: 'true', value: true, status: 'rejected'}
      {name: 'false', value: false, status: 'rejected'}
      {name: 'a date', value: new Date(), status: 'rejected'}
      {name: 'an Item', value: new Item(), status: 'rejected'}
      {name: 'an Item array', value: [new Item()], status: 'rejected'}
      {name: 'an object', value: {test:true}, status: 'accepted'}
      {name: 'an object array', value: [{test:true}], status: 'accepted'}
      {name: 'an empty array', value: [], status: 'accepted'}
      {name: 'a recursive object', value: circular, status: 'rejected'}
    ]