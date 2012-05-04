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
use Storable qw(lock_store lock_retrieve);

use Data::Dumper;
use strict;

# =========================

## TODO: clean up unnecessary double quotes into single quotes
sub new {
    my ( $class, $debugParam ) = @_;
    
    my $this = {
          DebugBreakSub       => {
#            'new' => 1,
          },
          DebugTraceSub => {
            new => 1,
          },
          UndeclaredStoresBehaviour => 'createUnknown',
          VolatileVars   => undef,
          PersistentVars => undef,
          StoreFileDir  => TWiki::Func::getWorkArea( 'SetGetPlugin' ),
          StoreFileMapping => {
            "defaultStore" => "persistentvars.dat",
          },
          DefaultStoreType => 'Legacy',
          StoreExtension => {
            "Storable" => ".store",
            "Legacy" => ".dat",
          },
          StoreTimeStamps => {
            "defaultStore" => 0,
          },
          Debug => 0
        };

    my $debugFlag = undef;
    if (ref ($debugParam) ne "HASH") {
        $debugFlag = $debugParam;
        if ($debugFlag > 0) { # Do not conflate with undef - this is user set & won't be undef
            $this->{Debug} = $debugFlag;        
        }
    }
    
    bless( $this, $class );
    $this->debug( "SetGetPlugin::Core constructor" ) if $this->{Debug};

    if (ref ($debugParam) eq "HASH") {
        foreach my $key (keys %$debugParam) {
            $this->debug('overriding key '.$key.' (previous value '.$this->_formatParameters($this->{$key}).
                         ') with debug set up value='.$this->_formatParameters($debugParam->{$key})) if $this->{Debug} > 1;
            $this->{$key} = $debugParam->{$key};
        }
    }    
    
    $this->_loadConfigSpec(); # if $TWiki::cfg{SetGetPlugin};
    
    $this->_loadPersistentVars();

    return $this;
}

=pod
Loads and validates all CFG environmental data.
=cut
sub _loadConfigSpec {
    my ($this) = @_;
    $this->debug('');
    
    my @storesList =  map {   
                s/^\s+//;  # strip leading spaces
                s/\s+$//;  # strip trailing spaces
                $_         # return the modified string
            }
            split ',', $TWiki::cfg{SetGetPlugin}{OtherStores} || '';

    
    $this->{DefaultStoreType} = $TWiki::cfg{SetGetPlugin}{DefaultStoreType} || $this->{DefaultStoreType};
    
    foreach my $store (@storesList) { # what the admin gave us
        my ($storeName, $storeFile) = $this->_defaultStoreFileForStoreName($store);
        $this->{StoreFileMapping}{$storeName} = $storeFile;
    }
    
    # TODO: DRY this is ugly code. Possibly https://metacpan.org/module/Deep::Hash::Utils if acceptable as a dependency
    if ($TWiki::cfg{SetGetPlugin}{StoreExtension}{Legacy}) {
        $this->{StoreExtension}{Legacy} = $TWiki::cfg{SetGetPlugin}{StoreExtension}{Legacy};
    }
    if ($TWiki::cfg{SetGetPlugin}{StoreExtension}{Storable}) {
        $this->{StoreExtension}{Storable} = $TWiki::cfg{SetGetPlugin}{StoreExtension}{Storable};
    }
}

sub _defaultStoreFileForStoreName {
        my ($this, $store) = @_;
        
        my $defaultExtension = $this->{StoreExtension}{$this->{DefaultStoreType}};
        my ($storeFile, $storeName);
        if ($store =~ m/(.*)\.(.*)/) { # is a storeFile
            $storeFile = $store;
            $storeName = $1;
        } else { # is a storeName
            $storeName = $store;
            $storeFile = $store . $defaultExtension;            
        }
    return ($storeName, $storeFile);
}
        
sub DESTROY {
    my ($this) = @_;
    if ($this->{Debug} > 1) {
        print "\n====== DESTROYING\n";        
        $this->debug($this); # already in if $this->{Debug};   
        $this->_dumpStores();
        print "\n================================================================================================================================================\n";
    }
}

=pod
This is an expensive routine. Call only with a conditional that $this->{Debug} is > 0.
=cut
sub debug {
    my ($this, $message) = @_;
    $message = $message;
    my $parentSub = (split( /::/, (caller(1))[3]))[-1]; # last part of the fully qualified package name

    if ($this->{Debug}) {
                
        TWiki::Func::writeDebug(' - SetGetPlugin '.$message) if ($this->{Debug} == 1);
        if ($this->{DebugTraceSub}{$parentSub} || $this->{Debug} > 2) {        
            my $callerIndent = " " x _callerDepth();
            print STDOUT "\t".$callerIndent." ".$parentSub." ".$message."\n";
            TWiki::Func::writeDebug(' - SetGetPlugin '.$callerIndent." ".$parentSub." ".$message);
        }
    }

    $DB::single = 1 if ($this->{DebugBreakSub}{$parentSub});
}

