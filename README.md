UP7Connect
==========

On [Paris Diderot](http://www.univ-paris-diderot.fr/english/) campus, there’s a
a private WiFi hotspot. To get connected to the Internet, you must connect
your computer to the WiFi hotspot, then open a random page in a browser, get
redirected, accept the https warning, then enter your login & pass, submit a
form, and you’re connected. *That’s pretty annoying*.

So, 9 months ago (March, 2012), I wrote a Ruby script which connects me
automatically to the WiFi when I call it. Since it could be useful to other
students, the goal is to rewrite the script to make it more readable, working
with all major OSes, and publish it as a gem.


Usage
-----

```
ruby src/up7connect.rb
```

The first time, it will ask you for your login/pass. It works on Ubuntu, but I
don’t know for Mac & Windows.
