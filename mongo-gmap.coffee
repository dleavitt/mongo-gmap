@log = -> @console?.log?(arguments...)

@Pins = new Meteor.Collection "pins"

_.w = (str) -> str.split(" ")

if Meteor.isClient
  globals = {}

  Template.map.rendered = (template) ->
    globals.map = new google.maps.Map @find("#map"),
      mapTypeId: google.maps.MapTypeId.HYBRID
      mapTypeControlOptions:
        mapTypeIds: [google.maps.MapTypeId.TERRAIN, google.maps.MapTypeId.HYBRID]
      streetViewControl: false
      panControl: false
      zoomControl: true
      zoomControlOptions:
        position: google.maps.ControlPosition.LEFT_TOP
      zoom: 3
      center: new google.maps.LatLng(-34.397, 150.644)



  Template.controls.directions = ->
    coords = Session.get("coords") or {top: 60, left: -170, bottom: 40, right: -130}
    {dir: dir, coord: coords[dir]} for dir in _.w("top left bottom right")

  Template.controls.events
    "submit .js-map-form": (e, template) ->
      e.preventDefault()

      coordArray = for selector in _.w("top left bottom right")
        Number(template.find(".rect-#{selector}").value)

      c = {top: "", left: "", bottom: "", right: ""}
      [c.top, c.left, c.bottom, c.right] = coordArray

      Session.set "coords", c


      spansDateline = false
      if c.left > c.right
        c.left -= 360
        spansDateline = true

      polygon = [ [c.left, c.top],
                  [c.right, c.top],
                  [c.right, c.bottom],
                  [c.left, c.bottom],
                  [c.left, c.top] ]

      shape = template.find('.js-shape:checked').value
      log shape
      if shape is "high-res-polygon"
        interPoints = 2
        highResPolygon = []
        _.reduce polygon, (a, b) =>
          highResPolygon.push(a)
          
          [[x1, y1], [x2, y2]] = [a, b]

          for intervalFraction in _.range(1, interPoints)
            newPoint = for axis in [0,1]
              a[axis] + (b[axis] - a[axis]) * intervalFraction / interPoints + Math.random() * 1

            highResPolygon.push(newPoint)
          b
        highResPolygon.push _.last(polygon) 
        
        if spansDateline
          polygon = _.map polygon, (coords) ->
            if coords[0] < -180
              [coords[0] + 360, coords[1]]
            else
              [coords[0], coords[1]]

        polygon = highResPolygon

      gCoords = (new google.maps.LatLng(point[1], point[0]) for point in polygon)

      globals.gPolygon.setMap null if globals.gPolygon

      globals.gPolygon = new google.maps.Polygon
        paths: gCoords
        strokeColor:    "#FF0000"
        strokeOpacity:  1
        strokeWeight:   2
        fillColor:      "#FF0000"
        fillOpacity:    0.15

      globals.gPolygon.setMap(globals.map)


      useGeoJSON = shape isnt "box"
      Meteor.call "getPins", polygon, useGeoJSON, (error, pins) ->
        globals.markers or= []

        marker.setMap(null) while marker = globals.markers.pop()

        for pin in pins
          [lng, lat] = pin.loc.coordinates
          location = new google.maps.LatLng(lat, lng)

          title = "#{lat}, #{lng}"
          marker = new google.maps.Marker
            position: location
            map: globals.map
            title: title
          globals.markers.push marker


    "click .js-seed-map": ->
      Meteor.call 'seedMap', (error, result) ->
        log error, result

if Meteor.isServer
  Meteor.startup ->
    Pins._ensureIndex {loc : "2dsphere"}, {min: -200, max: 200}

  Meteor.methods
    seedMap: ->
      Pins.remove({})
      [0..90].forEach (lng) ->
        [0..45].forEach (lat) ->
          Pins.insert loc: 
            # {lng: (lng * 4) - 180, lat: (lat * 4) - 90}
            type: "Point"
            coordinates: [(lng * 4) - 180, (lat * 4) - 90]

    getPins: (polygon, useGeoJSON = true) ->
      if useGeoJSON
        selector = loc: "$geoWithin": "$geometry":
          "type": "Polygon"
          "coordinates": [ polygon ]
      else
        selector = loc: "$within": "$box": [ polygon[3], polygon[1] ]
        
      Pins.find(selector, limit: 2000).fetch()


# code to run on server at startup