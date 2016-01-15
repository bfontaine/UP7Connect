# UP7Connect

On the [Paris Diderot](http://www.univ-paris-diderot.fr/english/) campus,
there’s a a private WiFi hotspot. To get connected to the Internet, you must
connect your computer to the WiFi hotspot, then open a random page in a
browser, get redirected, accept the https warning, then enter your login &
password, submit a form, and you’re connected. *That’s pretty annoying*.

So, 9 months ago (March, 2012), I wrote a Ruby script which automatically
connects me to the WiFi when I call it. I put it there because it could be
useful for other students.

Note: this is one of the very first Ruby scripts I’ve ever written, so expect
ugly code :)

## Usage

```sh
ruby src/up7connect.rb
```

The first time, it will ask you for your login/password. It works on Ubuntu and
should work on OS X and other UNIX-like OSes.
