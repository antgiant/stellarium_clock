# stellarium_clock
A simple script that places a full screen clock on the Stellarium display. Designed to allow Stellarium to be used as a wall clock background.

Requires that you create a `location.js` file containing
```
var lat = [clock_latitude];
var lon = [clock_longitude];
var alt = [clock_altitude_in_meters];
var place = "[clock_place_name]";

//Optionally
var night_look_direction = [Compass direction to look at night];
bounce_time = [true/false]; //Bounce the time around on screen to avoid burn-in

//Setting this overrides the time and instead shows a countdown
//  to this date and time. If date is in the past it will revert
//  to showing time. (This example is set to the announcement of the
//  first US COVID lockdown March 16, 2019 at 1 pm.)
countdown = new Date();
countdown.setFullYear(2019,3 - 1,16);
countdown.setHours(13, 00, 00);
 ```