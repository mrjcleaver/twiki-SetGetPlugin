use strict;

package SetGetPluginTests;

use base qw(TWikiFnTestCase);

use TWiki::Plugins::SetGetPlugin;
use TWiki::Plugins::SetGetPlugin::Core;
use TWiki::Attrs;
use Data::Dumper;
use TWiki;
use CGI;
use Error qw( :try );
use File::Slurp; # this is on track to be in Perl6, so okay to use

# use on a TWiki subversion based checkout (production copies lack the test/ folder)

# To run all tests
# cd installdir/core/test/unit/
# sh SetGetPlugin/run-test.sh

# To run just one test
# run-test.sh testname/all test_nameOfTest

# To Use graphical debugger ptkdb with a breakpoint (use $DB::single = 1;) inserted into code
# run-test testname/all -d:ptkdb 
# http://stackoverflow.com/questions/4691448/can-i-insert-break-point-into-source-perl-program

=pod
Overrides the list of tests to only run the one test provided on the command line
And turns up debug output
=cut
sub list_tests {
    my ($this, $suite) = @_;
    my @tests = $this->SUPER::list_tests($suite);
    if ($ENV{SGPTESTNAME} && $ENV{SGPTESTNAME} ne 'all') {
        @tests = ('SetGetPluginTests::'.$ENV{SGPTESTNAME});
        $this->{DebuggedSettings}->{Debug} = '2';
    }
    return @tests;
}

sub narrate {
    my ($this, $message) = @_;
    my $caller = subname(2);
    print "* ".$message."\n" if $this->{Debug}; 
}

sub narrateDebug {
    my ($this) = @_;
    $this->narrate("Tracing ".join(', ', sort keys(%{$this->{DebuggedSettings}->{DebugTraceSub}}))) if $this->{Debug};
}
    

# we print out as well as store for stack trace time any messages about results.
sub annotate {
    my ($this, $message) = @_;
    $this->SUPER::annotate($message);
    $this->narrate($message);
}



my $tempStoreFile_not_namespaced = '/tmp/storeFile_not_namespaced';
my $tempStoreFile_namespaced = '/tmp/storeFile_namespaced';

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->{DebuggedSettings} = {
                    DebugTraceSub => { 
                                    VarGET => 1,
                                    VarSET => 1,
                                    },
                    DebugBreakSub  => {
                        DESTROY => 1,
                    },
                    Debug => 1
                };
    $this->{DebuggedSettings}->{Debug} = '1';

# In a particular test, once initialized, you can trace or break a sub like this:
#    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadConfigSpec'} = '1';
#    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
# This will emit/break on the first call to $this->{DebuggedSettings}()
    
    
    $this->SUPER::set_up();
    
    $DB::single = 1;
    
    $this->{target_web} = "$this->{test_web}Target";
    $this->{target_web2} = "$this->{test_web}Target2";
    $this->{target_topic} = "$this->{test_topic}Target";
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web}
    );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web2}
    );
    #set_up_save_persistent_vars_not_namespaced();
    #set_up_save_persistent_vars_namespaced();
}


sub set_up_save_persistent_vars_not_namespaced {
    my $PersistentVars = {
                        'HoldMilestoneID00153_UNIX' => '1333131708',
                        'HoldMilestoneID00293_TIME' => '2535',
                        'MilestoneID00097_BL' => '1333132500',
                        'HoldMilestoneID00169_UNIX' => '1333149708',
                        'MilestoneID00078_UNIX' => '1333116558',
                        'HoldMilestoneID00349_BL' => '1333128300',
    };
    # copied from SetGetPlugin::Core    
    my $text = Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);
    TWiki::Func::saveFile( $tempStoreFile_not_namespaced, $text ) ;
}


