# EDRDG Dictionary Archive

This repo contains archived versions of
[EDRDG](https://www.edrdg.org/) dictionary files starting from
September 2023. An automated process uploads the latest version of
each file daily.


File | Description
-- | --
JMdict | The full Japanese-Multilingual Dictionary XML file
JMdict_e | JMdict with only English-language glossaries
JMdict_e_examp | JMdict_e with Tatoeba example sentences included
JMnedict.xml | The Japanese Multilingual Named Entity Dictionary
examples.utf | Japanese-to-English example sentences from the Tatoeba project, indexed to JMdict entries
kanjidic2.xml | The Kanjidic2 kanji dictionary XML file


# Purpose

Why bother keeping an archive of old file versions? Aside from the
historical value of being able to track changes to the dictionary
data, this archive is also valuable for the purpose of reproducible
software packaging. If a version of a particular software package is
built using EDRDG data from a particular date, then the
reproducibility of that package relies upon the continued availability
of that version of the data.


# Format

Files are archived as sequences of patches which may be applied to a
base file.  For example, to get the JMdict file for 2024-01-01, you
would first need to decompress the base file (2023-08-20) at
`JMdict/JMdict.br`, apply the first decompressed patch file
(2023-09-25), apply the second decompressed patch file (2023-09-26),
etc., until finally applying the patch for 2024-01-01.

Some [fish shell](https://fishshell.com/) scripts are included in the
`scripts` directory to automate this process. Patching these large XML
files is computationally expensive, and it may take several minutes to
patch a base file from 2023 to the latest version.  If the latest
version of a file is all you need, you should get it from the
[EDRDG FTP server](http://ftp.edrdg.org/pub/Nihongo/00INDEX.html) instead.


### Why not use regular Git versioning instead of patch files?

Some of these decompressed XML files are very large (>100 MiB) and
over GitHub's size limit.


### Why use Brotli for compression instead of zstd / zlib / etc?

Brotli is free software that offers good lossless compression ratios
comparable to other modern algorithms like Zstandard. I chose it
because it was the best of the options available in the
[dotnet standard library](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression).


# Attribution

Shell scripts in the `scripts` directory are distributed under the
[Apache 2.0 license](https://www.gnu.org/licenses/license-recommendations.html#small).
See the LICENSE file in that directory for details.

EDRDG dictionary is distributed under a Creative Commons
Attribution-ShareAlike Licence (V4.0). See the
[EDRDG license page](https://www.edrdg.org/edrdg/licence.html)
for details.
