# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010-2012 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is the core module of the SetGetPlugin.

package TWiki::Plugins::SetGetPlugin::Core;

use Data::Dumper;
# =========================
sub new {
    my ( $class, $debug ) = @_;

    my $this = {
          Debug          => $debug,
          UndeclaredStoresBehaviour => 'create',
          VolatileVars   => undef,
          PersistentVars => undef,
          StoreFileDir  => TWiki::Func::getWorkArea( 'SetGetPlugin' ),
          StoreFileMapping => {
            "defaultStore" => "persistentvars.dat",
          },
          StoreTimeStamps => {
            "default" => 0,
          }
        };
    bless( $this, $class );
    $this->debug( "Core constructor" ) if $this->{Debug};

    $this->_loadPersistentVars();

    return $this;
}

sub DESTROY {
    my ($this) = @_;
    if ($this->{Debug}) {
        $DB::single = 1;
        $this->_dumpStores();
        print "========================================================================\n";
    }
}

sub debug {
    my ($this, $message) = @_;
    $message = $message;
    TWiki::Func::writeDebug(' - SetGetPlugin '.$message);
    print STDOUT "\t\t".$message."\n" if ($this->{Debug} > 1);
}

sub _dumpStores {
    my ($this) = @_;
    foreach my $store (keys %{$this->{StoreFileMapping}}) {
        my $storeFile = $this->_storeFileForStore($store);
        if (-e $storeFile) {
            print "== STOREFILE $store @ $storeFile==\n";
            system("cat ".$storeFile);
        }
    }
}


# =========================
sub VarDUMP
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    my ($store, $namespace)  = $this->_getStoreAndNamespaceFromParams($params);    

    $this->debug( "DUMP ($store, $namespace, $name)" ) if $this->{Debug};
    #return '' unless( $name );

    my $value = '';
    my $hold = '';
    my $sep = "\n";
    my $format = "key: \$key, value: \$value <br />";

    $format = $params->{format} if( defined $params->{format} );
    $sep = $params->{separator} if( defined $params->{separator} );

#    $DB::single = 1;
    $sep =~ s/\$n/\n/g;
    while( my ($k, $v) = each %{$this->{PersistentVars}{$store}{$namespace}} ) {
        $hold = $format;
        $hold =~ s/\$key/$k/g;
        $hold =~ s/\$value/$v/g;
        $value .= "$hold$sep";
    }
    return $value;
}

# =========================
sub VarGET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    $this->debug( "GET (".Dumper($params).")" ) if $this->{Debug};
    return '' unless( $name );

    my $value = '';
    if( defined $this->{VolatileVars}{$name} ) {
        $value = $this->{VolatileVars}{$name};
        $this->debug( "-   get volatile returning $value" ) if $this->{Debug};
    } else {
        $value = $this->_getPersistentHash($name, $params);
        $this->debug( "-   get persistent returning $value" ) if $this->{Debug};
    }
    
    if (! $value && defined $params->{default} ) {
        $value = $params->{default};
        $this->debug( "-   get default returning $value" ) if $this->{Debug};
    } 
    return $value;
}

sub _getStoreAndNamespaceFromParams
{
    my ( $this, $params) = @_;

    my $namespace = $params->{namespace} || 'defaultNamespace';
    my $store = $params->{store} || 'defaultStore';

    return ($store, $namespace);    
}

sub _getPersistentHash
{
    my ($this, $name, $params) = @_;
    my ($store, $namespace)  = $this->_getStoreAndNamespaceFromParams($params);    

    my $value = '';    
    $value = $this->{PersistentVars}{$store}{$namespace}{$name}
        if ( defined $this->{PersistentVars}{$store}{$namespace}{$name} ) ;
    return $value;
}


sub _setPersistentHash
{
    my ( $this, $name, $value, $params) = @_;
    
    my ($store, $namespace)  = $this->_getStoreAndNamespaceFromParams($params);

    # TODO: assert all parameters are set
    $this->{PersistentVars}{$store}{$namespace}{$name} = $value;
    $this->debug( "Hash now ". Dumper($this->{PersistentVars})) if $this->{Debug} > 1;

}


