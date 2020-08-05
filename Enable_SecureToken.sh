#!/bin/bash

### Enable_SecureToken.sh (Working Title)

#### Set variables for admin account. Use the script parameters in Jamf for script setting in policy ###
adminUser="$4"
adminPass="$5"

### Check that adminUser and adminPass variables aren't empty
if [ "${adminUser}" == "" ]; then
	echo "Username undefined.  Please pass the management account username in parameter 4"
	exit 1
fi

if [ "${adminPass}" == "" ]; then
	echo "Password undefined.  Please pass the management account password in parameter 5"
	exit 2
fi

### Get the logged in user's name
userName=$(/usr/bin/stat -f%Su /dev/console)

# Check SecureToken Status of $userName
echo "Checking Secure Token status of '$userName'"
if [[ -n "$userName" && "$userName" != "root" ]]; then
    token_status=$(/usr/sbin/sysadminctl -secureTokenStatus "$userName" 2>&1 | /usr/bin/grep -ic enabled)
    # A logged in user with no secure token should give a result of "0"
    if [[ "$token_status" -eq 0 ]]; then
        echo "$userName does not have a Secure Token"
    elif [[ "$token_status" -eq 1 ]]; then
        echo "$userName has a Secure Token"
    else
        echo "Something has gone wrong checking $userName. Exiting..."
        exit 3
    fi
else 
    echo "Either no user is logged in or the logged in user is root. Exiting..."
    exit 4
fi

#Check SecureToken Status of $admin
echo "Checking Secure Token Status of $adminUser"
admin_token_status=$(/usr/sbin/sysadminctl -secureTokenStatus "$adminUser" 2>&1 | /usr/bin/grep -ic enabled)
# An admin with no secure token should give a result of "0"
if [[ "$admin_token_status" -eq 0 ]]; then
        echo "$adminUser does not have a Secure Token"
elif [[ "$admin_token_status" -eq 1 ]]; then
        echo "$adminUser has a Secure Token"
else
        echo "Something has gone wrong checking $adminUser. Exiting..."
        exit 5
fi

## Prompt for logged in user's password
echo "Prompting $userName for their login password."
userPass="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "Please enter your login password:" default answer "" with title "Login Password" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"

### Enabled Secure Token for logged in user with admin
if [[ "$token_status" -eq 0 && "$admin_token_status" -eq 1 ]]; then
    /usr/sbin/sysadminctl -adminUser $adminUser -adminPassword $adminPass -secureTokenOn $userName -password $userPass
fi

### Enable Secure Token for admin with logged in user
if [[ "$token_status" -eq 1 && "$admin_token_status" -eq 0 ]]; then
    #Check that logged in user is an admin
    if id -Gn $userName | grep -q -w admin; then
        echo "$userName is an admin. Enabling Secure Token for local admin."
        /usr/sbin/sysadminctl -adminUser $userName -adminPass $userPass -secureTokenOn $adminUser -password $adminPass
    else
        echo "$userName is not an admin. Temporarily elevating $userName to admin."
        /usr/sbin/dseditgroup -o edit -a $userName -t user admin
        echo "Checking that $userName is now an admin"
        if id -Gn $username | grep -q -w admin; then
            echo "$username now a temporary admin. Enabling Secure Token for local admin."
            /usr/sbin/sysadminctl -adminUser $userName -adminPass $userPass -secureTokenOn $adminUser -password $adminPass
            #Disabling user as admin
            /usr/sbin/dseditgroup -o edit -d $userName -t user admin
        else
            echo "Elevating $userName to admin failed. Exiting..."
            exit 5
        fi
    
    fi
fi

### Enable Secure Token for both admin and logged in user if no Secure Token is present
if [[ "$token_status" -eq 0 && "$admin_token_status" -eq 0 ]]; then
    /usr/sbin/sysadminctl -adminUser $adminUser -adminPassword $adminPass -secureTokenOn $userName -password $userPass
fi

if [[ "$token_status" -eq 1 && "$admin_token_status" -eq 1 ]]; then
    echo "Both current logged in user and local admin have Secure Token. No other action needed"
fi