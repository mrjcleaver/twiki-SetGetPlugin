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

# use on a TWiki subversion based checkout (production copies lack the test/ folder)
# cd installdir/core/test/unit/
# sh SetGetPlugin/run-test.sh
# To Use graphical debugger ptkdb and a breakpoint inserted into code
# use $DB::single = 1;
# and perl -d:ptkdb ../bin/TestRunner.pl ...
# http://stackoverflow.com/questions/4691448/can-i-insert-break-point-into-source-perl-program


my $debug = 1;
my $tempStoreFile_not_namespaced = '/tmp/storeFile_not_namespaced';
my $tempStoreFile_namespaced = '/tmp/storeFile_namespaced';

# Set up the test fixture
sub set_up {
    my $this = shift;

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
    set_up_save_persistent_vars_not_namespaced();
    set_up_save_persistent_vars_namespaced();
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
    my ($this, $core, $params) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};
    
    return $core->VarSET($session, $params, $topicName, $webName);
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
    my ($this, $core, $theParams, $optionalWeb) = @_;
    my $session = $this->{twiki};
    my $webName = $optionalWeb || $this->{test_web};
    my $topicName = $this->{test_topic};
    
    my $params = get_params($theParams);
    return $core->VarGET($session, $params, $topicName, $webName);
}

sub do_dump {
    my ($this, $core, $theParams) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    my $params = get_params($theParams);
        
    return $core->VarDUMP($session, $params, $topicName, $webName);
}

# Test existing functionality

# set (volatile) sets the variable
sub test_set_volatile {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1"});
    my $actual = $this->do_get($core,"volatile");

    $this->assert_equals('', $this->do_dump($core)); # There should be no response, this was a transient set    
    $this->assert_equals('v1', $actual);
}

# TODO: test that dump parameters work as specified.

# set (remember) affects the file
sub test_set_remember {
    my $this = shift;

    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remember1", value => "v1", remember=>'1'});
    my $actual = $this->do_get($core,"remember1");
    
    $this->assert_equals('v1', $actual);
    $this->assert_equals("key: remember1, value: v1 <br />\n", $this->do_dump($core));
}

# set (remember)  from 2 different web affects the same variable in the same file
sub test_set_doesnt_care_about_web {
    my $this = shift;

    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remember1", value => "v1", remember=>'1'});
    $this->do_set($core, {_DEFAULT => "remember1", value => "v2", remember=>'1'}, $this->{target_web2}); # this will overwrite v1 because SetGet doesn't distinguish web & topic
    my $actual1 = $this->do_get($core,"remember1");
    my $actual2 = $this->do_get($core,"remember1", $this->{target_web2});
    
    $this->assert_equals('v2', $actual1);
    $this->assert_equals('v2', $actual2);
}

sub test_set_namespace_volatile_should_be_ignored {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", namespace => "ns1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", namespace => "ns2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns2"});
    
    $this->assert_equals('', $this->do_dump($core)); # There should be no response, this was a transient set    
    $this->assert_equals('v2', $actual);
    $this->assert_equals('v2', $actual);
}

=pod
Assumption - users can create as many namespaces as they like, the administrator does not need to configure them

=cut

sub test_set_namespace_remember_needs_to_be_written {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remembered", value => "v0", remember=>"1"});    # not namespaced
    $this->do_set($core, {_DEFAULT => "remembered", value => "v1", namespace => "ns1", remember=>"1"});
    $this->do_set($core, {_DEFAULT => "remembered", value => "v2", namespace => "ns2", remember=>"1"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "remembered", namespace=> "ns1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "remembered", namespace=> "ns2"});
    my $actual_unnamespaced = $this->do_get($core, {_DEFAULT => "remembered"});

    $this->assert_equals("key: remembered, value: v1 <br />\nkey: remembered, value: v2 <br />\n",
                  $this->do_dump($core)); # TODO fix up with namespaces
    $this->assert_equals('v0', $actual_unnamespaced);
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual2);
}

sub test_set_scope_not_remembered_does_not_need_to_be_written {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", scope => "sc1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", scope => "sc2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc2"});

    $this->assert_equals('v2', $actual); # because no remember flag means scope not needed
    $this->assert_equals('v2', $actual);
}

=pod
Tests with a known good scope and remember=1

=cut

sub disabled_test_set_scope_remember_needs_to_be_written {
    my $this = shift;
    
    $TWiki::cfg{SetGetPlugin}{Scopes} = 'sc1, sc2';    
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remembered_scoped", value => "v1", scope => "sc1", remember => "1"});
    $this->do_set($core, {_DEFAULT => "remembered_scoped", value => "v2", scope => "sc2", remember => "1"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "remembered_scoped", scope=> "sc1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "remembered_scoped", scope=> "sc2"});

    $this->assert_equals("key: remembered_scoped, value: v1 <br />\nkey: remembered_scoped, value: v2 <br />\n", $this->do_dump($core)); 
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
}

=pod
Tests with a known bad scope and remember=1
=cut

sub disabled_test_set_scope_remember_bad_scope_needs_to_be_written {
    my $this = shift;
    
    $TWiki::cfg{SetGetPlugin}{Scopes} = 'ScopeA, ScopeB';
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remembered_scoped", value => "v1", scope => "nonExistantScope", remember => "1"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "remembered_scoped", scope=> "sc1"});
    # TODO - do we want to log bad accesses?

    $this->assert_equals('', $this->do_dump($core)); 
    $this->assert_equals('', $actual); # Scope "nonExistantScope" doesn't exist - so no value should be written
}

sub load_persistent_vars {
    my ($tempStoreFile) = @_;
    # copied from SetGetPlugin::Core
        my $text = TWiki::Func::readFile( $tempStoreFile );
        $text =~ /^(.*)$/gs; # untaint, it's safe
        $text = $1;

#    $DB::single = 1;
    
    our $PersistentVars;
    $PersistentVars = eval($text);
    return $PersistentVars;
}


sub test_load_persistent_vars {
    my $this = shift;
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );

    my $PersistentVars = load_persistent_vars($tempStoreFile_not_namespaced);
    print Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);

    #my $vars = load_into_storable($tempStoreFile_not_namespaced);
    
    $this->do_dump($core); # differnt 
    
    $PersistentVars = load_persistent_vars($tempStoreFile_namespaced);
    print Data::Dumper->Dump([$PersistentVars], [qw(PersistentVars)]);

#    $DB::single = 1;

    #my $vars2 = load_into_storable($tempStoreFile_namespaced);
    
    $this->do_dump($core);
}

####### If we need to move to Storable instead of eval. 

use Storable qw(lock_store lock_nstore lock_retrieve);

sub load_into_storable {
    my ($tempStoreFile) = @_;
    
    my $hashref = lock_retrieve($tempStoreFile);    
    return $hashref;
}


sub convert_persistent_vars_to_storeable {

    my ($persistentVarsStoreFile) = @_;
    my $storableStoreFile = $persistentVarsStoreFile.".storable";
    my $vars = load_persistent_vars($persistentVarsStoreFile);
    lock_store($vars, $storableStoreFile);
}


1;
