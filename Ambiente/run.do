vsim +access+r +UVM_TESTNAME=load_test;
run -all;
acdb save;
acdb report -db fcover.acdb -txt -o cov.txt -verbose
exec cat cov.txt
exit