sub set_up_save_persistent_vars_namespaced {
    # Some namespaced, others not
    my $PersistentVars = { 
                            'ns1' => {
                                'HoldMilestoneID00153_UNIX' => '1333131708',
                                'HoldMilestoneID00293_TIME' => '2535',
                            },
                            'ns2' => {
                                'MilestoneID00097_BL' => '1333132500',
                                'HoldMilestoneID00169_UNIX' => '1333149708',
                            },
                            'MilestoneID00078_UNIX' => '1333116558',
                            'HoldMilestoneID00349_BL' => '1333128300',                            
    };
    # copied from SetGetPlugin::Core    
    my $text = Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);
    TWiki::Func::saveFile( $tempStoreFile_namespaced, $text ) ;
}

sub tear_down {
    my $this = shift;
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web});
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web2});
    
    
    unlink $tempStoreFile_namespaced;
    unlink $tempStoreFile_not_namespaced;
    
    $this->SUPER::tear_down();
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_set {
    my ($this, $setgetplugin, $params) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    return $setgetplugin->VarSET($session, $params, $topicName, $webName);
}

sub get_params {
    my ($defaultParams) = @_;
    my $params; 
    if (ref ($defaultParams) eq "HASH") {
        $params = $defaultParams;
    } else {
        $params = {_DEFAULT => $defaultParams};
    }    
}

=pod
    @optionalWeb should never make a difference to results.
=cut 
sub do_get {
    my ($this, $setgetplugin, $theParams, $optionalWeb) = @_;
    my $session = $this->{twiki};
    my $webName = $optionalWeb || $this->{test_web};
    my $topicName = $this->{test_topic};
    
    my $params = get_params($theParams);
    return $setgetplugin->VarGET($session, $params, $topicName, $webName);
}

sub do_dump {
    my ($this, $setgetplugin, $theParams) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    my $params = get_params($theParams);
        
    return $setgetplugin->VarDUMP($session, $params, $topicName, $webName);
}

sub subname {
    my ($ancestor) = shift || 1;
    my $parentSub = (caller($ancestor))[3];
    $parentSub =~ s/:+/_/g;
    return $parentSub;
}

# Test existing functionality

# set (volatile) sets the variable
sub test_set_volatile {
    my $this = shift;
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1"});
    my $actual = $this->do_get($setgetplugin,$keyname);

    $this->assert_equals('', $this->do_dump($setgetplugin)); # There should be no response, this was a transient set    
    $this->assert_equals('v1', $actual);
}

# TODO: test that dump parameters work as specified.

# set (remember) affects the file
sub test_set_remember {
    my $this = shift;

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", remember=>'1'});

    my $actual = $this->do_get($setgetplugin, $keyname);
    
    $this->assert_equals('v1', $actual);
    $this->assert_equals("key: ".$keyname.", value: v1 <br />\n", $this->do_dump($setgetplugin));
}

# set (remember)  from 2 different web affects the same variable in the same file
sub test_set_doesnt_care_about_web {
    my $this = shift;

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();

    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", remember=>'1'});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", remember=>'1'}, $this->{target_web2}); # this will overwrite v1 because SetGet doesn't distinguish web & topic
    my $actual1 = $this->do_get($setgetplugin, $keyname);
    my $actual2 = $this->do_get($setgetplugin, $keyname, $this->{target_web2});
    
    $this->assert_equals('v2', $actual1);
    $this->assert_equals('v2', $actual2);
}

# default parameters answers should make sense
sub test_default_param_works {
    my $this = shift;

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();

    my $actual1 = $this->do_get($setgetplugin, { _DEFAULT => $keyname, 'default' => 'default_ans'});

    $this->assert_equals('default_ans', $actual1);
}

sub test_set_namespace_volatile_should_be_ignored {
    my $this = shift;
    
    my $keyname = subname();
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", namespace => "ns1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", namespace => "ns2"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns2"});
    
    $this->assert_equals('', $this->do_dump($setgetplugin)); # There should be no response, this was a transient set    
    $this->assert_equals('v2', $actual);
    $this->assert_equals('v2', $actual);
}

=pod
Assumption - users can create as many namespaces as they like, the administrator does not need to configure them

=cut

