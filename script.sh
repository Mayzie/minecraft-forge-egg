#!/bin/bash
set -e

# Jessica's completely rewritten CurseForge download script because the included one isn't that great.
# Default: https://raw.githubusercontent.com/parkervcp/eggs/master/game_eggs/minecraft/java/forge/curseforge-generic/egg-curseforge-generic.json

# Default directory to store server files.
readonly FILEPATH="/mnt/server"
# CurseForge API URL
readonly CURSEFORGE_MODPACK="https://addons-ecs.forgesvc.net/api/v2/addon/%d"
readonly CURSEFORGE_FILELIST="$CURSEFORGE_MODPACK/files"
readonly CURSEFORGE_DL="https://addons-ecs.forgesvc.net/api/v2/addon/%d/file/%d/download-url"

readonly GITHUB_API_URL="https://api.github.com"


# Forward all output to a logfile since Pterodactyl doesn't keep it.
exec &>> $FILEPATH/container-install.log


# Modified from: https://gitlab.com/bertrand-benoit/scripts-common/-/blob/9281232036d574d55b761653a36ed5743b25c729/utilities.sh#L335
has_command () {
	local _binary="$1" _full_path

	# Checks if the binary is available.
	local _full_path=$( command -v "$_binary" )
	local commandStatus=$?
	if [ $commandStatus -ne 0 ]; then
		return -1
	else
		# Checks if the binary has "execute" permission.
		if [ -x "$_full_path" ]; then
			return 0
		fi

		# It is not the case
		return -1
	fi

	# Otherwise, simple returns an error code.
	return -1
}

install_deps () {
	echo "# Installing dependencies..."
	if has_command apt-get; then
		apt-get update
		apt-get install -y curl jq libarchive-tools wget expect
	elif has_command apx; then
		apx install curl jq libarchive-tools wget expect
	else
		echo "Unable to install dependencies..."
	fi
}

get_file () {
	local version=$1
	local modpack_id=$2

	if [[ $version == "latest" ]]; then
		# Retrieve latest file.
		local url=$(printf $CURSEFORGE_MODPACK $modpack_id)
		local json=$(curl -sSL $url)

		local server_pack_id=$(echo -e $json | jq -r ".latestFiles | sort_by(.fileDate) | last | .serverPackFileId")

		if [ -z $server_pack_id ]; then
			return -1;
		fi

		local download_url=$(curl -sSL $(printf $CURSEFORGE_DL $modpack_id $server_pack_id))

		echo $download_url

		return 0
	elif [[ -n $version ]]; then
		# Version number specified.
		local url=$(printf $CURSEFORGE_FILELIST $modpack_id)
		local json=$(curl -sSL $url)

		local server_pack_id=$(echo -e $json | jq -r ". |= sort_by(.fileDate) | map(select(.displayName | contains(\"$version\"))) | last | .serverPackFileId")

		if [[ $server_pack_id == "null" ]] || [ -z $server_pack_id ]; then
			return -1
		fi

		local download_url=$(curl -sSL $(printf $CURSEFORGE_DL $modpack_id $server_pack_id))

		echo $download_url

		return 0
	elif [[ -z $version ]]; then
		# Prompt for download URL.
		echo "# No modpack version specified..." >> $FILEPATH/container-install.log

		return -1
	fi

	return -1
}

download_file () {
	local download_url=$1
	local dir=$2

	local file="$dir""server.zip"

	curl -o $file -L $download_url

	local top_level_dir=$(bsdtar -tf $file | egrep -o '(^[^\/]+\/)|(^[^\/]+$)' | uniq | wc -l)

    # Corner case exists here where if there's only one file in the ZIP, can't be bothered to fix it right now because
    # I don't think it's going to be an issue.
	if [ $top_level_dir -eq 1 ]; then
		bsdtar --strip-components=1 --directory $dir -xvf $file
	else
		bsdtar --directory $dir -xvf $file
	fi

	rm -f $file
}

main () {
	local server_dir=$FILEPATH
	# Make sure the path has a trailing /
	[[ "$server_dir" != */ ]] && server_dir="${server_dir}/"

	echo "Checking if '$server_dir' exists and creating it if necessary."
	if [ ! -d $server_dir ]; then
		set +e

		mkdir -p $server_dir &> /dev/null
		if [[ $? -ne 0 ]]; then
			echo "Error: Unable to create '$server_dir'."

			exit -1
		fi

		set -e
	fi

	install_deps

	local download_url=$(get_file $MODPACK_VERSION $MODPACK_ID)

	echo "# File URL: $download_url"

	if [ -z $download_url ]; then
		echo "Unable to find server download URL."

		exit -1
	fi

	download_file $download_url $server_dir

	echo "Installation complete"
}

main