# =========================
sub VarSET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );

    my $value = $params->{value};
    $this->debug( "SET ($name = $value)".Dumper($params) ) if $this->{Debug};
     
    return '' unless( $name );
    return '' unless( defined $value );
    
    my $remember = $params->{remember} || 0;
    if( $remember && ! ( $remember =~ /^off$/i ) ) {
        $this->_savePersistentVar($name, $value, $params );    
    } else {
        $this->debug( "-   set volatile -> $value" ) if $this->{Debug};
        $this->{VolatileVars}{$name} = $value;
    }
    return '';
}

# =========================
# Note on namespaces:
# We need a policy for which namespace to place unname-spaced SETS.
# e.g. we could place them into DEFAULT::
sub _loadPersistentVars
{
    my ( $this, $storeArg) = @_;
   #$DB::single = 1;
    
    if (! defined $storeArg){
        foreach my $store (keys %{$this->{StoreFileMapping}}) {
            $this->_loadStore($store);
        }
    } else {
        $this->_loadStore($storeArg);
    }
    # if namespace is specified, load just the one namespace
    # if not (e.g. during initialisation), load all namespaces
}

sub _loadStore
{
    my ($this, $storeName) = @_;
    #$DB::single = 1;
    $this->debug( "_loadStore ($storeName)" ) if $this->{Debug};   

    my $storeFile = $this->_storeFileForStore($storeName);
    # check if store is newer, load persistent vars if needed
    my $timeStamp = ( stat( $storeFile ) )[9];
    if( defined $timeStamp && $timeStamp != $this->{StoreTimeStamps}{$storeName} ) {
        $this->{StoreTimeStamps}{$storeName} = $timeStamp;
        my $text = TWiki::Func::readFile( $storeFile );
        $text =~ /^(.*)$/gs; # untaint, it's safe
        $text = $1;
        $this->{PersistentVars}{$storeName} = eval $text;
    }
}

=pod

=cut
sub _storeFileForStore {
    my ($this, $storeNameParam) = @_;

    my $storeName = $storeNameParam;
    my $file = $this->{StoreFileMapping}{$storeName};
    if (! $file) {
        my $behaviour = $this->{UndeclaredStoresBehaviour};
        if ($behaviour eq 'revert') {
            $storeName = 'default';
        } elsif ($behaviour eq 'create') {
            $this->{StoreFileMapping}{$storeName} = $storeName.'.dat';
        }
        $file = $this->{StoreFileMapping}{$storeName};
    }
    $this->debug( "_storeFileForStore ($storeNameParam) actually using store ($storeName) in $file" ) if $this->{Debug};   

    return $this->{StoreFileDir}.'/'.$file;
}


=pod
Save just the namespace of the variable being saved
=cut
sub _savePersistentVar
{
    my ( $this, $name, $value, $params ) = @_;
    $DB::single = 1;
    
    $this->_setPersistentHash($name, $value, $params);
    my ($store, $unusednamespace) = $this->_getStoreAndNamespaceFromParams($params); 
        
# TODO: discuss that there was a cache, but that doing two tests on it to save a write into memory is questionable
#       .... so I disabled it.
#            if( (defined $this->{PersistentVars}{$name}) 
#            && ($value eq $this->{PersistentVars}{$name}) ) {
#                $this->debug( "-   eliding (as already set) persistent -> $value" ) if $this->{Debug};
#        } else {
    $this->_saveStore( $name, $value, $store );
#        }
}

sub _saveStore
{
    my ( $this, $name, $value, $store) = @_;
    $DB::single = 1;
    $this->debug( "_saveStore ($store)" ) if $this->{Debug};   
    # FIXME: Do atomic transaction to avoid race condition - this will be done with Storable
    
    $this->_loadPersistentVars($store);            # re-load latest from disk in case updated
    my $storeFile = $this->_storeFileForStore($store);
        
    my $text = Data::Dumper->Dump([$this->{PersistentVars}{$store}], [qw(PersistentVars)]);
    $this->debug( '--**SAVING ('.$storeFile.') :'."\n".$text) if ($this->{Debug} > 1);
    TWiki::Func::saveFile( $storeFile, $text ) ;
    $this->{StoreTimeStamps}{$store} = ( stat( $storeFile ) )[9];
}



# =========================
sub _sanitizeName
{
    my ( $name ) = @_;
    $name = '' unless( defined $name );
    $name =~ s/[^a-zA-Z0-9\-]/_/go;
    $name =~ s/_+/_/go;
    return $name;
}

# =========================


####### TODO: move to Storable instead of eval. 

#use Storable qw(lock_store lock_nstore lock_retrieve);

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

#######
1;
