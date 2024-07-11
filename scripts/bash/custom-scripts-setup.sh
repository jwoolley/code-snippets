#!/bin/bash

DIRPATH_ENVAR_NAME="DEVTOOLS_ROOT_PATH"
DEVSCRIPTS_PATH_ENVAR_NAME="DEVTOOLS_SCRIPTS_PATH"

function_exists() {
	type $1	
	return $?
}

get_script_dirpath() {
	script_path="$(readlink -f "${BASH_SOURCE[0]}")"
	script_dirpath="$(dirname $script_path)"
	echo "$script_dirpath"
}

if [[ !($(function_exists cygpath)) ]]; then
	echo "Function does not exist: cygpath. Defining fill-in no-op version."
	cygpath() {
		PATH_STRING_TO_FORMAT="${@: -1}"
		echo $PATH_STRING_TO_FORMAT
	}
fi

if [[ -z ${!DIRPATH_ENVAR_NAME} ]]; then
	PROMPT="Set $DIRPATH_ENVAR_NAME user environment variable [y/N]? "
else
	echo "User variable $DIRPATH_ENVAR_NAME is already defined: ${!DIRPATH_ENVAR_NAME}"
	PROMPT="Overwrite [y/N]? "
fi

ROOT_DIR=$(get_script_dirpath)
if [[ !("${!DIRPATH_ENVAR_NAME}" -ef "$ROOT_DIR") ]]; then
	read -r -p "$PROMPT" REPLY
	case "$REPLY" in 
		[yY])
			SHOULD_SET_ENVAR=true
			;;
		*)
			SHOULD_SET_ENVAR=false
			;;
	esac
else 
	SHOULD_SET_ENVAR=false
fi

if $SHOULD_SET_ENVAR; then
	declare $DIRPATH_ENVAR_NAME=$(cygpath "$ROOT_DIR")
	setx $DIRPATH_ENVAR_NAME $(cygpath "$ROOT_DIR")
	echo "Exported $DIRPATH_ENVAR_NAME=$(cygpath "${!DIRPATH_ENVAR_NAME}")"
else
	echo "User environment variable not modified."
fi

if [[ -n ${!DEVSCRIPTS_PATH_ENVAR_NAME} && -d ${!DEVSCRIPTS_PATH_ENVAR_NAME} ]]; then
	SCRIPTS_DIRPATH=${!DEVSCRIPTS_PATH_ENVAR_NAME}
	SCRIPTS_DIR_EXISTS=true
	echo $"Found existing development scripts directory: $(cygpath -w ${!DEVSCRIPTS_PATH_ENVAR_NAME})"
	PROMPT="Update development scripts (overwrites) [y/N]? "
else
	SCRIPTS_DIR_EXISTS=false
	PROMPT="Copy development scripts [y/N]? "
fi

read -r -p "$PROMPT" REPLY
case "$REPLY" in 
	[yY])
		SHOULD_COPY_SCRIPTS=true
		;;
	*)
		SHOULD_COPY_SCRIPTS=false
		;;
esac

if $SHOULD_COPY_SCRIPTS; then

	PROMPT="Specify target directory for the development scripts (e.g. /c/Users/MyUser/scripts/) ([Enter] to cancel): "
	while [[ ! $PROCEED ]]; do
		read -r -p "$PROMPT" REPLY
		if [[ -n $REPLY ]]; then
			SCRIPTS_DIRPATH=`echo "$REPLY"`
			read -r -p "Use "$(cygpath $SCRIPTS_DIRPATH)" (e to edit) [Y/n/e]? " REPLY
			case "$REPLY" in 
				[eE])
					SCRIPTS_DIRPATH=""
					IS_CANCELING=false	
					PROMPT="Re-enter target directory for the development scripts ([Enter] to cancel): "
					;;
				[nN])
					SCRIPTS_DIRPATH=""
					IS_CANCELING=true	
					;;
				*|[yY])
					PROCEED=TRUE
					IS_CANCELING=false	
					;;
			esac
		else
			IS_CANCELING=TRUE
		fi
		if $IS_CANCELING; then
			read -r -p "Really cancel and terminate initialization [Y/n]? " REPLY
			case "$REPLY" in 
				[nN])
					IS_CANCELING=false
					;;
				*|[yY])
					SHOULD_COPY_SCRIPTS=false
					PROCEED=true
					;;
			esac
		fi
	done

	if $SHOULD_COPY_SCRIPTS; then
		if [[ ! -d $SCRIPTS_DIRPATH ]]; then
			read -r -p "Directory $SCRIPTS_DIRPATH doesn't exist. Create it [y/N]? " REPLY
			case "$REPLY" in 
				[yY])
					echo "Creating scripts directory $(cygpath -w $SCRIPTS_DIRPATH)"
					mkdir -p $SCRIPTS_DIRPATH
					echo "Directory created."
					;;
				*)
					SHOULD_COPY_SCRIPTS=false
					;;
			esac
		fi
	fi

	if $SHOULD_COPY_SCRIPTS; then
		SOURCE_SCRIPTS_PATH="$ROOT_DIR/scripts/"
		echo "Copying directory scripts"
		echo -n "   from: $(cygpath -w $SOURCE_SCRIPTS_PATH)"
		echo ""
		echo -n "   to: $(cygpath -w $SCRIPTS_DIRPATH)"
		echo ""
		cp -r "$SOURCE_SCRIPTS_PATH/." "$SCRIPTS_DIRPATH"
		echo "Scripts copied."

		# check to see if scripts path is in PATH
		if [[ -n $PATH ]]; then
			# IFS=Internal Field Separator. Haven't learned all the syntax; this is a StackOverflow special.
			# 	Source: https://stackoverflow.com/a/29949759/14644374 
		    IFS=: read -r -d '' -a path_array < <(printf '%s:\0' "$PATH")
		    for p in "${path_array[@]}"; do
			   if [[ !$SCRIPTS_IN_USER_PATH && "$p" -ef "$SCRIPTS_DIRPATH" ]]; then
				   SCRIPTS_IN_USER_PATH=true
			   fi
		    done
		fi

		if [[ !($SCRIPTS_IN_USER_PATH) ]]; then
			read -r -p "Add scripts directory to PATH in .bash_profile? [y/N]? " REPLY
			case "$REPLY" in 
				[yY])
					echo "export $DEVSCRIPTS_PATH_ENVAR_NAME=\"$SCRIPTS_DIRPATH\"" >> "$HOME/.bash_profile"
					echo "PATH=\"\$PATH:\$$DEVSCRIPTS_PATH_ENVAR_NAME\"" >> "$HOME/.bash_profile"	
					echo "echo \"Custom scripts from $(cygpath -w $SCRIPTS_DIRPATH) added to PATH.\"" >> "$HOME/.bash_profile"
					echo "echo \"Use 'scriptlist' to list available scripts.\"" >> "$HOME/.bash_profile"
					echo "Scripts directory added to PATH."
					;;
				*)
					:
					;;
			esac
		fi
	else
		echo "Development scripts will not be copied."
	fi
fi

echo "Done."
