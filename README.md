UP7Connect
==========

On [Paris Diderot](http://www.univ-paris-diderot.fr/english/) campus, there’s a
a private WiFi access. To get connected to the Internet, you need to connect
your computer to the WiFi access, then open a random page in a browser, get
redirected, accept the https warning, then enter your login & pass, submit a
form, and your connected. That’s pretty annoying.

So, 9 months ago (March, 2012), I wrote a Ruby script which connects me
automatically to the WiFi when I call it. Since it could be useful for other
students, the goal is to rewrite the script to make it more readable, working
with all major OSes, and publish it as a gem.
