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
# run-test.sh test_name/all test_nameOfTest

# To Use graphical debugger ptkdb with a breakpoint (use $DB::single = 1;) inserted into code
# run-test test_name/all -d:ptkdb 
# http://stackoverflow.com/questions/4691448/can-i-insert-break-point-into-source-perl-program

our $RunAllDebugLevel = 1; # if running the suite (0 = minimal; 1 = shows all calls)
our $RunOneDebugLevel = 2; # if running a named test. Usually 2 (show test specific things), but 3 (show everything)

## ----- Candidates to be promoted to TestCase.pm

=pod
Overrides the list of tests to only run the one test provided on the command line
And turns up debug output
=cut
sub list_tests {
    my ($this, $suite) = @_;
    my @tests = $this->SUPER::list_tests($suite);
    if ($ENV{SGPTESTNAME} && $ENV{SGPTESTNAME} ne 'all') {
        @tests = ('SetGetPluginTests::'.$ENV{SGPTESTNAME});
        $this->{RunOnlyOne} = $ENV{SGPTESTNAME};
    }
    return @tests;
}

sub narrate {
    my ($this, $message) = @_;
    print "* ".$message."\n" if $this->{DebuggedSettings}->{Debug} > 1; 
}

sub traceInDebug {
    my ($this, @toTrace) = @_;
    map {
          $this->{DebuggedSettings}->{DebugTraceSub}{$_} = '1'
        } @toTrace;
    $this->narrate("Tracing ".join(', ', sort @toTrace)) if $this->{DebuggedSettings}->{Debug} > 1;
}

sub breakInDebug {
    my ($this, @toTrace) = @_;
    map {
          $this->{DebuggedSettings}->{DebugBreakSub}{$_} = '1'
        } @toTrace;
    $this->narrate("Breaking ".join(', ', sort @toTrace)) if $this->{DebuggedSettings}->{Debug} > 1;
}    

# we print out as well as store for stack trace time any messages about results.
sub annotate {
    my ($this, $message) = @_;
    $this->SUPER::annotate($message);
    $this->narrate($message);
}

## ----- End of Candidates to be promoted to TestCase.pm

my $tempStoreFile_not_namespaced = '/tmp/storeFile_not_namespaced';
my $tempStoreFile_namespaced = '/tmp/storeFile_namespaced';

# Set up the test fixture
sub set_up {
    my $this = shift;
    $DB::single = 1; ## Don't delete. Comment out if necessary.
    
    $this->{DebuggedSettings} = {
                    DebugTraceSub => { 
                                    VarGET => 1,
                                    VarSET => 1,
                                    },
                    DebugBreakSub  => {
                        DESTROY => 1,
                    },
                    Debug => $RunAllDebugLevel,
                };
    if (defined $this->{RunOnlyOne}) { # defined from list_tests
        print "Setting debug=2\n";
        $this->{DebuggedSettings}->{Debug} = $RunOneDebugLevel;
    }

# In a particular test, once initialized, you can trace or break a sub like this:
#    $this->{DebuggedSettings}->{DebugTraceSub}->{'_loadConfigSpec'} = '1';
#    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
# This will emit/break on the first call to $this->{DebuggedSettings}()
    
    
    $this->SUPER::set_up();
    
    $this->{target_web} = "$this->{test_web}Target";
    $this->{target_web2} = "$this->{test_web}Target2";
    $this->{target_topic} = "$this->{test_topic}Target";
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web}
    );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web2}
    );

}


sub tear_down {
    my $this = shift;
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web});
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web2});    
    
    unlink $tempStoreFile_namespaced;
    unlink $tempStoreFile_not_namespaced;
    
    $this->SUPER::tear_down();
    #$this->printLogs(); #TODO - show the logs 
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

# get_params - used by do_get
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

# ==================== TESTS START HERE ====================

# Test 1.0 functionality

sub test_set_volatile {
    my $this = shift;
    
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();
    $this->narrate("Set a value, but only into memory, so the key should be retreivable but the store should be empty");
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1"});
    my $actual = $this->do_get($setgetplugin,$keyname);

    $this->assert_equals('', $this->do_dump($setgetplugin)); # 
    $this->assert_equals('v1', $actual);
}

# TODO: test that dump parameters work as specified.

