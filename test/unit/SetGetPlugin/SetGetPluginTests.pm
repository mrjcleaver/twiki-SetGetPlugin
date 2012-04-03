use strict;

package SetGetPluginTests;

use base qw(TWikiFnTestCase);

use TWiki::Plugins::SetGetPlugin;
use TWiki::Plugins::SetGetPlugin::Core;
use TWiki::Attrs;
use TWiki;
use CGI;
use Error qw( :try );

# perl ../bin/TestRunner.pl -clean SetGetPlugin/SetGetPluginSuite.pm

my $debug = 1;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    
    $this->{target_web} = "$this->{test_web}Target";
    $this->{target_topic} = "$this->{test_topic}Target";
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{target_web});
}

sub tear_down {
    my $this = shift;
    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $this->{target_web});
    $this->SUPER::tear_down();
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_set {
    my ($this, $core, $params) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};
    
    $core->VarSET($session, $params, $topicName, $webName);
}

sub do_get {
    my ($this, $core, $theParams) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};
    
    #print "get($theParams):  ". ref($theParams)."\n";
    my $params; 
    if (ref ($theParams) eq "HASH") {
       $params = $theParams;
    } else {
        $params = {_DEFAULT => $theParams};
    }
    $core->VarGET($session, $params, $topicName, $webName);
}

# Test existing functionality

# 1) set (volatile) sets the variable
sub test_set_volatile {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1"});
    my $actual = $this->do_get($core,"volatile");
    
    $this->assert_equals('v1', $actual);
}

# 2) set (remember) affects the file
sub test_set_remember {
    my $this = shift;

    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "remember1", value => "v1", remember=>'1'});
    my $actual = $this->do_get($core,"remember1");
    
    $this->assert_equals('v1', $actual);   
}

# 3) set namespace works
sub test_set_namespace_volatile {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", namespace => "ns1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", namespace => "ns2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", namespace=> "ns2"});

    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
    
}
# 4) set scope works
sub test_set_scope {
    my $this = shift;
    
    my $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    $this->do_set($core, {_DEFAULT => "volatile", value => "v1", scope => "sc1"});
    $this->do_set($core, {_DEFAULT => "volatile", value => "v2", scope => "sc2"});
    
    my $actual = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc1"});
    my $actual2 = $this->do_get($core, {_DEFAULT => "volatile", scope=> "sc2"});

    $this->assert_equals('v1', $actual);
    $this->assert_equals('v2', $actual);
    
}

1;