sub _callerDepth {
    my $depth = 0;
    for (; caller $depth; $depth++) {1} ; # http://www.perlmonks.org/?node_id=602360 (use sparingly - inefficient)
    return $depth;
}

sub _dumpStores {
    my ($this) = @_;
    $this->debug("Dump:") if $this->{Debug};
    foreach my $store (keys %{$this->{StoreFileMapping}}) {
        my $storeFile = $this->_storeFileForStore($store);
        if (-e $storeFile) {
            print"== STOREFILE $store @ $storeFile==\n";
            system("cat ".$storeFile);
            print "\n";
        } else {
            print "== STOREFILE $store @ $storeFile does not exist==\n";
        }
    }
}

=pod
Returns 0 or 1 whether there is a file for a given store name
=cut
sub _storeFileExists {
    my ($this, $store) = @_;
    my $storeFile = $this->_storeFileForStore($store);
    return -e $storeFile || 0;
}

# =========================
=pod
If you omit store, you get defaultStore
=cut

sub VarDUMP
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    my $namespace = $params->{namespace}; # this should not default to defaultNamespace, we show all namespaces if omitted
    my $store = $params->{store} || 'defaultStore';

    $this->debug( "%SETGETDUMP{".$this->_formatParameters($params)."}%") if $this->{Debug};
    #return '' unless( $name );

    my $output = '';
    my $hold = '';
    my $sep = "\n";
    my $format = "key: \$key, value: \$value <br />";

    $format = $params->{format} if( defined $params->{format} );
    $sep = $params->{separator} if( defined $params->{separator} );

    $DB::single = 1;
    return '' unless $this->{PersistentVars}; # nothing if undef
    
    my @namespaces = keys %{$this->{PersistentVars}{$store}};
    if ($namespace) { # we're overriding the above line.
        @namespaces = ($namespace);
    } 
    
    $sep =~ s/\$n/\n/g;
    foreach my $namespace (@namespaces) {
        while( my ($key, $value) = each %{$this->{PersistentVars}{$store}{$namespace}}) {
            $hold = $format;
            $hold =~ s/\$store/$store/g;
            $hold =~ s/\$namespace/$namespace/g;
            $hold =~ s/\$key/$key/g;
            $hold =~ s/\$value/$value/g;
            $output .= "$hold$sep";
        }
    }
    $this->debug(" returning ".$output) if $this->{Debug};
    return $output;
}

sub VarDUMPALL
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    
    $this->debug( "SETGETDUMPALL{".$this->_formatParameters($params)."}%") if $this->{Debug};
    
    if (! defined $params->{format}) {
        $params->{format} = "store: \$store namespace: \$namespace key: \$key, value: \$value <br />";
    }
    
    my $value = '';
    foreach my $store (keys %{$this->{StoreFileMapping}}) {
        $params->{store} = $store;
        $value .= $this->VarDUMP($session, $params, $topic, $web);
    }   
    return $value;
}

# =========================
sub VarGET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    $this->debug("%GET{".$this->_formatParameters($params)."}%") if $this->{Debug};
    return '' unless( $name );

    my $value = '';
    if( defined $this->{VolatileVars}{$name} ) {
        $value = $this->{VolatileVars}{$name};
        $this->debug( "-   get volatile returning '$value'" ) if $this->{Debug};
    } else {
        $value = $this->_getPersistentHash($name, $params);
        $this->debug( "-   get persistent returning '$value'" ) if $this->{Debug};
    }
    
    if (! $value && defined $params->{default} ) {
        $value = $params->{default};
        $this->debug( "-   get default returning '$value'" ) if $this->{Debug};
    } 
    return $value;
}

sub _getStoreAndNamespaceOrDefaultsFromParams
{
    my ( $this, $params) = @_;

    my $namespace = $params->{namespace} || 'defaultNamespace';
    my $store = $params->{store} || 'defaultStore';

    return ($store, $namespace);    
}

sub _getPersistentHash
{
    my ($this, $name, $params) = @_;
    my ($store, $namespace)  = $this->_getStoreAndNamespaceOrDefaultsFromParams($params);    

    $this->debug( "Hash for get ($store, $namespace) ". Dumper($this->{PersistentVars})) if $this->{Debug} > 1;
    my $value = '';    
    $value = $this->{PersistentVars}{$store}{$namespace}{$name}
        if ( defined $this->{PersistentVars}{$store}{$namespace}{$name} ) ;
    return $value;
}


