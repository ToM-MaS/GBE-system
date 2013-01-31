# Gemeinschaft System Environment

This repository hosts all system environment scripts for Gemeinschaft PBX.

### Installation / Prerequesites
More to come.

### Directory structure

#### /bin
Contains operational scripts, e.g. for self-update.


#### /dynamic
Contains dynamic system configuration files.
These files will be copied once during initial installation and will not be updated afterwards by the self-update function.
Users will be able to customize these files but might need to update them manually in case there are important changes.
However a factory reset will also re-write these files within the system directories and overwrite existing ones.


#### /lib
Contains operational library files, e.g. add-on database.


#### /static
Contains static system configuration files.
These files won't be copied to their destination system folders but symlinked instead and will always be reset during self-update to ensure core functionality.
Because of this users won't be able to do any permanent changes to these files (and should not need to do so).


### Mailing List
A mailing list about Gemeinschaft 5 is available here:
http://groups.google.com/group/gs5-users

It is mainly German but most of the participants should also be willing to answer in English.
