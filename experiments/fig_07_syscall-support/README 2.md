# syscalls-supported-application

## Goal

This repository contains the experiment to generate a syscalls
supported per application graph for Unikraft. An excel file which
contains the current syscalls status is provided in this repository.

In order to gather syscalls we perform a syscalls analysis of 30
applications by running a dependency analyser tool that we have
implemented ourself.

To have the right environment for each application, we have created a
docker file per application. These ones are available in the 
`dockerfile` folder. Note that docker must be installed on your 
machine to perform this experiment.

**APPROXIMATIVE EXECUTION TIME=30/45minutes**

## How to Use (automatic test)

You can automatically run all the experiment by running the `make all`
command. This command will:

1. Prepare the environment by executing the `./setup.sh` script. Note
that this script takes a long time...
2. Run the syscalls experiment by running `./run_all.sh`. 
3. Generate the graph by running the `./plot.sh` script and then the
figure is saved into the current repository as `syscall-support.pdf`.

## How to Use (manual test)

You can also test manually by executing the following procedure.

In order to setup the environment for these experiments, please
execute first the `./setup.sh` script. This script will setup all the
environment to generate the graph. Once the setup is done, you can run
the dependency analyser by running the `./run_all.sh`. Note that the
setup takes time since each application must be built as a docker
container.

Once all the results are generated, run the `./plot.sh` script to
generate the graph. This one will be generated in the current folder
with the following name: `syscall-support.pdf`.

## Others

Additional information that may be interesting if you want to test
a new application.

### Gathering syscalls for a new application

If you want to gather yourself the syscalls of an app, you need to
download and use our toolchain. Please follow the following steps:
1. clone the tools repo with the following command: `git clone git@github.com:gaulthiergain/tools.git`;
2. install GO and setup your GO PATH/ROOT variables;
3. run `make deps` within this folder and then run `make`;
4. when you have the `tools` binary file, you can use it as follow:
`./tools --dep -p <program_name> [-o|--options <option>][-t|--testFile <test_file>]`;
5. Note that you need to install yourself the application before using the tools;

Example with the apache web server, a specic config file and a test file.

`sudo ./tools --dep -p ~/dev/bin_programs/apache/httpd-2.4.46/httpd -o " -f /usr/local/apache2/conf/httpd.conf -X -k start" -t ~/go/src/tools/testfiles/test_http.json`

Please refer to the wiki for further information: https://github.com/gaulthiergain/tools/wiki

### Further Information about the heatmap

```
usage: cruncher.py [-h] [-a] [-s] [-p] [-m]

optional arguments:
  -h, --help      show this help message and exit
  -a, --apps      Print system call support in applications
  -s, --syscalls  Print system call usage / popularity in apps
  -p, --plot      Plot syscall support
  -m, --missing   Percentage of syscalls missing per app
```

Note that if you use the `--aggregated-file` argument, you need to 
adapt the `--nb-apps` argument. Its default value is 30.

To get numerical system call statistics in applications use
`cruncher.py`. Use `-s` or `-a` arguments to print system call
popularity or system call support in applications:

```
$ python cruncher.py -s
syscall,status,num_apps
read,OKAY,30
[...]

$ python cruncher.py -a
app,total,okay,not_impl,reg_miss,incomplete,stubbed,planned,broken,in_progress,absent
apache,41,23,8,1,5,1,0,1,2,1
[...]
```