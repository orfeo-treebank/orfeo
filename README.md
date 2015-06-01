# orfeo

The orfeo search portal is a set of related tools for importing,
converting and exploring annotated corpora. It was created within the
project [ANR ORFEO](http://www.projet-orfeo.fr/).

This repository contains an installer that automates, to the extent
possible, installation of the complete set of tools on a system.

# How to install

You probably need to be running a Unix system (e.g. Linux). You
definitely need to have Ruby installed.

Get the file [installer.rb](installer.rb) and execute it (as a normal
user, never with root privileges). Read the output carefully.

The installer is relatively safe in the sense that it will only modify
files under the directory it is executed in. (It may also install Ruby
gems.)