sub test_set_namespace_remember {
    my $this = shift;
    my $keyname = subname();
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v0", remember=>"1"});    # not namespaced
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", namespace => "ns1", remember=>"1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", namespace => "ns2", remember=>"1"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns2"});
    my $actual_unnamespaced = $this->do_get($setgetplugin, {_DEFAULT => $keyname});

    #$this->assert_equals("key: $keyname, value: v1 <br />\nkey: remembered, value: v2 <br />\n",
    #              $this->do_dump($setgetplugin)); # TODO fix up with namespaces
    $this->assert_equals('v0', $actual_unnamespaced);
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual2);
}

sub test_set_store_not_remembered_does_not_need_to_work {
    my $this = shift;
    my $keyname = subname();
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", store => "store1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", store => "store2"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "store1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "store2"});

    $this->assert_equals('v2', $actual); # because no remember flag means store not needed
    $this->assert_equals('v2', $actual);
}

=pod
Tests with a known good store and remember=1

=cut

sub test_set_store_remember {
    my $this = shift;
    my $keyname = subname();

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $setgetplugin->{UndeclaredStoresBehaviour} = 'createUnknown';
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, store => "st1", value => "v1", remember => "1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, store => "st2", value => "v2", remember => "1"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "st1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "st2"});

    #$this->assert_equals("key: $keyname, value: v1 <br />\nkey: $keyname, value: v2 <br />\n", $this->do_dump($setgetplugin)); 
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual2);
    
    $setgetplugin->_dumpStores();
}


sub test_set_store_remember_parallel_access {
    my $this = shift;
    my $keyname = subname();
    
    $this->annotate("Tests that a changed store file results in a reload of the underlying file");
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadConfigSpec'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadStore'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_getPersistentHash'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_setPersistentHash'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadPersistentVarsTWikiReadFile'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadPersistentVarsStorableLock'} = '1';
    
    my $storeType = 'Storable';
    $this->narrateDebug();
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $setgetplugin->{DefaultStoreType} = $storeType;
    my $setgetplugin2 = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $setgetplugin2->{DefaultStoreType} = $storeType;
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, store => "st1", value => "v1", remember => "1"});
    $this->do_set($setgetplugin2, {_DEFAULT => $keyname, store => "st1", value => "v2", remember => "1"});
    
    $this->narrate("If two pages write to the same remembered store value, and write from access B follows write from access A
should an in-page access from A look back at the store (& get value B) or should it look in the in-memory version?\n\nAnswer: it should get its in-memory version");
    my $actual1 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "st1"});
    my $actual2 = $this->do_get($setgetplugin2, {_DEFAULT => $keyname, store => "st1"});

    #$this->assert_equals("key: $keyname, value: v1 <br />\nkey: $keyname, value: v2 <br />\n", $this->do_dump($setgetplugin));
    $this->annotate("Access from session 1 that has a local value ".$actual1);
    $this->assert_equals('v1', $actual1);
    $this->annotate("Access from session 2 takes the same local value, ".$actual2);
    $this->assert_equals('v1', $actual2);

    $this->narrate("However, if one page writes to a remembered store value, and another page looks up that value and does not have an
in-memory value then it should not find a value as it is using a volatile setting");
    my $setgetplugin3 = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $actual3 = $this->do_get($setgetplugin3, {_DEFAULT => $keyname, store => "st1"});
    $this->annotate("Access from a page that doesn't have a local value, so should find nothing ".$actual3);
    $this->assert_equals('', $actual3);
    
    $setgetplugin->_dumpStores();
}

# TODO: I changed the name of the default store, from default to defaultStore
sub test_undeclared_stores_behaviours {
    my $this = shift;
    my $keyname = subname();
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $shouldBeDefault = $setgetplugin->_storeFileForStore('default');
    $this->assert_matches('.*persistentvars.dat$', $shouldBeDefault);
    
    $setgetplugin->{UndeclaredStoresBehaviour} = 'create';
    my $shouldBeNewStore = $setgetplugin->_storeFileForStore('newstore');
    $this->assert_matches('.*newstore.dat$', $shouldBeNewStore);

    $setgetplugin->{UndeclaredStoresBehaviour} = 'revert';
    my $shouldBeRevertedToDefault = $setgetplugin->_storeFileForStore('notallowednewstore');
    $this->assert_matches('.*persistentvars.dat$', $shouldBeRevertedToDefault);    

}

