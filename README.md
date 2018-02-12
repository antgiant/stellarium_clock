# stellarium_clock
A simple script that places a full screen clock on the Stellarium display. Designed to allow Stellarium to be used as a wall clock background.

Requires that you create a `location.js` file containing
```
var lat = [clock_latitude];
var lon = [clock_longitude];
var alt = [clock_altitude_in_meters];
var place = "[clock_place_name]";
 ```