sub test_set_remember {
    my $this = shift;

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();
    
    $this->narrate("Set a value, into the default store. The key should be retreivable and the store dump should show it formatted");
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

    $this->narrate("Set the same remembered variable from two different topics, show that SetGet is independent of the topic name");
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

    $this->narrate("Illustrate that the default parameter works");
    my $actual1 = $this->do_get($setgetplugin, { _DEFAULT => $keyname, 'default' => 'default_ans'});

    $this->assert_equals('default_ans', $actual1);
}

sub test_set_namespace_volatile_should_be_ignored {
    my $this = shift;
    
    my $keyname = subname();
    
    $this->narrate("The namespace feature was not wanted for volatile variables. It is silently ignored without remember");
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", namespace => "ns1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", namespace => "ns2"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, namespace=> "ns2"});
    
    $this->assert_equals('', $this->do_dump($setgetplugin)); # There should be no response, this was a transient set    
    $this->assert_equals('v2', $actual);
    $this->assert_equals('v2', $actual);
}

sub test_set_namespace_remember {
    my $this = shift;
    my $keyname = subname();
    
    $this->narrate("Users can create as many namespaces as they like, the administrator does not need to configure them");
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
    
    $this->narrate("Any use of the store parameter without the remember parameter will be *silently ignored*");
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v1", store => "store1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, value => "v2", store => "store2"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "store1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "store2"});

    $this->assert_equals('v2', $actual); # because no remember flag means store not needed
    $this->assert_equals('v2', $actual);
}


sub test_unallowed_stores_should_revert_to_default {
    my $this = shift;
    my $keyname = subname();
    
    $this->narrate("If UndeclaredStoresBehaviour}=createUnknown");
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


sub test_create_stores_on_the_fly {
    my $this = shift;
    my $keyname = subname();

    $this->narrate("If {UndeclaredStoresBehaviour}=createUnknown, then the user can make stores on the fly, without a setting in configure to enable that store");
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $setgetplugin->{UndeclaredStoresBehaviour} = 'createUnknown';
    
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, store => "st1", value => "v1", remember => "1"});
    $this->do_set($setgetplugin, {_DEFAULT => $keyname, store => "st2", value => "v2", remember => "1"});
    
    my $actual = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "st1"});
    my $actual2 = $this->do_get($setgetplugin, {_DEFAULT => $keyname, store => "st2"});

    #$this->assert_equals("key: $keyname, value: v1 <br />\nkey: $keyname, value: v2 <br />\n", $this->do_dump($setgetplugin)); 
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual2);
    

}


sub test_set_store_remember_parallel_access {
    my $this = shift;
    my $keyname = subname();
    
    $this->annotate("Tests that a changed store file results in a reload of the underlying file");

    
    my $storeType = 'Storable';
    $this->traceInDebug(qw(_loadConfigSpec _loadStore _getPersistentHash _setPersistentHash _loadPersistentVarsTWikiReadFile _loadPersistentVarsStorableLock));
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
    
    $this->traceInDebug(qw(_loadConfigSpec));
    #$this->breakInDebug(qw(_loadConfigSpec));

    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    $this->assert("Config.spec has the right defaults");
    
    $this->assert_equals("persistentvars.dat", $setgetplugin->{StoreFileMapping}{defaultStore});
    $this->assert_equals("Storable", $setgetplugin->{DefaultStoreType});
    $this->assert_equals(".dat", $setgetplugin->{StoreExtension}{Legacy});
    $this->assert_equals(".store", $setgetplugin->{StoreExtension}{Storable});
}


sub test_loadConfigSpecExtraStores {
    my $this = shift;
    my $keyname = subname();
    
    $TWiki::cfg{SetGetPlugin}{OtherStores} = 'noExtension, storeExtension.store, datExtension.dat';

    $this->{DebuggedSettings}->{DebugBreakSub}->{'_loadConfigSpec'} = '1';
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );    
    $this->assert_equals("Storable", $setgetplugin->{DefaultStoreType});
    $this->assert_equals("noExtension.store", $setgetplugin->{StoreFileMapping}{noExtension});
    $this->assert_equals("storeExtension.store", $setgetplugin->{StoreFileMapping}{storeExtension});
    $this->assert_equals("datExtension.dat", $setgetplugin->{StoreFileMapping}{datExtension});
}




