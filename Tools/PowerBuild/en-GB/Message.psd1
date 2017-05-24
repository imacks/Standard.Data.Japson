# Localized	25/12/2016 7:08 PM (GMT)	303:4.80.0411	Message.psd1
# PowerBuild PBLocalizedData.en-GB

ConvertFrom-StringData @'

# ---- [ Localized Data ] ---------------------------------------------

Err_InvalidTaskName = Task name should not be null or empty string.
Err_TaskNameDoesNotExist = Task {0} does not exist.
Err_CircularReference = Circular reference found for task {0}.
Err_MissingActionParameter = Action parameter must be specified when using PreAction or PostAction parameters for task {0}.
Err_CorruptCallStack = Call stack was corrupt. Expected {0}, but got {1}.
Err_InvalidFramework = Invalid .NET Framework version, {0} specified.
Err_UnknownFramework = Unknown .NET Framework version, {0} specified in {1}.
Err_UnknownPointerSize = Unknown pointer size ({0}) returned from System.IntPtr.
Err_UnknownBitnessPart = Unknown .NET Framework bitness, {0}, specified in {1}.
Err_NoFrameworkInstallDirFound = No .NET Framework installation directory found at {0}.
Err_BadCommand = Error executing command {0}.
Err_DefaultTaskCannotHaveAction = 'default' task cannot specify an action.
Er_DuplicateTaskName = Task {0} has already been defined.
Err_DuplicateAliasName = Alias {0} has already been defined.
Err_InvalidIncludePath = Unable to include {0}. File not found.
Err_BuildFileNotFound = Could not find the build file {0}.
Err_NoDefaultTask = 'default' task required.
Err_LoadingModule = Error loading module {0}.
Err_LoadConfig = Error loading build configuration: {0}
Warn_DeprecatedFrameworkVar = Warning: Using global variable $framework to set .NET framework version used is deprecated. Instead use Framework function or configuration file.
RequiredVarNotSet = Variable {0} must be set to run task {1}.
PostconditionFailed = Postcondition failed for task {0}.
PreconditionWasFalse = Precondition was false, not executing task {0}.
ContinueOnError = Error in task {0}. {1}
BuildSuccess = Build Succeeded!
RetryMessage = Try {0}/{1} failed, retrying in {2} second
BuildTimeReportTitle = Build Time Report
Divider = ----------------------------------------------------------------------
ErrorHeaderText = An error has occured. See details below:
ErrorLabel = Error
VariableLabel = Script variables:
DefaultTaskNameFormat = Executing {0}

# ---- [ /Localized Data ] --------------------------------------------
'@
