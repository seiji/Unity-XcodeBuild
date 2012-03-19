#/bin/sh

# Project
PROJECT_PATH=~/Unity-XcodeBuild
PROJECT_UNITY_PATH=$PROJECT_PATH/Unity
# Unity
UNITY_APP_PATH=/Applications/Unity/Unity.app/Contents/MacOS/Unity
UNITY_EDITOR_LOG_PATH=~/Library/Logs/Unity/Editor.log
# Xcode
OSX_ADMIN_PASSWORD=<OSX_ADMIN_PASSWORD>
IDENTITY=<IDENTITY> # iPhone Developer: XXX XXXXX
IOS_P12_PASSWORD=<IOS_P12_PASSWORD>
IOS_P12_FILE_PATH=$PROJECT_PATH/misc/iOS/UrProfile.p12
IOS_PROVISIONING_FILE_PATH=$PROJECT_PATH/misc/iOS/UrProfile.mobileprovision
# TestFlight
API_TOKEN=<API_TOKEN>
TEAM_TOKEN=<TEAM_TOKEN>
DISTRIBUTION_LISTS=<DISTRIBUTION_LISTS>

BUILD_NUMBER="1.0.0"

#-----------------
# Check argments
#-----------------
while getopts "uxt" flag; do
    case $flag in
        \?) OPT_ERROR=1; break;;
        u) opt_unity=true;;
        x) opt_xcode=true;;
        t) opt_testflight=true;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ $OPT_ERROR ]; then      # option error
    echo >&2 "usage: $0 [-ut] <gametype> <config>"
    exit 1
fi

