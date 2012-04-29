#! /bin/sh -x
OUTFILE=SetGetPlugin/test-run-output/`date +'%Y-%m-%d-%H-%M-%S'`
export SGPTESTNAME=$1
perl $2 ../bin/TestRunner.pl -clean SetGetPlugin/SetGetPluginSuite.pm 2>&1 | tee $OUTFILE

echo "usage $0 testname|all -d:ptkdb to run under the debugger"
echo "copy of output at $OUTFILE"
