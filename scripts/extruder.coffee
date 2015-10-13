
# Syncronize extrusion to on-off signal sent by robot
# Feeds forward (near infinite) when going off->on,
# and does a small retract when going on->off

# npm install firmata serialport coffee-script
# ./node_modules/.bin/coffee extruder.coffee

SerialPort = require("serialport").SerialPort
firmata = require 'firmata'

listenPinChange = (devicePath, readPin, onChange, callback) ->
  board = new firmata.Board devicePath, (err) ->
    return callback err if err

    board.pinMode readPin, board.MODES.INPUT
    board.digitalRead readPin, (value) ->
      console.log 'val', value
      onChange value

    return callback null

class GcodeSender
  constructor: (@port) ->
    options =
      baudrate: 115200
    @serial = new SerialPort @port, options, false

  open: (callback) ->
    checkStarted = (buffer) =>
      data = buffer.toString()
      if data == 'start\nok\n'
        @serial.removeListener 'data', checkStarted
        @serial.on 'data', (data) => @._recv data
        return callback null

    @serial.open (err) =>
      return callback err if err
      @serial.on 'data', checkStarted

  write: (gcode) ->
    @serial.write gcode, (err, res) ->
      console.log 'wrote', err, res

  _recv: (buffer) ->
    console.log 'recv', buffer.toString()


main = () ->

  settings =
    printerPort: '/dev/ttyACM0'
    ioPort: '/dev/ttyACM1'
    ioPin: 2
    retractDistance: -1
    forwardDistance: 1000
    feedRate: 10

  printer = new GcodeSender settings.printerPort

  lastState = false
  onPinChange = (value) ->
    state = value == 1
    if state != lastState
      extrusion = if state then settings.forwardDistance else settings.retractDistance
      fmt = (number) ->
        number.toFixed(2)
      command = "G1 E#{fmd(extrusion)} F#{fmt(settings.feedRate)}\n"
      console.log 'update', state, command
      printer.write command  

    lastState = state

  printer.open (err) ->
    throw err if err
    console.log 'printer setup done'
    listenPinChange settings.ioPort, settings.ioPin, onPinChange, (err) ->
      throw err if err
      console.log 'setup done'

main() if not module.parent
