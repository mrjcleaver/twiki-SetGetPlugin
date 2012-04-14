#! /bin/sh -x
OUTFILE=SetGetPlugin/test-run-output/`date +'%Y-%m-%d-%H-%M-%S'`
perl $1 ../bin/TestRunner.pl -clean SetGetPlugin/SetGetPluginSuite.pm 2>&1 | tee $OUTFILE

echo "usage $0 -d:ptkdb to run under the debugger"
echo "copy of output at $OUTFILE"
