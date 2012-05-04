#---+ SetGetPlugin
# This TWiki extension provides SET / GET for altering persistant and transient variables.
# **STRING 100**
# Default Store
$TWiki::cfg{SetGetPlugin}{DefaultStore} = 'persistentVars.dat';

# **STRING 100**
# Names of Scopes / filenames that stores should be saved in
# 
$TWiki::cfg{SetGetPlugin}{OtherStores} = 'Store1.storable, Store2.dat';

# **SELECT Storable, Legacy**
# Default Storage Type: Storable (for a binary, lockable Storable) or Legacy (for a text, unlockable .dat file)
$TWiki::cfg{SetGetPlugin}{DefaultStoreType} = 'Storable';

# **STRING 100**
# Extension for Storable files
$TWiki::cfg{SetGetPlugin}{StoreExtension}{Storable} = '.store';

# **STRING 5**
# Extension for Legacy files
$TWiki::cfg{SetGetPlugin}{StoreExtension}{Legacy} = '.dat';


# **SELECT revertToDefault,createUnknown**
# if UndeclaredStoresBehaviour => 'revertToDefault', references to unknown stores will use the defaultStore 
# if UndeclaredStoresBehaviour => 'createUnknown', references to an unknown storeName will create that store
$TWiki::cfg{SetGetPlugin}{UndeclaredStoresBehaviour} = 'revertToDefault';

# **SELECT false,true**
$TWiki::cfg{SetGetPlugin}{ConvertLegacyStoresToStorable} = 'true';
    