sub test_persistentVarsIsDefault {
    my $this = shift;
    my $keyname = subname();
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    
    $this->assert_matches('.*persistentvars.dat$', $setgetplugin->{StoreFileMapping}{defaultStore});    
}

sub test_loadConfigSpecDefaultConfig {
    my $this = shift;
    my $keyname = subname();
    
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadConfigSpec'} = '1';
    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );    
    $this->assert_equals("persistentvars.dat", $setgetplugin->{StoreFileMapping}{defaultStore});
    $this->assert_equals("Legacy", $setgetplugin->{DefaultStoreType});
    $this->assert_equals(".dat", $setgetplugin->{StoreExtension}{Legacy});
    $this->assert_equals(".store", $setgetplugin->{StoreExtension}{Storable});
}


sub test_loadConfigSpecExtraStores {
    my $this = shift;
    my $keyname = subname();
    
    $TWiki::cfg{SetGetPlugin}{OtherStores} = 'noExtension, storeExtension.store, datExtension.dat';

    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );    
    $this->assert_equals("Legacy", $setgetplugin->{DefaultStoreType});
    $this->assert_equals("noExtension.dat", $setgetplugin->{StoreFileMapping}{noExtension});
    $this->assert_equals("storeExtension.store", $setgetplugin->{StoreFileMapping}{storeExtension});
    $this->assert_equals("datExtension.dat", $setgetplugin->{StoreFileMapping}{datExtension});
}

sub test_loadImportsLegacyNonNamespacedPersistentVars {
    my $this = shift;
    my $keyname = subname();
    
    $this->narrate("Previous releases of SetGetPlugin did not use namespaces. So we need to make sure those get put into the defaultNamespace");
    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    
    my $defaultStoreFile = $setgetplugin->_storeFileForStore('defaultStore');
    $this->assert_not_null($defaultStoreFile);
    
    my $legacyFormat =<<"EOM";
\$PersistentVars = {
                    'defaultNamespace' => {
                                            '$keyname' => 'cello'
                                          }
                  };
EOM
    
}


sub test_saveStoresSavesInRightFormatsAndConvertsBetweenFormats {
    my $this = shift;
    my $keyname = subname();
    
    $TWiki::cfg{SetGetPlugin}{OtherStores} = 'store1.store, dat1.dat';
    $this->{DebuggedSettings}->{Debug} = '0';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_savePersistentVarsTWikiReadFile'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_savePersistentVarsStorableLock'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadConfigSpec'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_convertPersistentVarsIntoStorableLock'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_convertStorableLockIntoPersistentVars'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadStore'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_saveStore'} = '1';
    $this->{DebuggedSettings}->{DebugTraceSub}->{'_storeFileForStore'} = '1';
    $this->{DebuggedSettings}->{DebugBreakSub}->{'_convertStorableLockIntoPersistentVars'} = '1';
    
    $this->narrateDebug();
    $TWiki::cfg{SetGetPlugin}{StoreExtension}{Legacy} = '.dat';
    $TWiki::cfg{SetGetPlugin}{StoreExtension}{Storable} = '.store';
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );

    $this->narrate("Set a variable into defaultStore");

    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "cello", remember => "1"});
    
    $this->narrate("Make sure it saved correctly");
    my $defaultStoreFile = $setgetplugin->_storeFileForStore('defaultStore');
    $this->assert_not_null($defaultStoreFile);
    my $defaultStoreFileContents = read_file($defaultStoreFile);
    
    my $expectedDefaultContent =<<"EOM";