sub _setPersistentHash
{
    my ( $this, $name, $value, $params) = @_;
    
    my ($store, $namespace)  = $this->_getStoreAndNamespaceOrDefaultsFromParams($params);

    # TODO: assert all parameters are set
    $this->{PersistentVars}{$store}{$namespace}{$name} = $value;
    $this->debug( "Hash now ". Dumper($this->{PersistentVars})) if $this->{Debug} > 1;
}

sub _formatParameters
{
    my ($this, $params) = @_;
    my $text = join(" ", sort map { "$_=\"$params->{$_}\"" } keys %$params);
    $text =~ s/_DEFAULT=//;
    return $text;
}


# =========================
sub VarSET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );

    my $value = $params->{value};
    $this->debug( "%SET{".$this->_formatParameters($params)."}%" ) if $this->{Debug};
     
    return '' unless( $name );
    return '' unless( defined $value );
    
    my $remember = $params->{remember} || 0;
    if( $remember && ! ( $remember =~ /^off$/i ) ) {
        $this->_savePersistentVar($name, $value, $params );    
    } else {
        $this->debug( "-   setting volatile $name to $value" ) if $this->{Debug};
        $this->{VolatileVars}{$name} = $value;
    }
    $this->debug(' was set to '.$value);
    return '';
}

# =========================
# Note on namespaces:
# We need a policy for which namespace to place unname-spaced SETS.
# e.g. we could place them into DEFAULT::
sub _loadPersistentVars
{
    my ( $this, $storeArg) = @_;
    
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
    $this->debug( "($storeName)" ) if $this->{Debug};   

    my $storeFile = $this->_storeFileForStore($storeName);
    # check if store is newer, load persistent vars if needed
    my $timeStamp = ( stat( $storeFile ) )[9];
    $this->debug( "timestamp = ".Dumper($timeStamp) ) if $this->{Debug};
    if( ! defined $timeStamp ) {
        $this->debug( "File doesn't exist: ".$storeFile." (SO ABORTING LOAD)".Dumper(stat $storeFile)) if $this->{Debug} > 1;
        return;
    }

    if (! defined $this->{StoreTimeStamps}{$storeName}) {
        $this->debug( "No recorded timestamp for ".$storeName." (SO CONTINUING LOAD)") if $this->{Debug} > 1;       
    } elsif ($timeStamp == $this->{StoreTimeStamps}{$storeName} ) {
        $this->debug( "timestamp for ".$storeFile." matched existing record (SO ABORTING LOAD)") if $this->{Debug} > 1;
        return;
    } # else it didn't match, continue.

    $this->debug( "File ".$storeFile." is newer than records (PERFORMING LOAD)") if $this->{Debug} > 1;    
    # So, now the store is newer than our record of it. So our records have been invalided. Load it.
    $this->{StoreTimeStamps}{$storeName} = $timeStamp;
    my $legacyExt = quotemeta($this->{StoreExtension}{Legacy});
    if ($storeFile =~ m/.*$legacyExt$/) { # TODO: factor out the IF test.
        $this->{PersistentVars}{$storeName} = $this->_loadPersistentVarsTWikiReadFile($storeFile);    
    } else {
        $this->{PersistentVars}{$storeName} = $this->_loadPersistentVarsStorableLock($storeFile);
    }
    $this->debug( "Loaded". Dumper($this->{PersistentVars}{$storeName})) if $this->{Debug} > 1;
}


sub _fixUpDataStructure
{
    my ($this, $inputHash) = @_;
    $this->debug("INPUT". Dumper($inputHash)) if $this->{Debug} > 1;
    my $outputHash = $inputHash; #TODO - consider Storable's dclone - without it $input = $output as aliased here.
    
    foreach my $key (keys %$outputHash) {
        if (ref $outputHash->{$key} ne 'HASH') {
            $outputHash->{'defaultNamespace'}{$key} = $outputHash->{$key};
            delete $outputHash->{$key};
        }
    }
    $this->debug("OUTPUT". Dumper($outputHash)) if $this->{Debug} > 1;
    return $outputHash;
}

sub _loadPersistentVarsTWikiReadFile {
    my ($this, $storeFile) = @_;
    $this->debug( "($storeFile)" ) if $this->{Debug};   

    my $text = TWiki::Func::readFile( $storeFile );
    $text =~ /^(.*)$/gs; # untaint, it's safe because an internal file
    $text = $1;
    our $PersistentVars;
    my $hashref = eval $text; # sets variable $PersistentVars, with side effect to return value to end up in $hashref
    $hashref = $this->_fixUpDataStructure($hashref);
    return $hashref;
};

sub _savePersistentVarsTWikiReadFile
{
    my ($this, $storeFile, $ref) = @_;   
    $this->debug( "($storeFile)" ) if $this->{Debug};    
    my $text = Data::Dumper->Dump([$ref], [qw(PersistentVars)]);
    return TWiki::Func::saveFile( $storeFile, $text ) ;
}


