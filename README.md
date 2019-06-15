# DirecTV_SHEF
The `directv_http.pl` script is Copyright (c) 2011 Paul Sands. A link to the script and their documentation on it can be found [here](https://www.mythtv.org/wiki/Controlling_DirecTV_Set_Top_Box_(STB)_via_Network).

-

*If you do not already have docker, follow the installation instructions [here](https://docs.docker.com/v17.12/install/).*

To run this docker container, first clone this repository.

``` $ git clone https://github.com/fracturedface/DirecTV_SHEF.git ```



`cd` Into the downloaded directory and build the container with the following command:

``` $ docker build -t directv . ```

Run the container by typing:

``` $ docker run directv ```

The container opens by running the script with the `version` option. You can run other commands by adding options to the end of the docker run command like so:

``` $ docker run directv ip 192.168.1.77 on ``` - Powers on the STB at IP address `192.168.1.77`