# Chat
this.ChatRooms = new Meteor.Collection("chatrooms")
# These two would not need to be stuffed into TurkServer
this.ChatUsers = new Meteor.Collection("chatusers")
this.ChatMessages = new Meteor.Collection("chatmessages")

# Datastream
this.Datastream = new Meteor.Collection("datastream")

# Docs
this.Documents = new Meteor.Collection("docs")

# Events / Map
this.Events = new Meteor.Collection("events")

Meteor.methods
  ###
    Data Methods
  ###
  dataHide: (id) ->
    # Can't hide tagged events
    return if not @isSimulation and Datastream.findOne(id)?.events?.length > 0

    Datastream.update id,
      $set: { hidden: true }

  dataUnhide: (id) ->
    Datastream.update id,
      $set: { hidden: false }

  dataLink: (tweetId, eventId) ->
    return unless tweetId and eventId

    # Attach this tweet to the event
    Events.update eventId,
      $addToSet: { sources: tweetId }

    # Attach this event to the tweet, unhide if necessary
    Datastream.update tweetId,
      $addToSet: { events: eventId }
      $set: { hidden: false }

  dataUnlink: (tweetId, eventId) ->
    return unless tweetId and eventId

    Events.update eventId,
      $pull: { sources: tweetId }

    Datastream.update tweetId,
      $pull: { events: eventId }

  ###
    Event Methods
  ###
  createEvent: (eventId, fields) ->
    obj = {
      _id: eventId
      sources: []
      # location: undefined
    }

    _.extend(obj, fields)

    Events.insert(obj)

  editEvent: (id) ->
    userId = Meteor.userId()
    unless userId?
      bootbox.alert("Sorry, you must be logged in to make edits.") if @isSimulation
      return

    event = Events.findOne(id)

    unless event.editor
      Events.update id,
        $set: { editor: userId }
    else if @isSimulation and event.editor isnt userId
      bootbox.alert("Sorry, someone is already editing that event.")

  deleteEvent: (id) ->
    event = Events.findOne(id)

    # Pull all tweet links
    _.each event.sources, (tweetId) ->
      Datastream.update tweetId,
        $pull: { events: id }

    Events.remove(id)

  ###
    Chat Methods
  ###
  createChat: (roomName) ->
    ChatRooms.insert
      name: roomName
      users: 0

  sendChat: (roomId, message) ->
    # Do nothing on client side
    return if @isSimulation

    userId = Meteor.userId()
    return unless Meteor.userId()

    obj =
      room: roomId
      userId: userId
      text: message
      timestamp: +(new Date()) # Attach server-side timestamps to chat messages

    ChatMessages.insert(obj)

  deleteChat: (roomId) ->
    if @isSimulation
      # Client stub - do a quick check
      unless ChatRooms.findOne(roomId).users is 0
        bootbox.alert "You can only delete empty chat rooms."
      else
        ChatRooms.remove roomId
    else
      # Server method
      return unless ChatUsers.find(roomId: roomId).count() is 0
      ChatRooms.remove roomId
      # TODO should we delete messages? Or use them for logging...