\$PersistentVars = {
                    'defaultNamespace' => {
                                            '$keyname' => 'cello'
                                          }
                  };
EOM
    $this->assert_equals($expectedDefaultContent, $defaultStoreFileContents);

    # make sure the store we are putting this into is already empty
    my $store1File = $setgetplugin->_storeFileForStore('store1');
    $this->assert_not_null($store1File);
    
    $this->assert_null(-e $store1File);

    $this->narrate("Now convert that into a Storable");
    $setgetplugin->_convertPersistentVarsIntoStorableLock($defaultStoreFile, $store1File);
    $this->assert_not_null(-e $store1File);
 
    my $store1FileContents = read_file($store1File);

    $this->narrate("Not going to test the contents of store1File as it has binary content");
    
    $this->narrate("Now that Storable back into another Legacy file");
    my $dat1File = $setgetplugin->_storeFileForStore('dat1');
    $this->assert_not_null($dat1File);
    
    $setgetplugin->_convertStorableLockIntoPersistentVars($store1File, $dat1File);
    my $dat1FileContents = read_file($dat1File);
    $this->assert_equals($expectedDefaultContent, $dat1FileContents);    
}


sub test_client_scenario1 {
    my $this = shift;
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = "dummyvar_001";
    $setgetplugin->{StoreFileMapping}{newdat} = 'new.dat';
    $setgetplugin->{StoreFileMapping}{newstore} = 'new.store';
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "cello1", store => "newdat", remember => "1"});
    my $actual1 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "newdat"});
    $this->assert_equals("cello1", $actual1); 
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "cello2", store => "newstore", remember => "1"});    
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "newstore"});
    $this->assert_equals("cello2", $actual2); 
    
    my $actual1_no_store = $this->do_get($setgetplugin, {_DEFAULT => $keyname});
    $this->assert_equals("", $actual1_no_store);
    
    my $actual2_no_store = $this->do_get($setgetplugin, {_DEFAULT => $keyname});
    $this->assert_equals("", $actual2_no_store);
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "cello1", namespace => "ns1", remember => "1"});
    my $actual1_ns1 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace => "ns1"});
    $this->assert_equals("cello1", $actual1_ns1); 
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "cello2", namespace => "ns2", remember => "1"});    
    my $actual1_ns2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace => "ns2"});
    $this->assert_equals("cello2", $actual1_ns2);     
    
    my $actual1_unqualified = $this->do_get($setgetplugin, {_DEFAULT => $keyname});
    $this->assert_equals("", $actual1_unqualified);    
}

=pod
Tests with a known bad store and remember=1
=cut

sub disabled_test_set_store_remember_bad_store_needs_to_be_written {
    my $this = shift;
    my $keyname = subname();
    
    $TWiki::cfg{SetGetPlugin}{stores} = 'storeA, storeB';
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", store => "nonExistantStore", remember => "1"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store=> "st1"});
    # TODO - do we want to log bad accesses?

    $this->assert_equals('', $this->do_dump($setgetplugin)); 
    $this->assert_equals('', $actual); # store "nonExistantStore" doesn't exist - so no value should be written
}

sub load_persistent_vars {
    my ($tempStoreFile) = @_;
    # copied from SetGetPlugin::Core
        my $text = TWiki::Func::readFile( $tempStoreFile );
        $text =~ /^(.*)$/gs; # untaint, it's safe
        $text = $1;
    
    our $PersistentVars;
    $PersistentVars = eval($text);
    return $PersistentVars;
}


sub junk_test_load_persistent_vars {
    my $this = shift;
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );

    my $PersistentVars = load_persistent_vars($tempStoreFile_not_namespaced);
    print Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);

    #my $vars = load_into_storable($tempStoreFile_not_namespaced);
    
    $this->do_dump($setgetplugin); # differnt 
    
    $PersistentVars = load_persistent_vars($tempStoreFile_namespaced);
    print Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);


    #my $vars2 = load_into_storable($tempStoreFile_namespaced);
    
    $this->do_dump($setgetplugin);
}
1;
