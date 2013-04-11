It is for comparing MongoDB GeoJSON polygon queries to Google Maps polygons.

The marker grid represents the contents of polygon as returned by MongoDB. The rectangle is the polygon as represented in Google Maps.

It uses Meteor. It needs a newer version of MongoDB (2.4) than the one currently included in Meteor. So you have to specify your own when running it, like this: `MONGO_URL=mongodb://localhost:27017/mongo-gmap meteor`