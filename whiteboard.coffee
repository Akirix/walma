fs = require "fs"
express = require "express"
_  = require 'underscore'
_.mixin require 'underscore.string'

{Db, Connection, Server} = require "mongodb"

app = express.createServer()
io = require('socket.io').listen app

{Drawing} = require "./lib/drawmodel"
{Client} = require "./lib/client"

db = new Db('whiteboard2', new Server("localhost", Connection.DEFAULT_PORT))
db.open (err) ->
  if err
    console.log "Could not open the database", err.trace
    process.exit(1)

  db.collection "drawings", (err, collection) ->
    Drawing.collection = collection
    Drawing.db = db
    console.log "got collection"



require("./configure") app, io


app.get "/", (req, res) ->

  # TODO:
  rooms = _.map db, (history, name) ->
    return {} unless history
    name: name
    historySize:  _.reduce(history, (memo, draw) ->
      return memo unless draw?.shape?.moves
      memo + draw.shape.moves.length
    , 0)

  res.render "index.jade",
    rooms: rooms


app.get "/:room", (req, res) ->
  res.render "paint.jade"

# app.get "/:room/bitmap/latest", (req, res) ->
#   res.header('Content-Type', 'image/png')
#   # res.header('Content-Type', 'text/plain')
# 
#   console.log "fetching room", req.params
# 
#   room = new Drawing req.params.room
#   room.getLatestCachePosition (err, position) ->
#     throw err if err
#     room.getCache position, (err, data) ->
#       throw err if err
#       [__, pngData] = data.split ","
#       res.send new Buffer(pngData, "base64")


app.get "/:room/bitmap/:pos", (req, res) ->
  res.header('Content-Type', 'image/png')
  # res.header('Content-Type', 'text/plain')

  console.log "fetching room", req.params

  room = new Drawing req.params.room
  room.getCache req.params.pos, (err, data) ->
    throw err if err
    [__, pngData] = data.split ","
    res.send new Buffer(pngData, "base64")




rooms = {}

sockets = io.of "/drawer"
sockets.on "connection", (socket) ->


  socket.on "join", (opts) ->
    roomName = opts.room

    # Send history to the new client
    if not room = rooms[roomName]
      console.log "Creating new room"
      rooms[roomName] = room = new Drawing roomName

    console.log "Adding client"
    room.addClient (client = new Client socket, opts), (err) ->
      console.log "failed to add client #{ opts.id } to room #{ roomName }"

    client.on "draw", (draw) ->
      # got new shape from some client

      # Send new shape to all clients in the room
      socket.broadcast.to(roomName).emit "draw", draw





