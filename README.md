PCKeyboard 1
============

Simple, superseded emulation of "PC-Style" Delete and End.


Introduction
------------

PCKeyboard 1 is a small module that I wrote one evening when the difference between Delete, Copy (End on a RiscPC), Home and Backspace on Acorns and PCs finally drove me mad. It simply alters the actions of these keys on the Acorn so that they behave more like those on a PC.

Haven't people already done this?  Yes -- but only partially. Acorn User carried a module which used filters and so only worked where applications handled their own input and not in writeable icons. PC Keyboard 1 uses the InsV vector to monitor all keyboard input and so works everywhere on the Desktop.

PCKeyboard 1 has been superseded by PCKeyboard 2, which works much better on modern systems. This repository is mainly provided for historical interest.


Building
--------

PCKeyboard 1 consists of a collection of ARM assembler and un-tokenised BASIC, which must be assembled using the [SFTools build environment](https://github.com/steve-fryatt). It will be necessary to have suitable Linux system with a working installation of the [GCCSDK](http://www.riscos.info/index.php/GCCSDK) to be able to make use of this.

With a suitable build environment set up, making PCKeyboard 1 is a matter of running

	make

from the root folder of the project. This will build everything from source, and assemble a working PCKeyboard 1 module and its associated files within the build folder. If you have access to this folder from RISC OS (either via HostFS, LanManFS, NFS, Sunfish or similar), it will be possible to run it directly once built.

To clean out all of the build files, use

	make clean

To make a release version and package it into Zip files for distribution, use

	make release

This will clean the project and re-build it all, then create a distribution archive (no source), source archive and RiscPkg package in the folder within which the project folder is located. By default the output of `git describe` is used to version the build, but a specific version can be applied by setting the `VERSION` variable -- for example

	make release VERSION=1.23


Licence
-------

PCKeyboard 1 is licensed under the EUPL, Version 1.2 only (the "Licence"); you may not use this work except in compliance with the Licence.

You may obtain a copy of the Licence at <http://joinup.ec.europa.eu/software/page/eupl>.

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "**as is**"; basis, **without warranties or conditions of any kind**, either express or implied.

See the Licence for the specific language governing permissions and limitations under the Licence.