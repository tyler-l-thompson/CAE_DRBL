# Description
A DRBL and Clonezilla wrapper program designed to simplify running the DRBL servre for the CAE Center

# Usage
    DRBL optimized for the CAE Center.
    This program is capable of imaging one or two labs at the same time.
    It is only capable of pushing an image to a lab, not pulling.

    drbl-cae.sh [-h|-l|-s|-v|-g|-w|-p] [-a LAB1] [-b LAB2] [-i IMAGE] [-t n] [-m n] [-d s] [-f s] [-o s]

    where:
        Non-Pushing Commands
            These commands will execute and then the program will exit without setting up DRBL or Clonezilla.

        -h          Show this help text.
        -l          List images available to push.
        -s          Stop Clonezilla and turn off imaging ports.
        -v          List the versions of DRBL, Clonezilla, and Partclone.
        -g          Tail the log files associated with DRBL and CLonezilla.
        -w   LAB    Wake computers in specified lab. Pass -a, -b, or -o for target MAC addresses.
        -p   int    Control imaging ports. 0 - Disable both ports. 1 - Enable one port. 2 - Enable two ports.

        Pushing Commands
            These commands will allow you to setup DRBL and Clonezilla on the server.

        -a   LAB1   The name of the first lab to image. e.g. C-224
        -b   LAB2   (CURRENTLY NOT WORKING) The name of the second lab to image. Omit if pushing to one lab.
        -i   IMAGE  The name of the image to push.

        Pushing Options
            These commands are optional and can only be used when pushing commands are present.

        -t   int    Time to wait until automatically starting the push in seconds. Default 1500 seconds.
        -m   int    Number of clients to wait to connect before starting Clonezilla. Default is all clients.
        -d   DIR    Set the image directory path. Default: /images
        -f   DIR    Set the mac address files directory path. Default: /alva/LabInfo/mac
        -o   FILE   Instead of pushing to lab, use a specified mac address file. -a and -b can be omitted. Use full path.

        Examples

            drbl-cae -a C-224 -i HPZ2-Fall2019-190801
                Image lab C-224 with image HPZ2-Fall2019-190801

            drbl-cae -s
                Shutdown DRBL and Clonezilla and turn off image ports. Should be run after an image has finished pushing.

            drbl-cae -o /opt/automatedImaging/macs/delltbs.txt -i VMImage-Fall2019-190704 -m 1
                Image the computers defined in /opt/automatedImaging/macs/delltbs.txt with image VMImage-Fall2019-190704
                and start the push after 1 client connects.