sub _loadPersistentVarsStorableLock
{
    my ($this, $storeFile) = @_;
    $this->debug( "($storeFile)" ) if $this->{Debug};   
    
    my $hashref = lock_retrieve($storeFile);    
    return $hashref;
}

sub _savePersistentVarsStorableLock
{
    my ($this, $storeFile, $ref) = @_;   
    $this->debug( "($storeFile)" ) if $this->{Debug};      
    return lock_store($ref, $storeFile); # save

}

=pod
Migrate existing persistentVars as a storable lock implementation
=cut
sub _convertPersistentVarsIntoStorableLock {
    my ($this, $persistentVarsFile, $storableLockFile) = @_;
    $this->debug("($persistentVarsFile, $storableLockFile)");
    $this->{PersistentVars}{LastConverted} = $this->_loadPersistentVarsTWikiReadFile($persistentVarsFile);
    $this->_savePersistentVarsStorableLock($storableLockFile, $this->{PersistentVars}{LastConverted});
}

=pod
Migrate existing storable lock as a persistentVars implementation
=cut
sub _convertStorableLockIntoPersistentVars {
    my ($this, $storableLockFile, $persistentVarsFile) = @_;
    $this->debug("($storableLockFile, $persistentVarsFile)");
    $this->{PersistentVars}{LastConverted} = $this->_loadPersistentVarsStorableLock($storableLockFile);
    $this->_savePersistentVarsTWikiReadFile($persistentVarsFile, $this->{PersistentVars}{LastConverted});
}



=pod

=cut
sub _storeFileForStore {
    my ($this, $storeNameParam) = @_;

    my $storeName = $storeNameParam;
    my $storeFile = $this->{StoreFileMapping}{$storeName};
    if (! $storeFile) {
        my $behaviour = $this->{UndeclaredStoresBehaviour};
        if ($behaviour eq 'revertToDefault') {
            # change the store name to use the default store
            TWiki::Func::writeWarning("Use of undeclared store ".$storeNameParam. " but {SetGetPlugin}{UndeclaredStoresBehaviour} does not permit this (see configure)");            
            $storeName = 'defaultStore';
        } elsif ($behaviour eq 'createUnknown') {
            # accept the store name as is, and map the storeName
            ($storeName, $storeFile) = $this->_defaultStoreFileForStoreName($storeNameParam);
            $this->{StoreFileMapping}{$storeName} = $storeFile;
        } else {
            # invalid behaviour type
            TWiki::Func::writeWarning("Invalid UndeclaredStoresBehaviour ".$behaviour. " for ".$storeName);
            $storeName = 'defaultStore';            
        }
        $storeFile = $this->{StoreFileMapping}{$storeName};
        # TODO: write error or warning if $file is an invalid name
    }
    $this->debug( "($storeNameParam) actually using store ($storeName) in $storeFile" ) if $this->{Debug};
    my $result = $this->{StoreFileDir}.'/'.$storeFile;

    $this->debug( $result ) if $this->{Debug} > 1;   
    return $result;
}


=pod
Save just the namespace of the variable being saved
=cut
sub _savePersistentVar
{
    my ( $this, $name, $value, $params ) = @_;
    
    $this->_setPersistentHash($name, $value, $params);
    my ($store, $unusednamespace) = $this->_getStoreAndNamespaceOrDefaultsFromParams($params); 
        
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
    $this->debug( "($store)" ) if $this->{Debug};   
    # FIXME: Do atomic transaction to avoid race condition - this will be done with Storable
    
    $this->_loadPersistentVars($store);            # re-load latest from disk in case updated
    my $storeFile = $this->_storeFileForStore($store);        

    $this->debug( '--**SAVING ('.$storeFile.') :') if ($this->{Debug} > 1);
    my $ref = $this->{PersistentVars}{$store};
    $this->debug('HASH to save: '.Dumper($ref)) if ($this->{Debug} > 1);
    my $legacyExt = quotemeta($this->{StoreExtension}{Legacy});
    if ($storeFile =~ m/.*$legacyExt$/) {
        $this->_savePersistentVarsTWikiReadFile($storeFile, $ref);    
    } else {
        $this->_savePersistentVarsStorableLock($storeFile, $ref);    
    }
    
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


sub convertPersistentVarsToStoreable
{
    my ($persistentVarsStoreFile) = @_;
    my $storableStoreFile = storableForPersistentVarsFile($persistentVarsStoreFile);
    my $vars = load_persistent_vars($persistentVarsStoreFile); # load
    lock_store($vars, $storableStoreFile); # save
    # remove
}

sub verifyStorableIsEquivalentToPersistentVars
{
    my ($persistentVarsStoreFile, $storableStoreFile) = @_;
    my $storableHash = loadIntoStorable($storableStoreFile);
#    my $persistentVarsHash = load
}


#######
1;
