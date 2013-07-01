quicklook-lightroom
===================

Mac OS X QuickLook plugin for Lightroom .lrcat catalogs

<info@capturemonkey.com>

Copyright (c) 2013 Jarno Heikkinen. All rights reserved.

Installation
============
Copy quicklook-lightroom.qlgenerator package to /Library/QuickLook

Features
========
 * Reads .lrcat catalog and displays QuickLook preview using previews from .lrdata package
 * Creates previews for .lrprev files (which are actual thumbnails inside .lrdata)
 * To use, just open a Finder window, navigate to .lrcat catalog file and press space.

TODO
====
 * grid listing has 950ms timeout, which does not produce all the photos
 * no color management for thumbnails
 * thumbnail cropping could be improved