sub test_saveStoresSavesInRightFormatsAndConvertsBetweenFormats {
    my $this = shift;
    my $keyname = subname();

    $this->traceInDebug(qw(_savePersistentVarsTWikiReadFile _savePersistentVarsStorableLock _loadConfigSpec _convertPersistentVarsIntoStorableLock _convertStorableLockIntoPersistentVars _loadStore _saveStore _storeFileForStore _convertStorableLockIntoPersistentVars ));

    $TWiki::cfg{SetGetPlugin}{OtherStores} = 'store1.store, dat1.dat';
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



sub test_fixUpDataStructure {
    my $this = shift;
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    my $keyname = subname();

    $this->traceInDebug(qw(_fixUpDataStructure VarGET _getPersistentHash _loadStore));

    $this->narrate("Previous releases of SetGetPlugin did not use namespaces. So we need to make sure those get put into the defaultNamespace");
    
    my $inputPersistentVars = { 
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
    
    use Storable qw(dclone);
    my $inputPersistentVars2 = dclone($inputPersistentVars);
    
    my $expectedPersistentVars = {
        'ns1' => {
            'HoldMilestoneID00153_UNIX' => '1333131708',
            'HoldMilestoneID00293_TIME' => '2535',
        },
        'ns2' => {
            'MilestoneID00097_BL' => '1333132500',
            'HoldMilestoneID00169_UNIX' => '1333149708',
        },
        'defaultNamespace' => {
            'MilestoneID00078_UNIX' => '1333116558',
            'HoldMilestoneID00349_BL' => '1333128300',
        }
    };

    my $outputPersistentVars = $setgetplugin->_fixUpDataStructure($inputPersistentVars);
    $this->assert_deep_equals($outputPersistentVars, $expectedPersistentVars);        
    $this->narrate("Now push them into defaultStore, just to be sure");
    
    my $defaultStoreFile = $setgetplugin->_storeFileForStore('defaultStore');
    $this->assert_not_null($defaultStoreFile);

    
    my $text = Data::Dumper->Dump([$inputPersistentVars2], [qw(PersistentVars)]);    
    # NB. BREAKS ENCAPSULATION 
    TWiki::Func::saveFile($defaultStoreFile, $text ) ;
    ##
    
    $this->narrate("Having changed the file under the covers, perform a SET so SetGetPlugin is forced to reload the file before setting it");
    $this->do_set($setgetplugin, {"_DEFAULT" => "Reload", value => "File", remember=>"1" });

    my $impliedNamespacedValue = $this->do_get($setgetplugin, {_DEFAULT => 'MilestoneID00078_UNIX'});
    my $namedNamespacedValue = $this->do_get($setgetplugin, {_DEFAULT => 'MilestoneID00078_UNIX', namespace=>'defaultNamespace'});
    my $ns1Value = $this->do_get($setgetplugin, {_DEFAULT => 'HoldMilestoneID00153_UNIX', namespace=>'ns1'});
    my $ns2Value = $this->do_get($setgetplugin, {_DEFAULT => 'MilestoneID00097_BL', namespace=>'ns2'});
    
    $this->assert_not_null($setgetplugin->_storeFileExists('defaultStore'));
    
    $this->assert_equals($impliedNamespacedValue, '1333116558');
    $this->assert_equals($namedNamespacedValue, '1333116558');
    $this->assert_equals($ns1Value, '1333131708');
    $this->assert_equals($ns2Value, '1333132500');
    
}

sub test_client_scenario1 {
    my $this = shift;
    my $setgetplugin = new TWiki::Plugins::SetGetPlugin::Core( $this->{DebuggedSettings} );
    
    $this->traceInDebug(qw( VarGET VarDUMPALL VarDUMP));
        
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
    
    my $actual_dumpAll = $setgetplugin->VarDUMPALL();
    my $expected_dumpAll = <<EOM;
store: defaultStore namespace: ns2 key: dummyvar_001, value: cello2 <br />
store: defaultStore namespace: ns1 key: dummyvar_001, value: cello1 <br />
store: newstore namespace: defaultNamespace key: dummyvar_001, value: cello2 <br />
store: newdat namespace: defaultNamespace key: dummyvar_001, value: cello1 <br />
EOM
    $this->assert_equals($actual_dumpAll, $expected_dumpAll);
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


1;
