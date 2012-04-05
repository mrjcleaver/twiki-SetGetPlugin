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

# cd installdir/core/test/unit/
# perl ../bin/TestRunner.pl -clean SetGetPlugin/SetGetPluginSuite.pm > SetGetPlugin/test-run-output/1.out 2>&1

my $debug = 1;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    
    $this->{target_web} = "$this->{test_web}Target";
    $this->{target_web2} = "$this->{test_web}Target2";
    $this->{target_topic} = "$this->{test_topic}Target";
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web});
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web2});
}

sub tear_down {
    my $this = shift;
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web});
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web2});
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
    #print "get($theParams):  ". ref($theParams)."\n";
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
    $this->assert('key: remember1, value: v1 <br />', $this->do_dump($core));
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

sub test_set_namespace_volatile_should_fail {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", namespace => "ns1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", namespace => "ns2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns2"});

    $this->assert('', $this->do_dump($core)); # There should be no response, this was a transient set    
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
}

sub test_set_namespace_remember_should_fail {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remembered", value => "v1", namespace => "ns1", remember=>"1"});
    $this->do_set($core, {_DEFAULT => "remembered", value => "v2", namespace => "ns2", remember=>"1"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns2"});

    $this->assert('key: remembered, value: v1 <br />\nkey: remembered, value: v2 <br />', $this->do_dump($core)); 
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);

}

sub test_set_scope_should_fail {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", scope => "sc1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", scope => "sc2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc2"});

    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
}

sub test_set_scope_remember_should_fail {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remembered_scoped", value => "v1", scope => "sc1", remember => "1"});
    $this->do_set($core, {_DEFAULT => "remembered_scoped", value => "v2", scope => "sc2", remember => "1"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "remembered_scoped", scope=> "sc1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "remembered_scoped", scope=> "sc2"});

    $this->assert('key: remembered_scoped, value: v1 <br />\nkey: remembered_scoped, value: v2 <br />', $this->do_dump($core)); 
    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
}

1;