if [ $# -ne 2 ]; then
    echo "usage: $0 <gametype> <config> \n gametype is here \n - sample \n config is here \n - debug \n - release " 1>&2
    exit 1
fi


PRODUCT_NAME=$1
if [ "${2}" = "debug" ]; then
    PROJECT_NAME="${PRODUCT_NAME}_Debug"
    CONFIGURATION=Debug
    UNITY_BATCH_EXECUTE_METHOD=BatchBuild.SampleDebugNew
    if [ -e $XCODE_PROJECT_PATH ]; then
        UNITY_BATCH_EXECUTE_METHOD=BatchBuild.SampleDebugAppend
    fi
elif [ "${2}" = "release" ]; then
    PROJECT_NAME="${PRODUCT_NAME}_Release"
    CONFIGURATION=Release
    UNITY_BATCH_EXECUTE_METHOD=BatchBuild.SampleReleaseNew        
    if [ -e $XCODE_PROJECT_PATH ]; then
        UNITY_BATCH_EXECUTE_METHOD=BatchBuild.SampleReleaseAppend
    fi
fi

XCODE_PROJECT_PATH=$PROJECT_UNITY_PATH/$PROJECT_NAME

if [ ! -n "$UNITY_BATCH_EXECUTE_METHOD" ]; then
    echo "usage: $0 <gametype> <config> \n gametype is here \n - sample \n config is here \n - debug \n - release " 1>&2
    exit 1
fi

#-----------------
# Unity Build
#-----------------
KEYCHAIN_LOCATION=~/Library/Keychains/login.keychain
PROFILE_UUID=`grep "UUID" ${IOS_PROVISIONING_FILE_PATH} -A 1 --binary-files=text 2>/dev/null |grep string|sed -e 's/^[[:blank:]]<string>//' -e 's/<\/string>//'`

function unity_build () {
    echo "========== Building Unity $PROJECT_UNITY_PATH ... Start =========="
    echo "[LOCATION] $XCODE_PROJECT_PATH"
    echo "[METHOD  ] $UNITY_BATCH_EXECUTE_METHOD"    
    $UNITY_APP_PATH -batchmode \
        -quit -projectPath $PROJECT_UNITY_PATH \
        -executeMethod $UNITY_BATCH_EXECUTE_METHOD
    if [ $? -eq 1 ]; then
        cat $UNITY_EDITOR_LOG_PATH
        exit 1
    fi
    cat $UNITY_EDITOR_LOG_PATH
    echo "========== Building Unity $PROJECT_UNITY_PATH ... Done =========="    
}

#-----------------
# XcodeProj Arrange
#-----------------
function xcodeproj_arrange () {
    echo "========== Arranging $XCODE_PROJECT_PATH ... Start =========="
    $PROJECT_PATH/script/proj_xcode.rb $XCODE_PROJECT_PATH
    echo "========== Arranging $XCODE_PROJECT_PATH ... Done =========="
}
#-----------------
# Xcode Build
#-----------------
function xcodeproj_build () {
    echo "========== Building Xcode $XCODE_PROJECT_PATH ... Start =========="
    echo "$KEYCHAIN_LOCATION"
    echo "$IDENTITY"
    echo "$IOS_P12_FILE_PATH"
    echo "$IOS_PROVISIONING_FILE_PATH"
    # unlock keychain
    security unlock-keychain -p $OSX_ADMIN_PASSWORD "${KEYCHAIN_LOCATION}"
    # import
    security import "${IOS_P12_FILE_PATH}" -f pkcs12 -P $IOS_P12_PASSWORD -k "${KEYCHAIN_LOCATION}" -T /usr/bin/codesign
    cp $IOS_PROVISIONING_FILE_PATH ~/Library/MobileDevice/Provisioning\ Profiles/$PROFILE_UUID.mobileprovision
    XCODE_PROJECT_CONFIG_PATH=$XCODE_PROJECT_PATH/Unity-iPhone.xcodeproj
    # .dSYM
    BUILD_OPT_MAKE_DSYM="GCC_GENERATE_DEBUGGING_SYMBOLS=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES SEPARATE_STRIP=YES COPY_PHASE_STRIP=NO"
    # clean (optional)
    xcodebuild clean -configuration $CONFIGURATION -project "${XCODE_PROJECT_CONFIG_PATH}"
    # build
    xcodebuild \
        -project "${XCODE_PROJECT_CONFIG_PATH}" \
        -configuration "${CONFIGURATION}" \
        -target "Unity-iPhone" \
        CODE_SIGN_IDENTITY="${IDENTITY}" \
        OTHER_CODE_SIGN_FLAGS="--keychain ${KEYCHAIN_LOCATION}" \
        $BUILD_OPT_MAKE_DSYM
    echo "========== Building Xcode $XCODE_PROJECT_PATH ... Done =========="
}
#-----------------
# Create IPA and dsym
#-----------------
function create_ipa () {
    echo "========== Creating IPA ... Start =========="
    TARGET_APP_PATH=$XCODE_PROJECT_PATH/build/$PRODUCT_NAME.app
    IPA_FILE_PATH=$PROJECT_PATH/$PROJECT_NAME-$BUILD_NUMBER.ipa
    /usr/bin/xcrun \
        -sdk iphoneos \
        PackageApplication \
        -v "${TARGET_APP_PATH}" \
        -o "${IPA_FILE_PATH}" \
        --sign "${IDENTITY}" \
        --embed "${IOS_PROVISIONING_FILE_PATH}"
    echo "========== Creating IPA ... Done =========="

    TARGET_DSYM=$PRODUCT_NAME.app.dSYM
    DSYM_ZIP_PATH=$PROJECT_PATH/$PROJECT_NAME.app.dSYM-$BUILD_NUMBER.zip
    cd $XCODE_PROJECT_PATH/build/
    zip -r $DSYM_ZIP_PATH $TARGET_DSYM
}

#-----------------
# Send TestFlight
#-----------------
function send_testflight () {
# post testflight
    echo "========== Sending TestFlight ... Start =========="
    curl http://testflightapp.com/api/builds.json -F file=@$IPA_FILE_PATH -F api_token=$API_TOKEN -F team_token=$TEAM_TOKEN -F notes="`git log -5`" -F notify=True -F distribution_lists=$DISTRIBUTION_LISTS
    echo "========== Sending TestFlight ... Done =========="
}

#-----------------
# Main
#-----------------
# New
if expr "$UNITY_BATCH_EXECUTE_METHOD" : ".*New" >/dev/null; then 
    unity_build
    xcodeproj_arrange                                            # Arrange XcodeProj
    echo "first build" 1>&2
    echo "update xcode project." 1>&2
    open $XCODE_PROJECT_PATH/Unity-iPhone.xcodeproj
    exit 0
fi
# Append
if [ ! $opt_xcode ] && [ ! $opt_testflight ]; then # Default
    opt_unity=true
fi
if [ $opt_unity ]; then 
    unity_build
    if [ ! $opt_xcode ] && [ ! $opt_testflight ]; then
        open $XCODE_PROJECT_PATH/Unity-iPhone.xcodeproj
        exit 0
    fi
fi
if [ $opt_xcode ]; then 
    xcodeproj_build
    create_ipa
    if [ ! $opt_testflight ]; then
        exit 0
    fi
fi
if [ $opt_testflight ]; then
    if [ "${2}" = "debug" ]; then
        send_testflight
    fi
    exit 0
fi





